import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/environment_config.dart';
import '../utils/logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';

class DioClient {
  static Dio createDio() {
    // Ensure environment is initialized
    if (!EnvironmentConfig.isDevelopment &&
        !EnvironmentConfig.isStaging &&
        !EnvironmentConfig.isProduction) {
      throw Exception('Environment configuration not initialized');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: EnvironmentConfig.baseUrl,
        connectTimeout: EnvironmentConfig.timeout,
        receiveTimeout: EnvironmentConfig.timeout,
        sendTimeout: EnvironmentConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Environment': EnvironmentConfig.environmentName,
        },
        // Enable/disable validation based on environment
        validateStatus: (status) {
          if (EnvironmentConfig.isProduction) {
            // Strict validation in production
            return status != null && status >= 200 && status < 300;
          } else {
            // More lenient in development/staging for debugging
            return status != null && status < 500;
          }
        },
      ),
    );

    // Add interceptors based on environment
    dio.interceptors.addAll([
      AuthInterceptor(),
      CsrfInterceptor(), // Add CSRF protection
      ErrorInterceptor(),
      // Only add logging in development or when explicitly enabled
      if (EnvironmentConfig.isLoggingEnabled || kDebugMode)
        LoggingInterceptor(),
    ]);

    // Add additional security headers for production
    if (EnvironmentConfig.isProduction) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers.addAll({
              'X-Requested-With': 'XMLHttpRequest',
              'Cache-Control': 'no-cache',
            });
            handler.next(options);
          },
        ),
      );
    }

    return dio;
  }

  /// Create a Dio instance with custom configuration
  static Dio createCustomDio({
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? headers,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? EnvironmentConfig.baseUrl,
        connectTimeout: timeout ?? EnvironmentConfig.timeout,
        receiveTimeout: timeout ?? EnvironmentConfig.timeout,
        sendTimeout: timeout ?? EnvironmentConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Environment': EnvironmentConfig.environmentName,
          if (headers != null) ...headers,
        },
      ),
    );

    // Add basic interceptors
    dio.interceptors.addAll([
      ErrorInterceptor(),
      CsrfInterceptor(), // Add CSRF protection
      if (EnvironmentConfig.isLoggingEnabled) LoggingInterceptor(),
    ]);

    return dio;
  }
}