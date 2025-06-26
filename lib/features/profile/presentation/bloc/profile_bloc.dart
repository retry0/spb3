import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../../../core/storage/user_profile_repository.dart';
import '../../../../core/services/sync_service.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;
  final ChangePasswordUseCase _changePasswordUseCase;
  final UserProfileRepository _userProfileRepository;
  final SyncService _syncService;
  // Subscriptions
  StreamSubscription? _syncStatusSubscription;

  ProfileBloc({
    required ProfileRepository profileRepository,
    required ChangePasswordUseCase changePasswordUseCase,
    required UserProfileRepository userProfileRepository,
    required SyncService syncService,
  }) : _profileRepository = profileRepository,
       _changePasswordUseCase = changePasswordUseCase,
       _userProfileRepository = userProfileRepository,
       _syncService = syncService,
       super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<PasswordChangeRequested>(_onPasswordChangeRequested);
    on<ProfileUpdateRequested>(_onProfileUpdateRequested);
    on<ProfileSyncRequested>(_onProfileSyncRequested);
    on<ProfileSyncStatusChanged>(_onProfileSyncStatusChanged);

    // Listen to sync status changes
    _listenToSyncChanges();
  }

  void _listenToSyncChanges() {
    // Listen to sync status changes
    _syncService.syncStatusNotifier.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    add(
      ProfileSyncStatusChanged(
        status: _syncService.syncStatusNotifier.value,
        error: _syncService.syncErrorNotifier.value,
        lastSyncTime: _syncService.lastSyncTimeNotifier.value,
      ),
    );
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _profileRepository.getUserProfile();

    await result.fold(
      (failure) async {
        emit(ProfileError(failure.message));
      },
      (user) async {
        // Get sync status
        final syncStatus = _syncService.syncStatusNotifier.value;
        final syncError = _syncService.syncErrorNotifier.value;
        final lastSyncTime = _syncService.lastSyncTimeNotifier.value;

        emit(
          ProfileLoaded(
            user: user,
            syncStatus: syncStatus,
            syncError: syncError,
            lastSyncTime: lastSyncTime,
          ),
        );

        // Trigger background sync if not already syncing
        if (syncStatus != SyncStatus.syncing) {
          _syncService.syncUserProfile(silent: true);
        }
      },
    );
  }

  Future<void> _onPasswordChangeRequested(
    PasswordChangeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // Keep current profile state while changing password
    final currentState = state;
    emit(const PasswordChangeLoading());

    // Validate password confirmation
    if (event.newPassword != event.confirmPassword) {
      emit(const PasswordChangeError('New passwords do not match'));
      // Restore previous state
      emit(currentState);
      return;
    }

    // // Validate password complexity
    // final passwordValidationError = _validatePasswordComplexity(event.newPassword);
    // if (passwordValidationError != null) {
    //   emit(PasswordChangeError(passwordValidationError));
    //   emit(currentState);
    //   return;
    // }

    final result = await _changePasswordUseCase(
      userName: event.userName,
      oldPassword: event.oldPassword,
      newPassword: event.newPassword,
      requestor: event.requestor,
    );

    await result.fold(
      (failure) async {
        emit(PasswordChangeError(failure.message));
        // Restore previous state
        emit(currentState);
      },
      (_) async {
        emit(
          const PasswordChangeSuccess(
            'Password changed successfully. You will be redirected to login.',
          ),
        );
        // Don't restore previous state - user will be redirected to login
      },
    );
  }

  // String? _validatePasswordComplexity(String password) {
  //   if (password.length < 8) {
  //     return 'Password must be at least 8 characters long';
  //   }

  //   bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
  //   bool hasDigit = password.contains(RegExp(r'[0-9]'));
  //   bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  //   if (!hasUppercase) {
  //     return 'Password must contain at least one uppercase letter';
  //   }
  //   if (!hasDigit) {
  //     return 'Password must contain at least one digit';
  //   }
  //   if (!hasSpecialChar) {
  //     return 'Password must contain at least one special character';
  //   }

  //   return null;
  // }

  Future<void> _onProfileUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // Keep current profile state while updating
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(ProfileUpdating(user: currentState.user));

      final result = await _profileRepository.updateUserProfile(event.user);

      await result.fold(
        (failure) async {
          emit(
            ProfileUpdateError(
              message: failure.message,
              user: currentState.user,
            ),
          );
          // Restore previous state with error
          emit(currentState.copyWith(updateError: failure.message));
        },
        (updatedUser) async {
          emit(
            ProfileUpdateSuccess(
              message: 'Profile updated successfully',
              user: updatedUser,
            ),
          );

          // Update current state with new user data
          emit(currentState.copyWith(user: updatedUser, updateError: null));

          // Trigger sync
          _syncService.syncUserProfile();
        },
      );
    }
  }

  Future<void> _onProfileSyncRequested(
    ProfileSyncRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      // Update state to show syncing
      emit(
        currentState.copyWith(syncStatus: SyncStatus.syncing, syncError: null),
      );

      // Trigger sync
      final success = await _syncService.forceSyncNow();

      if (!success) {
        // If sync failed, update state with error
        emit(
          currentState.copyWith(
            syncStatus: SyncStatus.failed,
            syncError: _syncService.syncErrorNotifier.value,
          ),
        );

        // Reload profile to get latest data
        add(const ProfileLoadRequested());
      }
    }
  }

  void _onProfileSyncStatusChanged(
    ProfileSyncStatusChanged event,
    Emitter<ProfileState> emit,
  ) {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(
        currentState.copyWith(
          syncStatus: event.status,
          syncError: event.error,
          lastSyncTime: event.lastSyncTime,
        ),
      );

      // If sync was successful, reload profile to get latest data
      if (event.status == SyncStatus.success) {
        add(const ProfileLoadRequested());
      }
    }
  }

  @override
  Future<void> close() {
    _syncStatusSubscription?.cancel();
    _syncService.syncStatusNotifier.removeListener(_onSyncStatusChanged);
    return super.close();
  }
}
