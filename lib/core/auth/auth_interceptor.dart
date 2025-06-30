import 'package:dio/dio.dart';
import '../di/injection.dart';
import '../utils/logger.dart';
import 'token_manager.dart';

/// Intercepts HTTP requests to add authentication tokens and handle token refresh
class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;

  // Track requests that are waiting for token refresh
  final List<RequestOptions> _pendingRequests = [];
  bool _isRefreshing = false;

  AuthInterceptor(this._tokenManager);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip authentication for login and public endpoints
    if (_isAuthExempt(options.path)) {
      return handler.next(options);
    }

    try {
      // Get access token
      final accessToken = await _tokenManager.getAccessToken();

      if (accessToken != null) {
        // Add token to request header
        options.headers['Authorization'] = 'Bearer $accessToken';
        return handler.next(options);
      } else {
        // No valid token available
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No valid authentication token',
            type: DioExceptionType.unknown,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Auth interceptor error: $e');
      return handler.reject(
        DioException(
          requestOptions: options,
          error: e.toString(),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if error is due to token expiration (401 Unauthorized)
    if (err.response?.statusCode == 401) {
      final options = err.requestOptions;

      // If we're already refreshing, queue this request
      if (_isRefreshing) {
        _pendingRequests.add(options);
        return;
      }

      _isRefreshing = true;

      try {
        // Try to refresh the token
        final newToken = await _tokenManager.refreshToken();

        if (newToken != null) {
          // Retry the original request with the new token
          options.headers['Authorization'] = 'Bearer $newToken';

          // Execute the original request with new token
          final response = await getIt<Dio>().fetch(options);

          // Process any pending requests with the new token
          for (final pendingRequest in _pendingRequests) {
            pendingRequest.headers['Authorization'] = 'Bearer $newToken';
            getIt<Dio>().fetch(pendingRequest);
          }

          _pendingRequests.clear();

          // Return the response from the retried request
          return handler.resolve(response);
        } else {
          // Token refresh failed, reject all pending requests
          _rejectPendingRequests('Token refresh failed');

          // Reject the original request
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'Authentication failed after token refresh attempt',
              type: DioExceptionType.unknown,
            ),
          );
        }
      } catch (e) {
        // Token refresh failed with an exception
        _rejectPendingRequests('Token refresh error: $e');

        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'Token refresh error: $e',
            type: DioExceptionType.unknown,
          ),
        );
      } finally {
        _isRefreshing = false;
      }
    }

    // For other errors, just pass through
    return handler.next(err);
  }

  /// Reject all pending requests with an error
  void _rejectPendingRequests(String error) {
    for (final request in _pendingRequests) {
      // Since we don't have the handler for each pending request, you may want to handle this differently.
      // For now, just log or handle as needed.
      AppLogger.error('Pending request to ${request.path} rejected: $error');
      // Optionally, you could notify listeners or use a callback to reject these requests properly.
    }
    _pendingRequests.clear();
  }

  /// Check if a path is exempt from authentication
  bool _isAuthExempt(String path) {
    final exemptPaths = [
      '/Account/LoginUser',
      '/auth/login',
      '/auth/register',
      '/auth/forgot-password',
      '/health',
      '/public',
    ];

    return exemptPaths.any((exemptPath) => path.contains(exemptPath));
  }
}
