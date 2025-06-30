import 'package:equatable/equatable.dart';

class AppException implements Exception {
  final String message;
  final String? endpoint;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? details;
  final int? retryAfterSeconds;

  const AppException(
    this.message, {
    this.endpoint,
    this.statusCode,
    this.errorCode,
    this.details,
    this.retryAfterSeconds,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class ServerException extends AppException {
  const ServerException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class PermissionException extends AppException {
  const PermissionException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class TimeoutException extends AppException {
  const TimeoutException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class RateLimitException extends AppException {
  const RateLimitException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class OfflineException extends AppException {
  const OfflineException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class TokenRefreshException extends AppException {
  const TokenRefreshException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class SessionExpiredException extends AppException {
  const SessionExpiredException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class MultiDeviceException extends AppException {
  const MultiDeviceException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}

class TokenRevokedException extends AppException {
  const TokenRevokedException(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    super.retryAfterSeconds,
  });
}