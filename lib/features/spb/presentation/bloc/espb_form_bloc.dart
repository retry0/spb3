import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/espb_form_model.dart';
import '../../domain/usecases/save_espb_form_usecase.dart';
import '../../domain/usecases/get_espb_form_usecase.dart';
import '../../domain/usecases/sync_espb_form_usecase.dart';
import '../../domain/usecases/sync_all_pending_espb_forms_usecase.dart';
import '../../domain/usecases/migrate_espb_forms_usecase.dart';

part 'espb_form_event.dart';
part 'espb_form_state.dart';

class EspbFormBloc extends Bloc<EspbFormEvent, EspbFormState> {
  final SaveEspbFormUseCase _saveEspbFormUseCase;
  final GetEspbFormUseCase _getEspbFormUseCase;
  final SyncEspbFormUseCase _syncEspbFormUseCase;
  final SyncAllPendingEspbFormsUseCase _syncAllPendingEspbFormsUseCase;
  final MigrateEspbFormsUseCase _migrateEspbFormsUseCase;

  EspbFormBloc({
    required SaveEspbFormUseCase saveEspbFormUseCase,
    required GetEspbFormUseCase getEspbFormUseCase,
    required SyncEspbFormUseCase syncEspbFormUseCase,
    required SyncAllPendingEspbFormsUseCase syncAllPendingEspbFormsUseCase,
    required MigrateEspbFormsUseCase migrateEspbFormsUseCase,
  }) : _saveEspbFormUseCase = saveEspbFormUseCase,
       _getEspbFormUseCase = getEspbFormUseCase,
       _syncEspbFormUseCase = syncEspbFormUseCase,
       _syncAllPendingEspbFormsUseCase = syncAllPendingEspbFormsUseCase,
       _migrateEspbFormsUseCase = migrateEspbFormsUseCase,
       super(EspbFormInitial()) {
    on<EspbFormSaveRequested>(_onEspbFormSaveRequested);
    on<EspbFormLoadRequested>(_onEspbFormLoadRequested);
    on<EspbFormSyncRequested>(_onEspbFormSyncRequested);
    on<EspbFormSyncAllRequested>(_onEspbFormSyncAllRequested);
    on<EspbFormMigrateRequested>(_onEspbFormMigrateRequested);
  }

  Future<void> _onEspbFormSaveRequested(
    EspbFormSaveRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSaving(spbNumber: event.formData.noSpb));

    try {
      // Validate GPS data if not provided
      EspbFormModel formData = event.formData;
      
      if (formData.latitude == "0.0" || formData.longitude == "0.0") {
        try {
          final position = await Geolocator.getCurrentPosition();
          formData = formData.copyWith(
            latitude: position.latitude.toString(),
            longitude: position.longitude.toString(),
          );
        } catch (e) {
          // Continue with default coordinates if GPS fails
        }
      }

      final result = await _saveEspbFormUseCase(formData);

      await result.fold(
        (failure) async {
          emit(EspbFormSaveFailure(
            spbNumber: formData.noSpb,
            message: failure.message,
          ));
        },
        (isSynced) async {
          emit(EspbFormSaveSuccess(
            spbNumber: formData.noSpb,
            isSynced: isSynced,
          ));
        },
      );
    } catch (e) {
      emit(EspbFormSaveFailure(
        spbNumber: event.formData.noSpb,
        message: 'Unexpected error: $e',
      ));
    }
  }

  Future<void> _onEspbFormLoadRequested(
    EspbFormLoadRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormLoading(spbNumber: event.spbNumber));

    try {
      final result = await _getEspbFormUseCase(event.spbNumber);

      await result.fold(
        (failure) async {
          emit(EspbFormLoadFailure(
            spbNumber: event.spbNumber,
            message: failure.message,
          ));
        },
        (formData) async {
          if (formData != null) {
            emit(EspbFormLoaded(formData: formData));
          } else {
            emit(EspbFormEmpty(spbNumber: event.spbNumber));
          }
        },
      );
    } catch (e) {
      emit(EspbFormLoadFailure(
        spbNumber: event.spbNumber,
        message: 'Unexpected error: $e',
      ));
    }
  }

  Future<void> _onEspbFormSyncRequested(
    EspbFormSyncRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSyncing(spbNumber: event.spbNumber));

    try {
      final result = await _syncEspbFormUseCase(event.spbNumber);

      await result.fold(
        (failure) async {
          emit(EspbFormSyncFailure(
            spbNumber: event.spbNumber,
            message: failure.message,
          ));
        },
        (success) async {
          if (success) {
            emit(EspbFormSyncSuccess(spbNumber: event.spbNumber));
          } else {
            emit(EspbFormSyncFailure(
              spbNumber: event.spbNumber,
              message: 'Sync failed',
            ));
          }
        },
      );
    } catch (e) {
      emit(EspbFormSyncFailure(
        spbNumber: event.spbNumber,
        message: 'Unexpected error: $e',
      ));
    }
  }

  Future<void> _onEspbFormSyncAllRequested(
    EspbFormSyncAllRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormSyncingAll());

    try {
      final result = await _syncAllPendingEspbFormsUseCase();

      await result.fold(
        (failure) async {
          emit(EspbFormSyncAllFailure(message: failure.message));
        },
        (syncCount) async {
          emit(EspbFormSyncAllSuccess(syncedCount: syncCount));
        },
      );
    } catch (e) {
      emit(EspbFormSyncAllFailure(message: 'Unexpected error: $e'));
    }
  }

  Future<void> _onEspbFormMigrateRequested(
    EspbFormMigrateRequested event,
    Emitter<EspbFormState> emit,
  ) async {
    emit(EspbFormMigrating());

    try {
      final result = await _migrateEspbFormsUseCase();

      await result.fold(
        (failure) async {
          emit(EspbFormMigrateFailure(message: failure.message));
        },
        (_) async {
          emit(EspbFormMigrateSuccess());
        },
      );
    } catch (e) {
      emit(EspbFormMigrateFailure(message: 'Unexpected error: $e'));
    }
  }
}