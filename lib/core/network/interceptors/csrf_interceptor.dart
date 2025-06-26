import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// Adds CSRF protection to API requests
class CsrfInterceptor extends Interceptor {
  // In a real app, this would be fetched from the server or generated
  String _getCsrfToken() {
    // This is a simplified example - in a real app, you would:
    // 1. Fetch a CSRF token from the server on app initialization
    // 2. Store it securely
    // 3. Return the stored token here
    return 'csrf-token-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Only add CSRF token for state-changing operations
      if (['POST', 'PUT', 'DELETE', 'PATCH'].contains(options.method.toUpperCase())) {
        final csrfToken = _getCsrfToken();
        options.headers['X-CSRF-TOKEN'] = csrfToken;
        
        // For form submissions, you might also want to include it in the body
        if (options.data is Map) {
          final Map<String, dynamic> data = Map.from(options.data);
          data['_csrf'] = csrfToken;
          options.data = data;
        }
      }
    } catch (e) {
      AppLogger.error('CSRF interceptor error: $e');
    }

    handler.next(options);
  }
}