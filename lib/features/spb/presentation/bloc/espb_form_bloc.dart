import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/utils/logger.dart';
import '../../data/models/espb_form_data.dart';
import '../../domain/usecases/save_espb_form_usecase.dart';
import '../../domain/usecases/sync_espb_form_usecase.dart';
import 'espb_form_event.dart';
import 'espb_form_state.dart';

class EspbFormBloc extends Bloc<EspbFormEvent, EspbFormState> {
  final SaveEspbFormUseCase _saveEspbFormUseCase;
  final SyncEspbFormUseCase _syncEspbFormUseCase;
  final Connectivity _connectivity;

  // For connectivity monitoring
  StreamSubscription? _connectivitySubscription;
  bool _isConnected = true;

  // For auto-sync
  Timer? _syncTimer;
  final Duration _syncInterval = const Duration(minutes: 5);

  EspbFormBloc({
    required SaveEspbFormUseCase saveEspbFormUseCase,
    required SyncEspbFormUseCase syncEspbFormUseCase,
    required Connectivity connectivity,
  }) : _saveEspbFormUseCase = saveEspbFormUseCase,
       _syncEspbFormUseCase = syncEspbFormUseCase,
       _connectivity = connectivity,
       super(const EspbFormInitial()) {
    on<SaveAcceptanceFormRequested>(_onSaveAcceptanceFormRequested);
    on<SaveKendalaFormRequested>(_onSaveKendalaFormRequested);
    on<SyncFormRequested>(_onSyncFormRequested);
    on<SyncAllFormsRequested>(_onSyncAllFormsRequested);
    on<GetFormRequested>(_onGetFormRequested);
    on<GetPendingFormsRequested>(_onGetPendingFormsRequested);
    on<GetFormsForSpbRequested>(_onGetFormsForSpbRequested);
    on<ConnectivityChanged>(_onConnectivityChanged);

    // Initialize connectivity monitoring
    _initConnectivity();
    
    // Start periodic sync
    _startPeriodicSync();
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    return super.close();
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(connectivityResult);
      
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivityStatus,
      );
    } catch (e) {
      AppLogger.error('Failed to initialize connectivity monitoring: $e');
    }
  }

  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    
    // If connectivity status changed, emit event
    if (wasConnected != _isConnected) {
      add(ConnectivityChanged(isConnected: _isConnected));
      
      // If we just got connected, trigger sync
      if (_isConnected && !wasConnected) {
        add(const SyncAllFormsRequested());
      }
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      // Only sync if connected
      if (_isConnected) {
        add(const SyncAllFormsRequested());
      }
    });
  }

  Future<void> _onSaveAcceptanceFormRequested(
    SaveAcceptanceFormRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(const EspbFormSaving());
    
    final result = await _saveEspbFormUseCase(
      noSpb: event.noSpb,
      formType: EspbFormType.acceptance,
      status: "1", // Status 1 for acceptance
      latitude: event.latitude,
      longitude: event.longitude,
      createdBy: event.createdBy,
    );
    
    await result.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (formData) async {
        emit(EspbFormSaved(formData: formData));
        
        // If connected, try to sync immediately
        if (_isConnected) {
          add(SyncFormRequested(formId: formData.id));
        }
      },
    );
  }

  Future<void> _onSaveKendalaFormRequested(
    SaveKendalaFormRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(const EspbFormSaving());
    
    final result = await _saveEspbFormUseCase(
      noSpb: event.noSpb,
      formType: EspbFormType.kendala,
      status: "2", // Status 2 for kendala
      alasan: event.alasan,
      isDriverOrVehicleChanged: event.isDriverOrVehicleChanged,
      latitude: event.latitude,
      longitude: event.longitude,
      createdBy: event.createdBy,
    );
    
    await result.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (formData) async {
        emit(EspbFormSaved(formData: formData));
        
        // If connected, try to sync immediately
        if (_isConnected) {
          add(SyncFormRequested(formId: formData.id));
        }
      },
    );
  }

  Future<void> _onSyncFormRequested(
    SyncFormRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    // Get current form data first
    final getResult = await _getFormData(event.formId);
    
    await getResult.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (formData) async {
        // Skip if already synced
        if (formData.isSynced) {
          emit(EspbFormSynced(formData: formData));
          return;
        }
        
        // Show syncing state
        emit(EspbFormSyncLoading(formData: formData));
        
        // Attempt to sync
        final syncResult = await _syncEspbFormUseCase(event.formId);
        
        await syncResult.fold(
          (failure) async {
            emit(EspbFormSyncFailed(
              formData: formData,
              message: failure.message,
            ));
          },
          (syncedData) async {
            emit(EspbFormSynced(formData: syncedData));
          },
        );
      },
    );
  }

  Future<void> _onSyncAllFormsRequested(
    SyncAllFormsRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    try {
      // Get all pending forms first
      final pendingFormsResult = await _getPendingForms();
      
      await pendingFormsResult.fold(
        (failure) async {
          emit(EspbFormError(message: failure.message));
        },
        (pendingForms) async {
          // Skip if no pending forms
          if (pendingForms.isEmpty) {
            return;
          }
          
          // Show syncing state
          emit(EspbFormSyncAllLoading(pendingForms: pendingForms));
          
          // Attempt to sync all
          final syncResult = await _syncEspbFormUseCase.syncAll();
          
          await syncResult.fold(
            (failure) async {
              emit(EspbFormSyncAllFailed(
                message: failure.message,
                successCount: 0,
                totalCount: pendingForms.length,
              ));
            },
            (successCount) async {
              emit(EspbFormSyncAllComplete(
                successCount: successCount,
                totalCount: pendingForms.length,
              ));
            },
          );
        },
      );
    } catch (e) {
      emit(EspbFormError(message: 'Failed to sync forms: $e'));
    }
  }

  Future<void> _onGetFormRequested(
    GetFormRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(const EspbFormLoading());
    
    final result = await _getFormData(event.formId);
    
    await result.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (formData) async {
        emit(EspbFormLoaded(formData: formData));
      },
    );
  }

  Future<void> _onGetPendingFormsRequested(
    GetPendingFormsRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(const EspbFormLoading());
    
    final result = await _getPendingForms();
    
    await result.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (forms) async {
        emit(EspbFormListLoaded(forms: forms, isConnected: _isConnected));
      },
    );
  }

  Future<void> _onGetFormsForSpbRequested(
    GetFormsForSpbRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(const EspbFormLoading());
    
    final result = await _getFormsForSpb(event.noSpb);
    
    await result.fold(
      (failure) async {
        emit(EspbFormError(message: failure.message));
      },
      (forms) async {
        emit(EspbFormListLoaded(forms: forms, isConnected: _isConnected));
      },
    );
  }

  Future<void> _onConnectivityChanged(
    ConnectivityChanged event,
    Emitter<EspbFormState> emit,
  ) async {
    // Update current state with new connectivity status
    if (state is EspbFormListLoaded) {
      final currentState = state as EspbFormListLoaded;
      emit(EspbFormListLoaded(
        forms: currentState.forms,
        isConnected: event.isConnected,
      ));
    }
    
    // If we just got connected, trigger sync
    if (event.isConnected) {
      add(const SyncAllFormsRequested());
    }
  }

  // Helper methods to reduce code duplication
  
  Future<Either<Failure, EspbFormData>> _getFormData(String formId) async {
    try {
      final repository = _saveEspbFormUseCase.repository;
      return await repository.getFormData(formId);
    } catch (e) {
      return Left(ServerFailure('Failed to get form data: $e'));
    }
  }
  
  Future<Either<Failure, List<EspbFormData>>> _getPendingForms() async {
    try {
      final repository = _saveEspbFormUseCase.repository;
      return await repository.getAllPendingForms();
    } catch (e) {
      return Left(ServerFailure('Failed to get pending forms: $e'));
    }
  }
  
  Future<Either<Failure, List<EspbFormData>>> _getFormsForSpb(String noSpb) async {
    try {
      final repository = _saveEspbFormUseCase.repository;
      return await repository.getFormDataForSpb(noSpb);
    } catch (e) {
      return Left(ServerFailure('Failed to get forms for SPB: $e'));
    }
  }
}