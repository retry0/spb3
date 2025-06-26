import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart' as core_theme;
import 'core/router/app_router.dart';
import 'core/utils/bloc_observer.dart';
import 'core/utils/logger.dart';
import 'core/storage/database_helper.dart';
import 'core/config/environment_config.dart';
import 'core/config/environment_validator.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/utils/auth_sync_service.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/widgets/session_timeout_dialog.dart';
import 'features/theme/presentation/bloc/theme_bloc.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  AppLogger.init();

  try {
    // Initialize environment configuration
    await EnvironmentConfig.initialize();
    AppLogger.info('Environment: ${EnvironmentConfig.environmentName}');
    AppLogger.info('Base URL: ${EnvironmentConfig.baseUrl}');

    // Validate environment configuration
    final validation = EnvironmentValidator.validateEnvironment();
    if (!validation.isValid) {
      AppLogger.error('Environment validation failed:');
      AppLogger.error(validation.getReport());

      // In development, show validation errors but continue
      if (EnvironmentConfig.isDevelopment) {
        AppLogger.warning(
          'Continuing with invalid configuration in development mode',
        );
      } else {
        // In production/staging, fail fast
        throw Exception('Invalid environment configuration');
      }
    }

    if (validation.warnings.isNotEmpty) {
      AppLogger.warning('Environment warnings:');
      for (final warning in validation.warnings) {
        AppLogger.warning('  • $warning');
      }
    }
  } catch (e) {
    AppLogger.error('Failed to initialize environment configuration: $e');

    // Show user-friendly error in debug mode
    if (EnvironmentConfig.isDevelopment) {
      runApp(ErrorApp(error: e.toString()));
      return;
    } else {
      rethrow;
    }
  }

  // Initialize SQLite database
  await DatabaseHelper.instance.database;

  // Configure dependency injection
  await configureDependencies();

  // Set up BLoC observer
  Bloc.observer = AppBlocObserver();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create:
              (context) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider(
          create:
              (context) => getIt<ThemeBloc>()..add(const ThemeInitialized()),
        ),
        // Provide global services
        RepositoryProvider.value(value: getIt<ConnectivityService>()),
        RepositoryProvider.value(value: getIt<SyncService>()),
        RepositoryProvider.value(value: getIt<AuthSyncService>()),
        RepositoryProvider.value(value: getIt<SessionManager>()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return SessionTimeoutManager(
            child: MaterialApp.router(
              title: 'SPB Secure App',
              debugShowCheckedModeBanner: false,
              theme: core_theme.AppTheme.lightTheme,
              darkTheme: core_theme.AppTheme.darkTheme,
              themeMode: themeState.themeMode,
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(
                        context,
                      ).textScaler.scale(1.0).clamp(0.8, 1.4),
                    ),
                  ),
                  child: child!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Error app shown when environment configuration fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Error',
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your environment configuration and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (EnvironmentConfig.isDevelopment) ...[
                  const Text(
                    'Development Mode Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Ensure your backend server is running\n'
                    '• Check environment variables are set correctly',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
