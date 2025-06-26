part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class PasswordChangeRequested extends ProfileEvent {
  final String userName;
  final String oldPassword;
  final String newPassword;
  final String confirmPassword;
  final String requestor;

  const PasswordChangeRequested({
    required this.userName,
    required this.oldPassword,
    required this.newPassword,
    required this.confirmPassword,
    required this.requestor,
  });

  @override
  List<Object> get props => [
    userName,
    oldPassword,
    newPassword,
    confirmPassword,
    requestor,
  ];
}

class ProfileUpdateRequested extends ProfileEvent {
  final User user;

  const ProfileUpdateRequested({required this.user});

  @override
  List<Object> get props => [user];
}

class ProfileSyncRequested extends ProfileEvent {
  const ProfileSyncRequested();
}

class ProfileSyncStatusChanged extends ProfileEvent {
  final SyncStatus status;
  final String? error;
  final DateTime? lastSyncTime;

  const ProfileSyncStatusChanged({
    required this.status,
    this.error,
    this.lastSyncTime,
  });

  @override
  List<Object?> get props => [status, error, lastSyncTime];
}
