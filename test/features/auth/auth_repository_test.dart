import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:spb/core/error/failures.dart';
import 'package:spb/core/error/exceptions.dart';
import 'package:spb/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:spb/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:spb/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spb/features/auth/data/models/auth_tokens_model.dart';
import 'package:spb/features/auth/domain/entities/auth_tokens.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}
class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockLocalDataSource;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalDataSource = MockAuthLocalDataSource();
    mockConnectivity = MockConnectivity();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      connectivity: mockConnectivity,
    );
  });

  group('loginWithUserName', () {
    const testUserName = 'test_user';
    const testPassword = 'test_password';
    const testTokens = AuthTokensModel(token: 'test_token');

    test('should return AuthTokens when online login is successful', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockRemoteDataSource.loginWithUserName(any()))
          .thenAnswer((_) async => testTokens);
      when(() => mockLocalDataSource.saveToken(any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.saveOfflineCredentials(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.updateLastOnlineAuth(any()))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.loginWithUserName(testUserName, testPassword);

      // Assert
      expect(result, equals(const Right(testTokens)));
      verify(() => mockRemoteDataSource.loginWithUserName({
        'userName': testUserName,
        'password': testPassword,
      })).called(1);
      verify(() => mockLocalDataSource.saveToken(testTokens.token)).called(1);
      verify(() => mockLocalDataSource.saveOfflineCredentials(testUserName, testPassword)).called(1);
      verify(() => mockLocalDataSource.updateLastOnlineAuth(testUserName)).called(1);
    });

    test('should try offline authentication when network exception occurs', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockRemoteDataSource.loginWithUserName(any()))
          .thenThrow(const NetworkException('Network error'));
      when(() => mockLocalDataSource.verifyOfflineCredentials(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockLocalDataSource.getUser(any()))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.loginWithUserName(testUserName, testPassword);

      // Assert
      expect(result.isLeft(), true);
      verify(() => mockLocalDataSource.verifyOfflineCredentials(testUserName, testPassword)).called(1);
    });

    test('should return AuthTokens when offline authentication is successful', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [],
      );
      when(() => mockLocalDataSource.verifyOfflineCredentials(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockLocalDataSource.getUser(any()))
          .thenAnswer((_) async => UserModel(
            Id: 'test_id',
            UserName: testUserName,
            Nama: 'Test User',
          ));
      when(() => mockLocalDataSource.saveToken(any()))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.loginWithUserName(testUserName, testPassword);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.verifyOfflineCredentials(testUserName, testPassword)).called(1);
      verify(() => mockLocalDataSource.getUser(testUserName)).called(1);
      verify(() => mockLocalDataSource.saveToken(any())).called(1);
    });

    test('should return AuthFailure when offline authentication fails', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [],
      );
      when(() => mockLocalDataSource.verifyOfflineCredentials(any(), any()))
          .thenAnswer((_) async => false);

      // Act
      final result = await repository.loginWithUserName(testUserName, testPassword);

      // Assert
      expect(result, equals(Left(AuthFailure('Invalid credentials for offline authentication'))));
      verify(() => mockLocalDataSource.verifyOfflineCredentials(testUserName, testPassword)).called(1);
    });
  });

  group('logout', () {
    test('should clear local data when logout is successful', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockLocalDataSource.clearToken())
          .thenAnswer((_) async {});

      // Act
      final result = await repository.logout();

      // Assert
      expect(result, equals(const Right(null)));
      verify(() => mockLocalDataSource.clearToken()).called(1);
    });

    test('should clear local data even when network is unavailable', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [],
      );
      when(() => mockLocalDataSource.clearToken())
          .thenAnswer((_) async {});

      // Act
      final result = await repository.logout();

      // Assert
      expect(result, equals(const Right(null)));
      verify(() => mockLocalDataSource.clearToken()).called(1);
    });

    test('should clear local data even when an error occurs', () async {
      // Arrange
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockLocalDataSource.clearToken())
          .thenThrow(Exception('Test error'));

      // Act
      final result = await repository.logout();

      // Assert
      expect(result, equals(const Right(null)));
    });
  });

  group('isLoggedIn', () {
    test('should return true when token is valid', () async {
      // Arrange
      when(() => mockLocalDataSource.getAccessToken())
          .thenAnswer((_) async => 'valid_token');

      // Act
      final result = await repository.isLoggedIn();

      // Assert
      expect(result, true);
      verify(() => mockLocalDataSource.getAccessToken()).called(1);
    });

    test('should return true when offline token is valid', () async {
      // Arrange
      final offlineToken = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      when(() => mockLocalDataSource.getAccessToken())
          .thenAnswer((_) async => offlineToken);

      // Act
      final result = await repository.isLoggedIn();

      // Assert
      expect(result, true);
      verify(() => mockLocalDataSource.getAccessToken()).called(1);
    });

    test('should return false when no token exists', () async {
      // Arrange
      when(() => mockLocalDataSource.getAccessToken())
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.isLoggedIn();

      // Assert
      expect(result, false);
      verify(() => mockLocalDataSource.getAccessToken()).called(1);
    });
  });
}