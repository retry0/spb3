import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart' as core_theme;
import 'core/router/app_router.dart';
import 'core/utils/bloc_observer.dart';
import 'core/utils/logger.dart';
import 'core/storage/database_helper.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/widgets/session_timeout_dialog.dart';
import 'features/theme/presentation/bloc/theme_bloc.dart';
import 'features/spb/data/services/kendala_form_migration_service.dart';
import 'features/spb/presentation/pages/migration_status_page.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize logging
  AppLogger.init();

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

  // Check if migration is needed
  final needsMigration = await _checkIfMigrationNeeded();

  runApp(MyApp(needsMigration: needsMigration));
}

Future<bool> _checkIfMigrationNeeded() async {
  try {
    // Check if kendala_forms table exists
    final db = await DatabaseHelper.instance.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='kendala_forms'"
    );
    
    if (tables.isEmpty) {
      // Table doesn't exist, check if there's data in SharedPreferences
      final prefs = await getIt<SharedPreferences>();
      final allKeys = prefs.getKeys();
      final formDataKeys = allKeys.where((key) => key.startsWith('kendala_form_data_')).toList();
      
      // If there's data in SharedPreferences but no table, migration is needed
      return formDataKeys.isNotEmpty;
    }
    
    // Table exists, no migration needed
    return false;
  } catch (e) {
    AppLogger.error('Error checking migration status: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  final bool needsMigration;
  
  const MyApp({super.key, this.needsMigration = false});

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
                // Show migration page if needed
                if (needsMigration) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        MediaQuery.of(
                          context,
                        ).textScaler.scale(1.0).clamp(0.8, 1.4),
                      ),
                    ),
                    child: const MigrationStatusPage(),
                  );
                }
                
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}