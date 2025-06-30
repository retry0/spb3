part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String userName;
  final String password;

  const AuthLoginRequested({required this.userName, required this.password});

  @override
  List<Object> get props => [userName, password];
}

class AuthLogoutRequested extends AuthEvent {
  final String? reason;

  const AuthLogoutRequested({this.reason});

  @override
  List<Object?> get props => reason != null ? [reason!] : [];
}

class AuthTokenValidationRequested extends AuthEvent {
  const AuthTokenValidationRequested();
}

class AuthTokenRefreshRequested extends AuthEvent {
  const AuthTokenRefreshRequested();
}

class AuthConnectivityChanged extends AuthEvent {
  final bool isConnected;

  const AuthConnectivityChanged({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}

class AuthSessionStatusChanged extends AuthEvent {
  final SessionState status;

  const AuthSessionStatusChanged(this.status);

  @override
  List<Object> get props => [status];
}

class AuthRetryRequested extends AuthEvent {
  const AuthRetryRequested();
}

class AuthServiceStateChanged extends AuthEvent {
  final auth_service.AuthState authState;

  const AuthServiceStateChanged(this.authState);

  @override
  List<Object> get props => [authState];
}
