import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/spb_model.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/config/api_endpoints.dart';
import 'package:dio/dio.dart';

part 'espb_form_event.dart';
part 'espb_form_state.dart';

class EspbFormBloc extends Bloc<EspbFormEvent, EspbFormState> {
  final DatabaseHelper _dbHelper = getIt<DatabaseHelper>();
  final Dio _dio = getIt<Dio>();
  final Connectivity _connectivity = getIt<Connectivity>();
  
  // For background sync
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  
  EspbFormBloc() : super(EspbFormInitial()) {
    on<EspbFormSubmitted>(_onEspbFormSubmitted);
    on<EspbFormSyncRequested>(_onEspbFormSyncRequested);
    on<EspbFormSyncAll>(_onEspbFormSyncAll);
    on<EspbFormConnectivityChanged>(_onEspbFormConnectivityChanged);
    
    // Initialize connectivity monitoring
    _initConnectivityMonitoring();
    
    // Start background sync timer
    _startBackgroundSync();
  }
  
  @override
  Future<void> close() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
  
  void _initConnectivityMonitoring() {
    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      final isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      add(EspbFormConnectivityChanged(isConnected: isConnected));
    });
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      add(EspbFormConnectivityChanged(isConnected: isConnected));
    });
  }
  
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    // Check for pending syncs every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      add(const EspbFormSyncAll());
    });
  }

  Future<void> _onEspbFormSubmitted(
    EspbFormSubmitted event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSubmitting(spbNumber: event.spbNumber));
    
    try {
      // Validate required fields
      if (event.spbNumber.isEmpty) {
        emit(EspbFormError(
          message: 'SPB number is required',
          spbNumber: event.spbNumber,
        ));
        return;
      }
      
      if (event.createdBy.isEmpty) {
        emit(EspbFormError(
          message: 'Created by is required',
          spbNumber: event.spbNumber,
        ));
        return;
      }
      
      if (event.latitude.isEmpty || event.longitude.isEmpty) {
        emit(EspbFormError(
          message: 'Location coordinates are required',
          spbNumber: event.spbNumber,
        ));
        return;
      }
      
      // Save to local database
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final formData = {
        'no_spb': event.spbNumber,
        'status': event.status,
        'created_by': event.createdBy,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'alasan': event.alasan,
        'is_any_handling_ex': event.isAnyHandlingEx ? 1 : 0,
        'timestamp': timestamp,
        'is_synced': 0, // Not synced yet
        'retry_count': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      
      // Insert into database
      await _dbHelper.insert('espb_form_data', formData);
      
      // Try to sync immediately if connected
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty && 
                         !connectivityResult.contains(ConnectivityResult.none);
      
      if (isConnected) {
        // Try to sync with API
        final syncResult = await _syncFormData(event.spbNumber);
        if (syncResult) {
          emit(EspbFormSuccess(
            spbNumber: event.spbNumber,
            isSynced: true,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        } else {
          // Sync failed but data is saved locally
          emit(EspbFormSuccess(
            spbNumber: event.spbNumber,
            isSynced: false,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        }
      } else {
        // Offline - data saved locally only
        emit(EspbFormSuccess(
          spbNumber: event.spbNumber,
          isSynced: false,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        ));
      }
    } catch (e) {
      emit(EspbFormError(
        message: 'Error saving form data: $e',
        spbNumber: event.spbNumber,
      ));
    }
  }

  Future<void> _onEspbFormSyncRequested(
    EspbFormSyncRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSyncing(spbNumber: event.spbNumber));
    
    try {
      final success = await _syncFormData(event.spbNumber);
      
      if (success) {
        // Get the timestamp from the database
        final results = await _dbHelper.query(
          'espb_form_data',
          where: 'no_spb = ?',
          whereArgs: [event.spbNumber],
          limit: 1,
        );
        
        if (results.isNotEmpty) {
          final timestamp = results.first['timestamp'] as int;
          emit(EspbFormSyncSuccess(
            spbNumber: event.spbNumber,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        } else {
          emit(EspbFormSyncSuccess(
            spbNumber: event.spbNumber,
            timestamp: DateTime.now(),
          ));
        }
      } else {
        emit(EspbFormSyncFailure(
          message: 'Failed to sync with server',
          spbNumber: event.spbNumber,
        ));
      }
    } catch (e) {
      emit(EspbFormSyncFailure(
        message: 'Error during sync: $e',
        spbNumber: event.spbNumber,
      ));
    }
  }

  Future<void> _onEspbFormSyncAll(
    EspbFormSyncAll event,
    Emitter<EspbFormState> emit,
  ) async {
    // Check connectivity first
    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult.isNotEmpty && 
                       !connectivityResult.contains(ConnectivityResult.none);
    
    if (!isConnected) {
      // Skip sync if offline
      return;
    }
    
    emit(const EspbFormSyncingAll());
    
    try {
      // Get all unsynced forms
      final unsyncedForms = await _dbHelper.query(
        'espb_form_data',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      
      if (unsyncedForms.isEmpty) {
        emit(const EspbFormSyncAllComplete(count: 0));
        return;
      }
      
      int successCount = 0;
      
      // Sync each form
      for (final form in unsyncedForms) {
        final spbNumber = form['no_spb'] as String;
        final success = await _syncFormData(spbNumber);
        
        if (success) {
          successCount++;
        }
      }
      
      emit(EspbFormSyncAllComplete(count: successCount));
    } catch (e) {
      emit(EspbFormSyncAllFailure(message: 'Error syncing forms: $e'));
    }
  }

  Future<void> _onEspbFormConnectivityChanged(
    EspbFormConnectivityChanged event,
    Emitter<EspbFormState> emit,
  ) async {
    // If we just got connected, try to sync all pending forms
    if (event.isConnected) {
      add(const EspbFormSyncAll());
    }
  }

  // Helper method to sync a single form with the API
  Future<bool> _syncFormData(String spbNumber) async {
    try {
      // Get form data from database
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
        limit: 1,
      );
      
      if (results.isEmpty) {
        return false;
      }
      
      final formData = results.first;
      
      // Prepare data for API
      final apiData = {
        'noSPB': formData['no_spb'],
        'status': formData['status'],
        'createdBy': formData['created_by'],
        'latitude': formData['latitude'],
        'longitude': formData['longitude'],
        'alasan': formData['alasan'],
        'isAnyHandlingEx': formData['is_any_handling_ex'] == 1,
      };
      
      // Determine which API endpoint to use based on status
      final endpoint = formData['status'] == "1" 
          ? ApiServiceEndpoints.AcceptSPBDriver 
          : ApiServiceEndpoints.AdjustSPBDriver;
      
      // Call API
      final response = await _dio.put(
        endpoint,
        data: apiData,
      );
      
      if (response.statusCode == 200) {
        // Update local database to mark as synced
        await _dbHelper.update(
          'espb_form_data',
          {
            'is_synced': 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          },
          where: 'no_spb = ?',
          whereArgs: [spbNumber],
        );
        
        return true;
      } else {
        // Update retry count
        await _dbHelper.update(
          'espb_form_data',
          {
            'retry_count': formData['retry_count'] + 1,
            'last_error': 'API error: ${response.statusCode}',
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          },
          where: 'no_spb = ?',
          whereArgs: [spbNumber],
        );
        
        return false;
      }
    } catch (e) {
      // Update retry count and error message
      await _dbHelper.update(
        'espb_form_data',
        {
          'retry_count': Sqflite.firstIntValue(await _dbHelper.query(
            'espb_form_data',
            columns: ['retry_count'],
            where: 'no_spb = ?',
            whereArgs: [spbNumber],
          )) + 1,
          'last_error': 'Exception: $e',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
      );
      
      return false;
    }
  }
  
  // Get sync status for a specific SPB
  Future<Map<String, dynamic>?> getSyncStatus(String spbNumber) async {
    try {
      final results = await _dbHelper.query(
        'espb_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbNumber],
        limit: 1,
      );
      
      if (results.isEmpty) {
        return null;
      }
      
      return {
        'isSynced': results.first['is_synced'] == 1,
        'timestamp': results.first['timestamp'] as int,
        'retryCount': results.first['retry_count'] as int,
        'lastError': results.first['last_error'],
      };
    } catch (e) {
      return null;
    }
  }
}