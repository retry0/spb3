import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import '../storage/local_storage.dart';
import '../storage/database_helper.dart';
//import '../storage/data_repository.dart';
import '../storage/user_profile_repository.dart';
import '../utils/jwt_token_manager.dart';
import '../utils/session_manager.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/refresh_token_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/theme/presentation/bloc/theme_bloc.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/change_password_usecase.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/spb/data/datasources/spb_remote_datasource.dart';
import '../../features/spb/data/datasources/spb_local_datasource.dart';
import '../../features/spb/data/repositories/spb_repository_impl.dart';
import '../../features/spb/data/repositories/spb_qr_repository_impl.dart';
import '../../features/spb/domain/repositories/spb_repository.dart';
import '../../features/spb/domain/repositories/spb_qr_repository.dart';
import '../../features/spb/domain/usecases/get_spb_for_driver_usecase.dart';
import '../../features/spb/domain/usecases/sync_spb_data_usecase.dart';
import '../../features/spb/domain/usecases/generate_spb_qr_code_usecase.dart';
import '../../features/spb/presentation/bloc/spb_bloc.dart';
import '../../features/spb/data/services/kendala_form_sync_service.dart';
import '../../features/spb/data/services/cek_spb_form_sync_service.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  // Database
  getIt.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);

  // Core services
  getIt.registerLazySingleton<SecureStorage>(
    () => SecureStorageImpl(getIt<FlutterSecureStorage>()),
  );

  getIt.registerLazySingleton<LocalStorage>(
    () => LocalStorageImpl(getIt<SharedPreferences>(), getIt<DatabaseHelper>()),
  );

  // getIt.registerLazySingleton<DataRepository>(
  //   () => DataRepository(getIt<DatabaseHelper>()),
  // );

  // JWT Token Manager
  getIt.registerLazySingleton<JwtTokenManager>(
    () => JwtTokenManager(getIt<FlutterSecureStorage>()),
  );

  getIt.registerLazySingleton<Dio>(() => DioClient.createDio());

  // Connectivity
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(getIt<Connectivity>()),
  );

  // User Profile Repository
  getIt.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepository(
      dbHelper: getIt<DatabaseHelper>(),
      tokenManager: getIt<JwtTokenManager>(),
      dio: getIt<Dio>(),
      connectivity: getIt<Connectivity>(),
    ),
  );

  // Sync Service
  getIt.registerLazySingleton<SyncService>(
    () => SyncService(
      userProfileRepository: getIt<UserProfileRepository>(),
      connectivityService: getIt<ConnectivityService>(),
    ),
  );

  // Kendala Form Sync Service
  getIt.registerLazySingleton<CekFormSyncService>(
    () => CekFormSyncService(
      dio: getIt<Dio>(),
      maxRetries: 3,
      initialBackoff: const Duration(seconds: 5),
    ),
  );

  // Kendala Form Sync Service
  getIt.registerLazySingleton<KendalaFormSyncService>(
    () => KendalaFormSyncService(
      dio: getIt<Dio>(),
      maxRetries: 3,
      initialBackoff: const Duration(seconds: 5),
    ),
  );

  // Utilities
  getIt.registerLazySingleton<Uuid>(() => const Uuid());

  // Data sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<Dio>()),
  );

  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      getIt<SecureStorage>(),
      getIt<DatabaseHelper>(),
    ),
  );

  getIt.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(getIt<Dio>()),
  );

  // SPB data sources
  getIt.registerLazySingleton<SpbRemoteDataSource>(
    () => SpbRemoteDataSourceImpl(dio: getIt<Dio>()),
  );

  getIt.registerLazySingleton<SpbLocalDataSource>(
    () => SpbLocalDataSourceImpl(dbHelper: getIt<DatabaseHelper>()),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      localDataSource: getIt<AuthLocalDataSource>(),
      connectivity: getIt<Connectivity>(),
    ),
  );

  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      authRepository: getIt<AuthRepository>(),
      remoteDataSource: getIt<ProfileRemoteDataSource>(),
      userProfileRepository: getIt<UserProfileRepository>(),
    ),
  );

  // SPB repository
  getIt.registerLazySingleton<SpbRepository>(
    () => SpbRepositoryImpl(
      remoteDataSource: getIt<SpbRemoteDataSource>(),
      localDataSource: getIt<SpbLocalDataSource>(),
      connectivity: getIt<Connectivity>(),
    ),
  );

  // SPB QR repository
  getIt.registerLazySingleton<SpbQrRepository>(
    () => SpbQrRepositoryImpl(
      connectivity: getIt<Connectivity>(),
      prefs: getIt<SharedPreferences>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(
    () => RefreshTokenUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => ChangePasswordUseCase(getIt<ProfileRepository>()),
  );

  // SPB use cases
  getIt.registerLazySingleton(
    () => GetSpbForDriverUseCase(getIt<SpbRepository>()),
  );
  getIt.registerLazySingleton(() => SyncSpbDataUseCase(getIt<SpbRepository>()));
  getIt.registerLazySingleton(() => GenerateSpbQrCodeUseCase());

  // Session Manager
  getIt.registerLazySingleton<SessionManager>(
    () => SessionManager(
      getIt<SharedPreferences>(),
      getIt<FlutterSecureStorage>(),
      getIt<JwtTokenManager>(),
      sessionTimeoutMinutes: 30,
    ),
  );
  // BLoCs
  getIt.registerFactory(
    () => AuthBloc(
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
      refreshTokenUseCase: getIt<RefreshTokenUseCase>(),
      sessionManager: getIt<SessionManager>(),
    ),
  );

  getIt.registerFactory(() => ThemeBloc(getIt<LocalStorage>()));

  getIt.registerFactory(
    () => ProfileBloc(
      profileRepository: getIt<ProfileRepository>(),
      changePasswordUseCase: getIt<ChangePasswordUseCase>(),
      userProfileRepository: getIt<UserProfileRepository>(),
      syncService: getIt<SyncService>(),
    ),
  );

  // SPB BLoC
  getIt.registerFactory(
    () => SpbBloc(
      getSpbForDriverUseCase: getIt<GetSpbForDriverUseCase>(),
      syncSpbDataUseCase: getIt<SyncSpbDataUseCase>(),
      connectivity: getIt<Connectivity>(),
    ),
  );
}
