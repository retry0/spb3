import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/espb_form_data.dart';
import '../../domain/usecases/save_espb_form_usecase.dart';
import '../../domain/usecases/sync_espb_form_usecase.dart';
import '../../../../core/utils/logger.dart';

part 'espb_form_event.dart';
part 'espb_form_state.dart';

class EspbFormBloc extends Bloc<EspbFormEvent, EspbFormState> {
  final SaveEspbFormUseCase _saveEspbFormUseCase;
  final SyncEspbFormUseCase _syncEspbFormUseCase;
  final Connectivity _connectivity;
  
  // Connectivity subscription
  StreamSubscription? _connectivitySubscription;
  
  // Background sync timer
  Timer? _syncTimer;
  
  // Retry mechanism
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _initialBackoffDuration = Duration(seconds: 5);
  Timer? _retryTimer;
  
  EspbFormBloc({
    required SaveEspbFormUseCase saveEspbFormUseCase,
    required SyncEspbFormUseCase syncEspbFormUseCase,
    required Connectivity connectivity,
  }) : _saveEspbFormUseCase = saveEspbFormUseCase,
       _syncEspbFormUseCase = syncEspbFormUseCase,
       _connectivity = connectivity,
       super(EspbFormInitial()) {
    on<EspbFormSaveRequested>(_onEspbFormSaveRequested);
    on<EspbFormSyncRequested>(_onEspbFormSyncRequested);
    on<EspbFormSyncAllRequested>(_onEspbFormSyncAllRequested);
    on<EspbFormConnectivityChanged>(_onEspbFormConnectivityChanged);
    
    // Initialize connectivity monitoring
    _initConnectivityMonitoring();
    
    // Start background sync timer
    _startBackgroundSync();
  }
  
  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    return super.close();
  }
  
  void _initConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final hasConnectivity = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      add(EspbFormConnectivityChanged(isConnected: hasConnectivity));
    });
  }
  
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      add(const EspbFormSyncAllRequested());
    });
  }
  
  Future<void> _onEspbFormSaveRequested(
    EspbFormSaveRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSaving());
    
    final result = await _saveEspbFormUseCase(event.formData);
    
    result.fold(
      (failure) {
        emit(EspbFormSaveFailure(message: failure.message));
      },
      (success) {
        final isSynced = event.formData.isSynced;
        emit(EspbFormSaveSuccess(isSynced: isSynced));
        
        // If not synced, check connectivity and try to sync
        if (!isSynced) {
          _checkConnectivityAndSync();
        }
      },
    );
  }
  
  Future<void> _onEspbFormSyncRequested(
    EspbFormSyncRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSyncing(spbNumber: event.spbNumber));
    
    final result = await _syncEspbFormUseCase.syncSpecific(event.spbNumber);
    
    result.fold(
      (failure) {
        emit(EspbFormSyncFailure(
          message: failure.message,
          spbNumber: event.spbNumber,
        ));
        
        // Schedule retry if it's a network failure
        if (failure is NetworkFailure) {
          _scheduleRetry(event);
        }
      },
      (success) {
        emit(EspbFormSyncSuccess(spbNumber: event.spbNumber));
        
        // Reset retry counter on success
        _retryAttempt = 0;
      },
    );
  }
  
  Future<void> _onEspbFormSyncAllRequested(
    EspbFormSyncAllRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    // Check if there's anything to sync
    final hasUnsyncedData = await _syncEspbFormUseCase.hasUnsyncedData();
    if (!hasUnsyncedData) {
      return; // Nothing to sync
    }
    
    emit(const EspbFormSyncingAll());
    
    final result = await _syncEspbFormUseCase();
    
    result.fold(
      (failure) {
        emit(EspbFormSyncAllFailure(message: failure.message));
        
        // Schedule retry if it's a network failure
        if (failure is NetworkFailure) {
          _scheduleRetryAll();
        }
      },
      (syncedCount) {
        emit(EspbFormSyncAllSuccess(syncedCount: syncedCount));
        
        // Reset retry counter on success
        _retryAttempt = 0;
      },
    );
  }
  
  Future<void> _onEspbFormConnectivityChanged(
    EspbFormConnectivityChanged event,
    Emitter<EspbFormState> emit,
  ) async {
    // If we just got connected, try to sync
    if (event.isConnected) {
      AppLogger.info('Connectivity restored, attempting to sync ESPB form data');
      add(const EspbFormSyncAllRequested());
    }
  }
  
  void _scheduleRetry(EspbFormSyncRequested event) {
    if (_retryAttempt >= _maxRetryAttempts) {
      AppLogger.warning('Max retry attempts reached for SPB: ${event.spbNumber}');
      return;
    }
    
    _retryAttempt++;
    
    // Calculate backoff duration with exponential increase
    final backoffDuration = Duration(
      milliseconds: _initialBackoffDuration.inMilliseconds * (1 << _retryAttempt),
    );
    
    AppLogger.info('Scheduling retry in ${backoffDuration.inSeconds} seconds for SPB: ${event.spbNumber}');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(backoffDuration, () {
      add(EspbFormSyncRequested(spbNumber: event.spbNumber));
    });
  }
  
  void _scheduleRetryAll() {
    if (_retryAttempt >= _maxRetryAttempts) {
      AppLogger.warning('Max retry attempts reached for syncing all ESPB form data');
      return;
    }
    
    _retryAttempt++;
    
    // Calculate backoff duration with exponential increase
    final backoffDuration = Duration(
      milliseconds: _initialBackoffDuration.inMilliseconds * (1 << _retryAttempt),
    );
    
    AppLogger.info('Scheduling retry in ${backoffDuration.inSeconds} seconds for all ESPB form data');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(backoffDuration, () {
      add(const EspbFormSyncAllRequested());
    });
  }
  
  Future<void> _checkConnectivityAndSync() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasConnectivity = connectivityResult.isNotEmpty && 
                           !connectivityResult.contains(ConnectivityResult.none);
    
    if (hasConnectivity) {
      add(const EspbFormSyncAllRequested());
    }
  }
}