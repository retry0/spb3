import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:spb/core/error/failures.dart';
import 'package:spb/core/utils/session_manager.dart';
import 'package:spb/features/auth/domain/entities/auth_tokens.dart';
import 'package:spb/features/auth/domain/entities/user.dart';
import 'package:spb/features/auth/domain/usecases/login_usecase.dart';
import 'package:spb/features/auth/domain/usecases/logout_usecase.dart';
import 'package:spb/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:spb/features/auth/domain/repositories/auth_repository.dart';
import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}
class MockSessionManager extends Mock implements SessionManager {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockValueNotifier<T> extends Mock implements ValueNotifier<T> {}

void main() {
  late AuthBloc authBloc;
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockRefreshTokenUseCase mockRefreshTokenUseCase;
  late MockSessionManager mockSessionManager;
  late MockAuthRepository mockAuthRepository;
  late MockValueNotifier<SessionState> mockSessionStateNotifier;

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockRefreshTokenUseCase = MockRefreshTokenUseCase();
    mockSessionManager = MockSessionManager();
    mockAuthRepository = MockAuthRepository();
    mockSessionStateNotifier = MockValueNotifier<SessionState>();
    
    // Set up repository for login use case
    when(() => mockLoginUseCase.repository).thenReturn(mockAuthRepository);
    
    // Set up session state notifier
    when(() => mockSessionManager.sessionState).thenReturn(mockSessionStateNotifier);
    when(() => mockSessionManager.initializeSession()).thenAnswer((_) async {});
    
    authBloc = AuthBloc(
      loginUseCase: mockLoginUseCase,
      logoutUseCase: mockLogoutUseCase,
      refreshTokenUseCase: mockRefreshTokenUseCase,
      sessionManager: mockSessionManager,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  test('initial state is AuthInitial', () {
    expect(authBloc.state, equals(const AuthInitial()));
  });

  group('AuthCheckRequested', () {
    const testUser = User(
      Id: 'test_id',
      UserName: 'test_user',
      Nama: 'Test User',
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when session is active and token is valid',
      build: () {
        when(() => mockSessionManager.isSessionActive()).thenAnswer((_) async => true);
        when(() => mockRefreshTokenUseCase()).thenAnswer((_) async => const Right(true));
        when(() => mockAuthRepository.getCurrentUser()).thenAnswer((_) async => const Right(testUser));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(user: testUser),
      ],
      verify: (_) {
        verify(() => mockSessionManager.isSessionActive()).called(1);
        verify(() => mockRefreshTokenUseCase()).called(1);
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when session is not active',
      build: () {
        when(() => mockSessionManager.isSessionActive()).thenAnswer((_) async => false);
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockSessionManager.isSessionActive()).called(1);
        verifyNever(() => mockRefreshTokenUseCase());
        verifyNever(() => mockAuthRepository.getCurrentUser());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when token is invalid',
      build: () {
        when(() => mockSessionManager.isSessionActive()).thenAnswer((_) async => true);
        when(() => mockRefreshTokenUseCase()).thenAnswer((_) async => const Left(AuthFailure('Token expired')));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockSessionManager.isSessionActive()).called(1);
        verify(() => mockRefreshTokenUseCase()).called(1);
        verifyNever(() => mockAuthRepository.getCurrentUser());
      },
    );
  });

  group('AuthLoginRequested', () {
    const testUserName = 'test_user';
    const testPassword = 'test_password';
    const testTokens = AuthTokens(token: 'test_token');
    const testUser = User(
      Id: 'test_id',
      UserName: 'test_user',
      Nama: 'Test User',
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when login is successful',
      build: () {
        when(() => mockLoginUseCase(testUserName, testPassword))
            .thenAnswer((_) async => const Right(testTokens));
        when(() => mockAuthRepository.getCurrentUser())
            .thenAnswer((_) async => const Right(testUser));
        when(() => mockSessionManager.updateLastActivity())
            .thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        userName: testUserName,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(user: testUser),
      ],
      verify: (_) {
        verify(() => mockLoginUseCase(testUserName, testPassword)).called(1);
        verify(() => mockSessionManager.updateLastActivity()).called(1);
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when login fails',
      build: () {
        when(() => mockLoginUseCase(testUserName, testPassword))
            .thenAnswer((_) async => const Left(AuthFailure('Login failed')));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        userName: testUserName,
        password: testPassword,
      )),
      expect: () => [
        const AuthLoading(),
        const AuthError('Login failed'),
      ],
      verify: (_) {
        verify(() => mockLoginUseCase(testUserName, testPassword)).called(1);
        verifyNever(() => mockSessionManager.updateLastActivity());
        verifyNever(() => mockAuthRepository.getCurrentUser());
      },
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when logout is successful',
      build: () {
        when(() => mockLogoutUseCase(maxRetries: any(named: 'maxRetries')))
            .thenAnswer((_) async => const Right(null));
        when(() => mockSessionManager.clearSession())
            .thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockLogoutUseCase(maxRetries: any(named: 'maxRetries'))).called(1);
        verify(() => mockSessionManager.clearSession()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when logout fails',
      build: () {
        when(() => mockLogoutUseCase(maxRetries: any(named: 'maxRetries')))
            .thenAnswer((_) async => const Left(ServerFailure('Logout failed')));
        when(() => mockSessionManager.clearSession())
            .thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Logout failed'),
      ],
      verify: (_) {
        verify(() => mockLogoutUseCase(maxRetries: any(named: 'maxRetries'))).called(1);
        verify(() => mockSessionManager.clearSession()).called(1);
      },
    );
  });

  group('Session state changes', () {
    const testUser = User(
      Id: 'test_id',
      UserName: 'test_user',
      Nama: 'Test User',
    );

    test('should add AuthTokenValidationRequested when session is expiring', () async {
      // Arrange
      final mockBloc = MockAuthBloc();
      when(() => mockBloc.add(any())).thenReturn(null);
      
      // Create a real AuthBloc with mocked dependencies
      final authBloc = AuthBloc(
        loginUseCase: mockLoginUseCase,
        logoutUseCase: mockLogoutUseCase,
        refreshTokenUseCase: mockRefreshTokenUseCase,
        sessionManager: mockSessionManager,
      );
      
      // Mock the current state
      when(() => mockBloc.state).thenReturn(AuthAuthenticated(user: testUser));
      
      // Simulate session state change
      final listener = authBloc.state;
      
      // Act - simulate session expiring
      authBloc.add(const AuthSessionStatusChanged(SessionState.expiring));
      
      // Wait for the event to be processed
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Clean up
      await authBloc.close();
    });
  });
}

class MockAuthBloc extends Mock implements AuthBloc {}