import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/utils/session_manager.dart';
import '../../../../core/auth/auth_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/error/failures.dart';
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RefreshTokenUseCase refreshTokenUseCase;
  final SessionManager? sessionManager;
  final AuthService authService;

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isConnected = true;

  // Token refresh timer
  Timer? _tokenRefreshTimer;
  final Duration _tokenRefreshInterval = const Duration(minutes: 10);

  // Retry configuration
  int _retryAttempt = 0;
  final int _maxRetryAttempts = 5;
  final Duration _initialBackoffDuration = const Duration(seconds: 5);
  Timer? _retryTimer;
  
  // Auth service subscription
  StreamSubscription? _authStateSubscription;

  AuthBloc({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.refreshTokenUseCase,
    required this.authService,
    this.sessionManager,
  }) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTokenValidationRequested>(_onAuthTokenValidationRequested);
    on<AuthTokenRefreshRequested>(_onAuthTokenRefreshRequested);
    on<AuthConnectivityChanged>(_onAuthConnectivityChanged);
    on<AuthSessionStatusChanged>(_onAuthSessionStatusChanged);
    on<AuthRetryRequested>(_onAuthRetryRequested);
    on<AuthServiceStateChanged>(_onAuthServiceStateChanged);

    // Initialize connectivity monitoring
    _initConnectivityMonitoring();

    // Listen for session state changes if session manager is provided
    if (sessionManager != null) {
      sessionManager!.sessionState.addListener(_onSessionStateChanged);
    }
    
    // Listen for auth service state changes
    _listenToAuthService();
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _tokenRefreshTimer?.cancel();
    _retryTimer?.cancel();
    _authStateSubscription?.cancel();
    if (sessionManager != null) {
      sessionManager!.sessionState.removeListener(_onSessionStateChanged);
    }
    return super.close();
  }
  
  void _listenToAuthService() {
    // Listen to auth service state changes
    authService.authState.addListener(() {
      add(AuthServiceStateChanged(authService.authState.value));
    });
  }

  void _initConnectivityMonitoring() {
    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      _updateConnectivityStatus(result);
    });

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      _updateConnectivityStatus(result);
    });
  }

  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected =
        result.isNotEmpty && !result.contains(ConnectivityResult.none);

    // If connectivity status changed, dispatch event
    if (wasConnected != _isConnected) {
      add(AuthConnectivityChanged(isConnected: _isConnected));
    }
  }

  void _onSessionStateChanged() {
    if (sessionManager != null) {
      add(AuthSessionStatusChanged(sessionManager!.sessionState.value));
    }
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) {
      add(const AuthTokenRefreshRequested());
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Check if session is active if session manager is available
      if (sessionManager != null) {
        final isSessionActive = await sessionManager!.isSessionActive();
        if (!isSessionActive) {
          emit(const AuthUnauthenticated());
          return;
        }
      }

      // Check if user is logged in with auth service
      final isLoggedIn = await authService.isSessionValid();
      
      if (isLoggedIn) {
        // Get user data
        final userResult = await loginUseCase.repository.getCurrentUser();
        
        await userResult.fold(
          (failure) async {
            emit(const AuthUnauthenticated());
          },
          (user) async {
            emit(AuthAuthenticated(user: user));
            
            // Start token refresh timer
            _startTokenRefreshTimer();
            
            // Update session activity if session manager is available
            if (sessionManager != null) {
              await sessionManager!.updateLastActivity();
            }
          },
        );
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Failed to check authentication status: $e'));
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    // Reset retry counter on new login attempt
    _retryAttempt = 0;

    // Use auth service for login
    final success = await authService.login(event.userName, event.password);
    
    if (success) {
      // Get user data
      final userResult = await loginUseCase.repository.getCurrentUser();
      
      await userResult.fold(
        (failure) async {
          emit(AuthError(failure.message));
        },
        (user) async {
          emit(AuthAuthenticated(user: user));
          
          // Start token refresh timer
          _startTokenRefreshTimer();
          
          // Update session activity if session manager is available
          if (sessionManager != null) {
            await sessionManager!.updateLastActivity();
          }
        },
      );
    } else {
      // Login failed
      emit(AuthError(authService.authState.value == AuthState.error 
          ? 'Authentication failed' 
          : 'Invalid credentials'));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    // Log the reason if provided
    if (event.reason != null) {
      AppLogger.info('Logout requested: ${event.reason}');
    }

    // Use auth service for logout
    final success = await authService.logout();

    // Cancel token refresh timer
    _tokenRefreshTimer?.cancel();

    // Clear session if session manager is available
    if (sessionManager != null) {
      await sessionManager!.clearSession();
    }

    if (success) {
      emit(const AuthUnauthenticated());
    } else {
      // Even if logout fails, we should consider the user logged out locally
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthTokenValidationRequested(
    AuthTokenValidationRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Don't change state to loading to avoid UI flicker during background validation

    final result = await refreshTokenUseCase.validateToken();

    await result.fold(
      (failure) async {
        // Token is invalid
        if (state is AuthAuthenticated) {
          // Only emit unauthenticated if we were previously authenticated
          emit(const AuthUnauthenticated());
        }
      },
      (isValid) async {
        if (!isValid && state is AuthAuthenticated) {
          // Token is invalid and we were authenticated
          emit(const AuthUnauthenticated());
        }
        // If valid, keep current state
      },
    );
  }

  Future<void> _onAuthTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Only refresh if we're authenticated
    if (state is! AuthAuthenticated) {
      return;
    }

    // Don't change state to loading to avoid UI flicker during background refresh

    final result = await refreshTokenUseCase.forceRefresh();

    await result.fold(
      (failure) async {
        // Token refresh failed
        AppLogger.warning('Token refresh failed: ${failure.message}');

        // If it's a network error, don't log out - we'll try again later
        if (failure is NetworkFailure || failure is TimeoutFailure) {
          // Schedule retry with backoff if we're still connected
          if (_isConnected && _retryAttempt < _maxRetryAttempts) {
            _scheduleTokenRefreshRetry();
          }
        } else if (failure is RateLimitFailure) {
          // For rate limit failures, log but don't log out
          AppLogger.warning('Token refresh rate limited: ${failure.message}');
        } else {
          // For other errors, log out
          emit(const AuthUnauthenticated());
        }
      },
      (tokens) async {
        // Token refresh successful, reset retry counter
        _retryAttempt = 0;

        // Update session activity if session manager is available
        if (sessionManager != null) {
          await sessionManager!.updateLastActivity();
        }

        // No need to update state, we're still authenticated
      },
    );
  }

  void _scheduleTokenRefreshRetry() {
    // Calculate backoff duration with exponential increase
    final backoffDuration = _initialBackoffDuration * (1 << _retryAttempt);

    AppLogger.info(
      'Scheduling token refresh retry in ${backoffDuration.inSeconds} seconds (attempt ${_retryAttempt + 1}/${_maxRetryAttempts})',
    );

    // Schedule retry
    _retryTimer?.cancel();
    _retryTimer = Timer(backoffDuration, () {
      _retryAttempt++;
      add(const AuthTokenRefreshRequested());
    });
  }

  Future<void> _onAuthConnectivityChanged(
    AuthConnectivityChanged event,
    Emitter<AuthState> emit,
  ) async {
    // If we just got connected and we're authenticated, refresh token
    if (event.isConnected && state is AuthAuthenticated) {
      // Validate token with server after reconnection
      final result = await refreshTokenUseCase.handleReconnection();
      
      await result.fold(
        (failure) async {
          // Token validation failed after reconnection
          AppLogger.warning('Token validation failed after reconnection: ${failure.message}');
          
          // If it's a network error, don't log out - we'll try again later
          if (failure is NetworkFailure || failure is TimeoutFailure) {
            // Schedule retry with backoff
            if (_retryAttempt < _maxRetryAttempts) {
              _scheduleTokenRefreshRetry();
            }
          } else {
            // For other errors, log out
            emit(const AuthUnauthenticated());
          }
        },
        (isValid) async {
          if (!isValid) {
            // Token is invalid after reconnection
            emit(const AuthUnauthenticated());
          }
          // If valid, keep current state
        },
      );
    }

    // No state change needed, just updating internal connectivity status
  }

  Future<void> _onAuthSessionStatusChanged(
    AuthSessionStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    // React to session state changes
    switch (event.status) {
      case SessionState.expiring:
        // Token is about to expire, validate it
        add(const AuthTokenValidationRequested());
        break;
      case SessionState.timeout:
        // Session timed out, log out
        add(const AuthLogoutRequested(reason: 'Session timeout'));
        break;
      case SessionState.inactive:
        // Session is inactive, log out
        add(const AuthLogoutRequested(reason: 'Session inactive'));
        break;
      case SessionState.error:
        // Session error, log out
        add(const AuthLogoutRequested(reason: 'Session error'));
        break;
      default:
        // No action needed for other states
        break;
    }
  }

  Future<void> _onAuthRetryRequested(
    AuthRetryRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Check current state
    if (state is AuthError) {
      // If we're in error state, try to check auth status again
      add(const AuthCheckRequested());
    } else if (state is AuthUnauthenticated) {
      // If we're unauthenticated, we can't retry
      // User needs to log in again
    }
  }
  
  Future<void> _onAuthServiceStateChanged(
    AuthServiceStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.authState) {
      case AuthState.authenticated:
        // Get user data
        final userResult = await loginUseCase.repository.getCurrentUser();
        
        await userResult.fold(
          (failure) async {
            emit(AuthError(failure.message));
          },
          (user) async {
            emit(AuthAuthenticated(user: user));
            
            // Start token refresh timer
            _startTokenRefreshTimer();
            
            // Update session activity if session manager is available
            if (sessionManager != null) {
              await sessionManager!.updateLastActivity();
            }
          },
        );
        break;
        
      case AuthState.unauthenticated:
      case AuthState.sessionExpired:
        emit(const AuthUnauthenticated());
        break;
        
      case AuthState.error:
        emit(AuthError(authService.authState.value.toString()));
        break;
        
      case AuthState.authenticating:
      case AuthState.loggingOut:
        emit(const AuthLoading());
        break;
        
      case AuthState.unknown:
        // Do nothing, wait for a definitive state
        break;
    }
  }
}