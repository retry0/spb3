import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../di/injection.dart';
import '../../storage/secure_storage.dart';
import '../../constants/storage_keys.dart';
import '../../utils/logger.dart';
import '../../utils/session_manager.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage _secureStorage = getIt<SecureStorage>();
  //final SessionManager _sessionManager = getIt<SessionManager>();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.read(StorageKeys.accessToken);

      if (token != null && !JwtDecoder.isExpired(token)) {
        options.headers['Authorization'] = 'Bearer $token';

        // Update last activity timestamp for session management
        // await _sessionManager.updateLastActivity();
      } else if (token != null) {
        // Token is expired, clear it
        //await _secureStorage.delete(StorageKeys.accessToken);
        AppLogger.warning('Expired JWT token cleared');
      }
    } catch (e) {
      AppLogger.error('Auth interceptor error: $e');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        // Clear expired or invalid token
        await _secureStorage.delete(StorageKeys.accessToken);
        AppLogger.warning('Invalid token cleared due to 401 response');

        // Clear session data
        //await _sessionManager.clearSession();
      } catch (e) {
        AppLogger.error('Failed to clear invalid token: $e');
      }
    }

    handler.next(err);
  }
}
