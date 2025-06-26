part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final User user;
  final SyncStatus syncStatus;
  final String? syncError;
  final DateTime? lastSyncTime;
  final String? updateError;

  const ProfileLoaded({
    required this.user,
    this.syncStatus = SyncStatus.idle,
    this.syncError,
    this.lastSyncTime,
    this.updateError,
  });
  ProfileLoaded copyWith({
    User? user,
    SyncStatus? syncStatus,
    String? syncError,
    DateTime? lastSyncTime,
    String? updateError,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      updateError: updateError,
    );
  }

  @override
  List<Object?> get props => [
    user,
    syncStatus,
    syncError,
    lastSyncTime,
    updateError,
  ];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}

class PasswordChangeLoading extends ProfileState {
  const PasswordChangeLoading();
}

class PasswordChangeSuccess extends ProfileState {
  final String message;

  const PasswordChangeSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class PasswordChangeError extends ProfileState {
  final String message;

  const PasswordChangeError(this.message);

  @override
  List<Object> get props => [message];
}

class ProfileUpdating extends ProfileState {
  final User user;

  const ProfileUpdating({required this.user});

  @override
  List<Object> get props => [user];
}

class ProfileUpdateSuccess extends ProfileState {
  final String message;
  final User user;

  const ProfileUpdateSuccess({required this.message, required this.user});

  @override
  List<Object> get props => [message, user];
}

class ProfileUpdateError extends ProfileState {
  final String message;
  final User user;

  const ProfileUpdateError({required this.message, required this.user});

  @override
  List<Object> get props => [message, user];
}
