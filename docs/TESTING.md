# Testing Documentation

## Overview

This document outlines the comprehensive testing strategy for the SPB Secure Flutter application, covering unit tests, widget tests, integration tests, and end-to-end testing approaches.

## Testing Philosophy

Our testing approach follows the **Testing Pyramid** principle:

```
    /\
   /  \     E2E Tests (Few)
  /____\    
 /      \   Integration Tests (Some)
/__________\ Unit Tests (Many)
```

- **Unit Tests (70%)**: Fast, isolated tests for business logic
- **Widget Tests (20%)**: UI component testing
- **Integration Tests (10%)**: End-to-end user flows

## Test Structure

```
test/
├── unit/                           # Unit tests
│   ├── core/                      # Core functionality tests
│   │   ├── config/
│   │   ├── network/
│   │   ├── storage/
│   │   └── utils/
│   └── features/                  # Feature-specific tests
│       ├── auth/
│       ├── home/
│       └── data/
├── widget/                        # Widget tests
│   ├── pages/
│   ├── widgets/
│   └── components/
├── integration/                   # Integration tests
│   ├── auth_flow_test.dart
│   ├── data_management_test.dart
│   └── user_journey_test.dart
├── helpers/                       # Test utilities
│   ├── test_helpers.dart
│   ├── mock_data.dart
│   └── test_constants.dart
└── mocks/                         # Mock objects
    ├── mock_repositories.dart
    ├── mock_data_sources.dart
    └── mock_services.dart
```

## Unit Testing

### Testing Framework Setup

```dart
// test/helpers/test_helpers.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

class TestHelpers {
  static void setupTestDependencies() {
    GetIt.instance.reset();
    // Register test dependencies
  }

  static void tearDownTestDependencies() {
    GetIt.instance.reset();
  }
}

// Base test class
abstract class BaseTest {
  void setUp() {
    TestHelpers.setupTestDependencies();
  }

  void tearDown() {
    TestHelpers.tearDownTestDependencies();
  }
}
```

### BLoC Testing

```dart
// test/unit/features/auth/auth_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/core/error/failures.dart';
import 'package:spb/features/auth/domain/entities/auth_tokens.dart';
import 'package:spb/features/auth/domain/usecases/login_usecase.dart';
import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}
class MockCheckUserNameAvailabilityUseCase extends Mock 
    implements CheckUserNameAvailabilityUseCase {}

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    late MockLoginUseCase mockLoginUseCase;
    late MockLogoutUseCase mockLogoutUseCase;
    late MockRefreshTokenUseCase mockRefreshTokenUseCase;
    late MockCheckUserNameAvailabilityUseCase mockCheckUserNameAvailabilityUseCase;

    setUp(() {
      mockLoginUseCase = MockLoginUseCase();
      mockLogoutUseCase = MockLogoutUseCase();
      mockRefreshTokenUseCase = MockRefreshTokenUseCase();
      mockCheckUserNameAvailabilityUseCase = MockCheckUserNameAvailabilityUseCase();
      
      authBloc = AuthBloc(
        loginUseCase: mockLoginUseCase,
        logoutUseCase: mockLogoutUseCase,
        refreshTokenUseCase: mockRefreshTokenUseCase,
        checkUserNameAvailabilityUseCase: mockCheckUserNameAvailabilityUseCase,
      );
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(const AuthInitial()));
    });

    group('AuthLoginRequested', () {
      const testUserName = 'test_user';
      const testPassword = 'test_password';
      const testTokens = AuthTokens(accessToken: 'test_token');

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] when login succeeds',
        build: () {
          when(() => mockLoginUseCase(testUserName, testPassword))
              .thenAnswer((_) async => const Right(testTokens));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          userName: testUserName,
          password: testPassword,
        )),
        expect: () => [
          const AuthLoading(),
          isA<AuthAuthenticated>(),
        ],
        verify: (_) {
          verify(() => mockLoginUseCase(testUserName, testPassword)).called(1);
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
      );
    });

    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthUnauthenticated] when logout succeeds',
        build: () {
          when(() => mockLogoutUseCase())
              .thenAnswer((_) async => const Right(null));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLogoutRequested()),
        expect: () => [
          const AuthLoading(),
          const AuthUnauthenticated(),
        ],
      );
    });
  });
}
```

### Repository Testing

```dart
// test/unit/features/auth/data/repositories/auth_repository_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/core/error/exceptions.dart';
import 'package:spb/core/error/failures.dart';
import 'package:spb/features/auth/data/models/auth_tokens_model.dart';
import 'package:spb/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  group('AuthRepositoryImpl', () {
    late AuthRepositoryImpl repository;
    late MockAuthRemoteDataSource mockRemoteDataSource;
    late MockAuthLocalDataSource mockLocalDataSource;

    setUp(() {
      mockRemoteDataSource = MockAuthRemoteDataSource();
      mockLocalDataSource = MockAuthLocalDataSource();
      repository = AuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    group('loginWithUserName', () {
      const testUserName = 'test_user';
      const testPassword = 'test_password';
      const testTokens = AuthTokensModel(accessToken: 'test_token');

      test('should return AuthTokens when login is successful', () async {
        // Arrange
        when(() => mockRemoteDataSource.loginWithUserName(any()))
            .thenAnswer((_) async => testTokens);
        when(() => mockLocalDataSource.saveToken(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.loginWithUserName(testUserName, testPassword);

        // Assert
        expect(result, equals(const Right(testTokens)));
        verify(() => mockRemoteDataSource.loginWithUserName({
          'userName': testUserName,
          'password': testPassword,
        })).called(1);
        verify(() => mockLocalDataSource.saveToken(testTokens.accessToken)).called(1);
      });

      test('should return AuthFailure when remote data source throws AuthException', () async {
        // Arrange
        when(() => mockRemoteDataSource.loginWithUserName(any()))
            .thenThrow(const AuthException('Invalid credentials'));

        // Act
        final result = await repository.loginWithUserName(testUserName, testPassword);

        // Assert
        expect(result, equals(const Left(AuthFailure('Invalid credentials'))));
        verifyNever(() => mockLocalDataSource.saveToken(any()));
      });

      test('should return NetworkFailure when remote data source throws NetworkException', () async {
        // Arrange
        when(() => mockRemoteDataSource.loginWithUserName(any()))
            .thenThrow(const NetworkException('Network error'));

        // Act
        final result = await repository.loginWithUserName(testUserName, testPassword);

        // Assert
        expect(result, equals(const Left(NetworkFailure('Network error'))));
      });
    });
  });
}
```

### Use Case Testing

```dart
// test/unit/features/auth/domain/usecases/login_usecase_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/core/error/failures.dart';
import 'package:spb/features/auth/domain/entities/auth_tokens.dart';
import 'package:spb/features/auth/domain/repositories/auth_repository.dart';
import 'package:spb/features/auth/domain/usecases/login_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginUseCase', () {
    late LoginUseCase useCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      useCase = LoginUseCase(mockRepository);
    });

    test('should return AuthTokens when login is successful', () async {
      // Arrange
      const testUserName = 'test_user';
      const testPassword = 'test_password';
      const testTokens = AuthTokens(accessToken: 'test_token');
      
      when(() => mockRepository.loginWithUserName(testUserName, testPassword))
          .thenAnswer((_) async => const Right(testTokens));

      // Act
      final result = await useCase(testUserName, testPassword);

      // Assert
      expect(result, equals(const Right(testTokens)));
      verify(() => mockRepository.loginWithUserName(testUserName, testPassword)).called(1);
    });

    test('should return ValidationFailure when username is empty', () async {
      // Act
      final result = await useCase('', 'password');

      // Assert
      expect(result, isA<Left<ValidationFailure, AuthTokens>>());
      verifyNever(() => mockRepository.loginWithUserName(any(), any()));
    });

    test('should return ValidationFailure when password is empty', () async {
      // Act
      final result = await useCase('username', '');

      // Assert
      expect(result, isA<Left<ValidationFailure, AuthTokens>>());
      verifyNever(() => mockRepository.loginWithUserName(any(), any()));
    });
  });
}
```

### Utility Testing

```dart
// test/unit/core/utils/jwt_decoder_util_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spb/core/utils/jwt_decoder_util.dart';

void main() {
  group('JwtDecoderUtil', () {
    const validJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
    const invalidJwtToken = 'invalid.token.here';

    group('decodeAndFilterToken', () {
      test('should return filtered data for valid token', () {
        // Act
        final result = JwtDecoderUtil.decodeAndFilterToken(validJwtToken);

        // Assert
        expect(result, isNotNull);
        expect(result!['sub'], equals('1234567890'));
        expect(result['name'], equals('John Doe'));
        expect(result['iat'], equals(1516239022));
        
        // Verify sensitive fields are filtered out
        expect(result.containsKey('access_token'), isFalse);
        expect(result.containsKey('refresh_token'), isFalse);
      });

      test('should return null for invalid token', () {
        // Act
        final result = JwtDecoderUtil.decodeAndFilterToken(invalidJwtToken);

        // Assert
        expect(result, isNull);
      });
    });

    group('extractUserInfo', () {
      test('should extract user information from valid token', () {
        // Act
        final result = JwtDecoderUtil.extractUserInfo(validJwtToken);

        // Assert
        expect(result, isNotNull);
        expect(result!['sub'], equals('1234567890'));
        expect(result['name'], equals('John Doe'));
      });

      test('should return null for invalid token', () {
        // Act
        final result = JwtDecoderUtil.extractUserInfo(invalidJwtToken);

        // Assert
        expect(result, isNull);
      });
    });

    group('isTokenValid', () {
      test('should return false for expired token', () {
        // Expired token (exp: 1516239022 = 2018-01-18)
        const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiZXhwIjoxNTE2MjM5MDIyfQ.4Adcj3UFYzPUVaVF43FmMab6RlaQD8A9V8wFzzht-KQ';
        
        // Act
        final result = JwtDecoderUtil.isTokenValid(expiredToken);

        // Assert
        expect(result, isFalse);
      });
    });
  });
}
```

## Widget Testing

### Basic Widget Test

```dart
// test/widget/widgets/login_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:spb/features/auth/presentation/widgets/login_form.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  group('LoginForm', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    });

    testWidgets('renders correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const Scaffold(body: LoginForm()),
          ),
        ),
      );

      // Assert
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('submits form when valid', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const Scaffold(body: LoginForm()),
          ),
        ),
      );

      // Act
      await tester.enterText(find.byType(TextFormField).first, 'test_user');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Assert
      verify(() => mockAuthBloc.add(const AuthLoginRequested(
        userName: 'test_user',
        password: 'password123',
      ))).called(1);
    });

    testWidgets('shows loading indicator when AuthLoading', (WidgetTester tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const Scaffold(body: LoginForm()),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('validates username format', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const Scaffold(body: LoginForm()),
          ),
        ),
      );

      // Act - enter invalid username
      await tester.enterText(find.byType(TextFormField).first, 'inv@lid');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Assert - form validation should prevent submission
      verifyNever(() => mockAuthBloc.add(any()));
      expect(find.text('Username can only contain letters, numbers, underscore, and hyphen'), findsOneWidget);
    });
  });
}
```

### Golden Tests

```dart
// test/widget/pages/login_page_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:spb/features/auth/presentation/pages/login_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  group('LoginPage Golden Tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    });

    testWidgets('renders correctly - light theme', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const LoginPage(),
          ),
        ),
      );

      // Assert
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_page_light.png'),
      );
    });

    testWidgets('renders correctly - dark theme', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const LoginPage(),
          ),
        ),
      );

      // Assert
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_page_dark.png'),
      );
    });

    testWidgets('renders error state correctly', (WidgetTester tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(const AuthError('Invalid credentials'));
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const LoginPage(),
          ),
        ),
      );

      // Assert
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_page_error.png'),
      );
    });
  });
}
```

### Navigation Testing

```dart
// test/widget/navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/core/router/app_router.dart';
import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('Navigation Tests', () {
    late MockAuthBloc mockAuthBloc;
    late GoRouter router;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
      when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());
      
      router = AppRouter.router;
    });

    testWidgets('unauthenticated user is redirected to login', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) {
            return BlocProvider<AuthBloc>.value(
              value: mockAuthBloc,
              child: child!,
            );
          },
        ),
      );
      
      // Navigate to protected route
      router.go('/home');
      await tester.pumpAndSettle();

      // Assert - should be redirected to login
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('authenticated user can access protected routes', (WidgetTester tester) async {
      // Arrange - authenticated user
      when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(
        user: User(
          id: '1',
          userName: 'test_user',
          email: 'test@example.com',
          name: 'Test User',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) {
            return BlocProvider<AuthBloc>.value(
              value: mockAuthBloc,
              child: child!,
            );
          },
        ),
      );
      
      // Navigate to protected route
      router.go('/home');
      await tester.pumpAndSettle();

      // Assert - should see home page
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
```

## Integration Testing

### Setup

```dart
// integration_test/helpers/test_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:spb/core/di/injection.dart';
import 'package:spb/core/router/app_router.dart';
import 'package:spb/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:spb/features/theme/presentation/bloc/theme_bloc.dart';

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => GetIt.instance<AuthBloc>(),
        ),
        BlocProvider(
          create: (context) => GetIt.instance<ThemeBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'SPB Secure App - Test',
        routerConfig: AppRouter.router,
      ),
    );
  }
}

Future<void> initializeTestApp() async {
  // Initialize dependencies
  await configureDependencies();
  
  // Override with test implementations if needed
  // GetIt.instance.registerSingleton<ApiClient>(MockApiClient());
}
```

### Authentication Flow Test

```dart
// integration_test/auth_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spb/main.dart' as app;
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Test', () {
    testWidgets('Login and logout flow', (WidgetTester tester) async {
      // Initialize test app
      await initializeTestApp();
      await tester.pumpWidget(const TestApp());
      await tester.pumpAndSettle();

      // Verify we're on the login page
      expect(find.text('Welcome Back'), findsOneWidget);
      
      // Enter credentials and login
      await tester.enterText(
        find.byType(TextFormField).first, 
        'test_user',
      );
      await tester.enterText(
        find.byType(TextFormField).last, 
        'password123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify we're logged in and on the home page
      expect(find.text('Dashboard'), findsOneWidget);
      
      // Navigate to profile
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      
      // Verify we're on the profile page
      expect(find.text('Profile'), findsOneWidget);
      
      // Scroll to find logout button
      await tester.dragUntilVisible(
        find.text('Logout'),
        find.byType(SingleChildScrollView),
        const Offset(0, 50),
      );
      
      // Tap logout
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      
      // Confirm logout
      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle();
      
      // Verify we're back on the login page
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
```

### Data Management Test

```dart
// integration_test/data_management_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spb/main.dart' as app;
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Data Management Test', () {
    testWidgets('Create, view, and delete data entry', (WidgetTester tester) async {
      // Initialize test app and login
      await initializeTestApp();
      await tester.pumpWidget(const TestApp());
      await tester.pumpAndSettle();
      
      // Login (reuse auth flow test steps)
      // ...
      
      // Navigate to data page
      await tester.tap(find.byIcon(Icons.data_usage));
      await tester.pumpAndSettle();
      
      // Verify we're on the data page
      expect(find.text('Data Management'), findsOneWidget);
      
      // Add new data entry
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Fill form
      await tester.enterText(
        find.byKey(const Key('name_field')), 
        'Test Entry',
      );
      await tester.enterText(
        find.byKey(const Key('email_field')), 
        'test@example.com',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Verify entry was added
      expect(find.text('Test Entry'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      
      // Delete entry
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();
      
      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      
      // Verify entry was deleted
      expect(find.text('Test Entry'), findsNothing);
    });
  });
}
```

## End-to-End Testing

### Full User Journey

```dart
// integration_test/user_journey_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spb/main.dart' as app;
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End User Journey', () {
    testWidgets('Complete user journey', (WidgetTester tester) async {
      // Initialize test app
      await initializeTestApp();
      await tester.pumpWidget(const TestApp());
      await tester.pumpAndSettle();

      // Login
      // ...
      
      // Navigate through main features
      // 1. Check dashboard
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Metrics'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      
      // 2. Navigate to data page
      await tester.tap(find.byIcon(Icons.data_usage));
      await tester.pumpAndSettle();
      expect(find.text('Data Management'), findsOneWidget);
      
      // 3. Test data filtering
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      
      // 4. Navigate to profile
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      
      // 5. Test theme switching
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      
      // 6. Logout
      // ...
    });
  });
}
```

## Performance Testing

### Memory Leak Testing

```dart
// test/performance/memory_leak_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spb/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Memory Leak Tests', () {
    testWidgets('No memory leaks during navigation', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Login
      // ...
      
      // Perform multiple navigation cycles
      for (int i = 0; i < 10; i++) {
        // Navigate to data page
        await tester.tap(find.byIcon(Icons.data_usage));
        await tester.pumpAndSettle();
        
        // Navigate to profile page
        await tester.tap(find.byIcon(Icons.person));
        await tester.pumpAndSettle();
        
        // Navigate to home page
        await tester.tap(find.byIcon(Icons.home));
        await tester.pumpAndSettle();
      }
      
      // Check for memory leaks
      // This is a placeholder - actual memory profiling would be done
      // using DevTools or platform-specific profiling tools
    });
  });
}
```

### Rendering Performance

```dart
// test/performance/rendering_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spb/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Rendering Performance Tests', () {
    testWidgets('Smooth scrolling performance', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Login
      // ...
      
      // Navigate to data page with many items
      await tester.tap(find.byIcon(Icons.data_usage));
      await tester.pumpAndSettle();
      
      // Measure scroll performance
      final Stopwatch stopwatch = Stopwatch()..start();
      
      // Scroll multiple times
      for (int i = 0; i < 10; i++) {
        await tester.drag(
          find.byType(ListView), 
          const Offset(0, -300),
        );
        await tester.pump(); // Don't wait for animations to complete
      }
      
      stopwatch.stop();
      
      // Check if scrolling was smooth (less than 16ms per frame on average)
      final double avgFrameTime = stopwatch.elapsedMilliseconds / 10;
      expect(avgFrameTime, lessThan(16.0));
    });
  });
}
```

## Mocking

### Network Mocking

```dart
// test/helpers/mock_dio_client.dart
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

class MockDioError extends Mock implements DioException {}

class FakeDioRequestOptions extends Fake implements RequestOptions {}

class MockDioClient {
  static Dio getMockDio({
    Map<String, dynamic>? mockResponseData,
    int statusCode = 200,
    DioException? mockError,
  }) {
    final dio = MockDio();
    
    if (mockError != null) {
      when(() => dio.get(any())).thenThrow(mockError);
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(mockError);
      when(() => dio.put(any(), data: any(named: 'data'))).thenThrow(mockError);
      when(() => dio.delete(any())).thenThrow(mockError);
    } else {
      final response = MockResponse();
      when(() => response.statusCode).thenReturn(statusCode);
      when(() => response.data).thenReturn(mockResponseData);
      
      when(() => dio.get(any())).thenAnswer((_) async => response);
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((_) async => response);
      when(() => dio.put(any(), data: any(named: 'data'))).thenAnswer((_) async => response);
      when(() => dio.delete(any())).thenAnswer((_) async => response);
    }
    
    return dio;
  }
}
```

### Database Mocking

```dart
// test/helpers/mock_database_helper.dart
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

import 'package:spb/core/storage/database_helper.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {
  static MockDatabaseHelper instance = MockDatabaseHelper();
}

class MockDatabase extends Mock implements Database {}

class MockDatabaseFactory extends Mock implements DatabaseFactory {}

void setupMockDatabase() {
  final mockDb = MockDatabase();
  
  // Setup common query responses
  when(() => mockDb.query(
    any(),
    columns: any(named: 'columns'),
    where: any(named: 'where'),
    whereArgs: any(named: 'whereArgs'),
    orderBy: any(named: 'orderBy'),
    limit: any(named: 'limit'),
    offset: any(named: 'offset'),
  )).thenAnswer((_) async => []);
  
  when(() => mockDb.insert(
    any(),
    any(),
    conflictAlgorithm: any(named: 'conflictAlgorithm'),
  )).thenAnswer((_) async => 1);
  
  when(() => mockDb.update(
    any(),
    any(),
    where: any(named: 'where'),
    whereArgs: any(named: 'whereArgs'),
  )).thenAnswer((_) async => 1);
  
  when(() => mockDb.delete(
    any(),
    where: any(named: 'where'),
    whereArgs: any(named: 'whereArgs'),
  )).thenAnswer((_) async => 1);
  
  // Setup database helper
  when(() => MockDatabaseHelper.instance.database).thenAnswer((_) async => mockDb);
}
```

### Secure Storage Mocking

```dart
// test/helpers/mock_secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spb/core/storage/secure_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockSecureStorage extends Mock implements SecureStorage {}

MockSecureStorage getMockSecureStorage() {
  final mockStorage = MockSecureStorage();
  
  // Setup common operations
  when(() => mockStorage.read(any())).thenAnswer((_) async => null);
  when(() => mockStorage.write(any(), any())).thenAnswer((_) async {});
  when(() => mockStorage.delete(any())).thenAnswer((_) async {});
  when(() => mockStorage.deleteAll()).thenAnswer((_) async {});
  
  return mockStorage;
}
```

## Test Coverage

### Running Coverage

```bash
# Generate coverage report
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open coverage report
open coverage/html/index.html
```

### Coverage Thresholds

- **Overall Coverage Target**: 80%
- **Core Layer**: 90%
- **Domain Layer**: 95%
- **Data Layer**: 85%
- **Presentation Layer**: 70%

### Excluding Files from Coverage

Create a `lcov.info` file to exclude generated files:

```
# Exclude generated files
--exclude "**/*.g.dart"
--exclude "**/*.freezed.dart"
--exclude "**/generated_plugin_registrant.dart"
```

## Continuous Integration

### GitHub Actions

```yaml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs
        
      - name: Analyze code
        run: flutter analyze
        
      - name: Run tests with coverage
        run: flutter test --coverage
        
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
```

### GitLab CI

```yaml
stages:
  - test

variables:
  FLUTTER_VERSION: "3.27.0"

before_script:
  - apt-get update -qq && apt-get install -y -qq git curl unzip lcov
  - git clone https://github.com/flutter/flutter.git -b stable --depth 1
  - export PATH="$PATH:`pwd`/flutter/bin"
  - flutter doctor -v
  - flutter pub get
  - flutter packages pub run build_runner build --delete-conflicting-outputs

unit_tests:
  stage: test
  script:
    - flutter test --coverage
    - lcov --remove coverage/lcov.info "**/*.g.dart" "**/*.freezed.dart" -o coverage/lcov_filtered.info
    - genhtml coverage/lcov_filtered.info -o coverage/html
  coverage: '/lines......: \d+\.\d+\%/'
  artifacts:
    paths:
      - coverage/html/
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

## Test Data

### Mock Data

```dart
// test/helpers/mock_data.dart
class MockData {
  // User data
  static const mockUser = {
    'id': 'usr_123456789',
    'userName': 'test_user',
    'email': 'test@example.com',
    'name': 'Test User',
    'avatar': null,
    'createdAt': '2025-01-01T00:00:00.000Z',
    'updatedAt': '2025-01-27T10:30:45.123Z',
  };

  // Auth tokens
  static const mockTokens = {
    'accessToken': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    'tokenType': 'Bearer',
    'expiresIn': 86400,
  };

  // Data entries
  static final mockDataEntries = [
    {
      'id': 'entry_123',
      'name': 'John Doe',
      'email': 'john@example.com',
      'status': 'active',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'updatedAt': '2025-01-27T10:30:45.123Z',
    },
    {
      'id': 'entry_456',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'status': 'inactive',
      'createdAt': '2025-01-02T00:00:00.000Z',
      'updatedAt': '2025-01-26T15:20:30.456Z',
    },
  ];

  // Dashboard metrics
  static const mockDashboardMetrics = {
    'totalUsers': 1234,
    'activeSessions': 89,
    'dataPoints': 5678,
    'securityScore': 98,
  };

  // Error responses
  static const mockValidationError = {
    'statusCode': 422,
    'errorCode': 'VALIDATION_ERROR',
    'message': 'The request contains invalid data',
    'details': 'Validation failed for 2 field(s).',
    'suggestedActions': [
      'Review the field errors below and correct the invalid data',
    ],
    'timestamp': '2025-01-27T10:30:45.123Z',
    'requestId': 'req_7f8a9b2c-3d4e-5f6g-7h8i-9j0k1l2m3n4o',
    'fieldErrors': {
      'email': ['Email address is required'],
      'password': ['Password must be at least 8 characters long'],
    },
    'retryable': false,
  };
}
```

### Test Fixtures

```dart
// test/helpers/fixture_reader.dart
import 'dart:io';
import 'dart:convert';

String fixture(String name) {
  return File('test/fixtures/$name').readAsStringSync();
}

Map<String, dynamic> jsonFixture(String name) {
  return json.decode(fixture('$name.json')) as Map<String, dynamic>;
}

List<dynamic> jsonListFixture(String name) {
  return json.decode(fixture('$name.json')) as List<dynamic>;
}
```

Example fixture file:

```json
// test/fixtures/user.json
{
  "id": "usr_123456789",
  "userName": "test_user",
  "email": "test@example.com",
  "name": "Test User",
  "avatar": null,
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-27T10:30:45.123Z"
}
```

## Test Automation

### Pre-commit Hooks

Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
echo "Running pre-commit hooks..."

# Run Flutter format
echo "Running flutter format..."
flutter format --set-exit-if-changed lib test

# Run Flutter analyze
echo "Running flutter analyze..."
flutter analyze

# Run unit tests
echo "Running flutter test..."
flutter test --no-pub --coverage

# Check coverage
echo "Checking test coverage..."
COVERAGE=$(lcov --summary coverage/lcov.info | grep "lines" | awk '{print $4}' | cut -d'%' -f1)
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
  echo "Test coverage is below 80% (current: $COVERAGE%)"
  exit 1
fi

echo "All pre-commit hooks passed!"
```

### Test Automation Script

Create `scripts/run_tests.sh`:

```bash
#!/bin/bash
set -e

# Clean and get dependencies
flutter clean
flutter pub get

# Generate code
flutter packages pub run build_runner build --delete-conflicting-outputs

# Run static analysis
flutter analyze

# Run unit tests with coverage
flutter test --coverage

# Filter out generated files
lcov --remove coverage/lcov.info "**/*.g.dart" "**/*.freezed.dart" -o coverage/lcov_filtered.info

# Generate HTML report
genhtml coverage/lcov_filtered.info -o coverage/html

# Run integration tests
flutter test integration_test

echo "All tests completed successfully!"
```

## Best Practices

### Test Organization

1. **Group Related Tests**: Use `group()` to organize related tests
2. **Descriptive Test Names**: Use clear, descriptive test names
3. **Setup and Teardown**: Use `setUp()` and `tearDown()` for common initialization
4. **Test Independence**: Each test should be independent and not rely on other tests

### Test Coverage

1. **Happy Path**: Test the expected successful flow
2. **Edge Cases**: Test boundary conditions and edge cases
3. **Error Handling**: Test error scenarios and recovery
4. **Input Validation**: Test all input validation rules
5. **State Transitions**: Test all state transitions in BLoCs

### Test Maintenance

1. **Avoid Brittle Tests**: Don't rely on implementation details
2. **Use Test Helpers**: Create reusable test utilities
3. **Mock External Dependencies**: Isolate tests from external systems
4. **Keep Tests Fast**: Optimize for quick feedback
5. **Regular Maintenance**: Update tests when requirements change

## Troubleshooting

### Common Test Issues

#### 1. Flaky Tests
- **Symptoms**: Tests pass sometimes and fail other times
- **Causes**: Timing issues, external dependencies, state leakage
- **Solutions**:
  - Add proper `pumpAndSettle()` calls
  - Mock external dependencies
  - Ensure proper tearDown cleanup
  - Add retry logic for integration tests

#### 2. Widget Test Failures
- **Symptoms**: Widget tests fail with "No MaterialLocalizations found"
- **Solution**: Wrap widgets with `MaterialApp` or `MaterialApp.router`

#### 3. Golden Test Failures
- **Symptoms**: Golden tests fail with pixel differences
- **Solutions**:
  - Update golden files: `flutter test --update-goldens`
  - Use platform-independent rendering
  - Set consistent test environment

#### 4. BLoC Test Issues
- **Symptoms**: BLoC tests fail with unexpected states
- **Solutions**:
  - Check event handling order
  - Verify mock setup
  - Use `blocTest` for proper testing

#### 5. Integration Test Timeouts
- **Symptoms**: Tests timeout waiting for conditions
- **Solutions**:
  - Increase timeout duration
  - Add proper waiting conditions
  - Check for UI blocking operations

This comprehensive testing documentation provides a solid foundation for maintaining high-quality code and ensuring the reliability of the SPB Secure application.