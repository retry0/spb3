import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DioClient {
  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']!,
        //connectTimeout: EnvironmentConfig.timeout,
        //receiveTimeout: EnvironmentConfig.timeout,
        //sendTimeout: EnvironmentConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Environment': dotenv.env['FLUTTER_ENV'],
        },
      ),
    );

    // Add interceptors based on environment
    dio.interceptors.addAll([
      AuthInterceptor(),
      CsrfInterceptor(), // Add CSRF protection
      ErrorInterceptor(),
    ]);

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
        // baseUrl: baseUrl ?? dotenv.env['API_BASE_URL'],
        // connectTimeout: timeout ?? EnvironmentConfig.timeout,
        // receiveTimeout: timeout ?? EnvironmentConfig.timeout,
        // sendTimeout: timeout ?? EnvironmentConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Environment': dotenv.env['FLUTTER_ENV'],
          if (headers != null) ...headers,
        },
      ),
    );

    // Add basic interceptors
    dio.interceptors.addAll([
      ErrorInterceptor(),
      CsrfInterceptor(), // Add CSRF protection
      // if (EnvironmentConfig.isLoggingEnabled) LoggingInterceptor(),
    ]);

    return dio;
  }
}
