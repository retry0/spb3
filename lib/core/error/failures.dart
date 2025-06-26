import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? endpoint;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? details;

  const Failure(
    this.message, {
    this.endpoint,
    this.statusCode,
    this.errorCode,
    this.details,
  });

  @override
  List<Object?> get props => [
    message,
    endpoint,
    statusCode,
    errorCode,
    details,
  ];

  /// Get a user-friendly message based on the failure type and endpoint
  String getUserFriendlyMessage() {
    // Default implementation returns the original message
    // Subclasses can override this to provide more specific messages
    return message;
  }

  /// Get suggested actions based on the failure type and endpoint
  List<String> getSuggestedActions() {
    // Default implementation returns an empty list
    // Subclasses can override this to provide specific suggestions
    return [];
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (endpoint != null) {
      if (endpoint!.contains('/auth') || endpoint!.contains('/login')) {
        return 'Unable to connect to authentication service. Please check your internet connection and try again.';
      } else if (endpoint!.contains('/data') ||
          endpoint!.contains('/api/data')) {
        return 'Unable to fetch data from server. Please check your internet connection and try again.';
      } else if (endpoint!.contains('/upload') ||
          endpoint!.contains('/files')) {
        return 'Network error while uploading files. Please check your connection and try again.';
      }
    }

    return 'Network connection error. Please check your internet connection and try again.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = [
      'Check your internet connection',
      'Try again in a few moments',
    ];

    if (endpoint != null) {
      if (endpoint!.contains('/auth') || endpoint!.contains('/login')) {
        actions.add('Try logging in again');
      } else if (endpoint!.contains('/upload')) {
        actions.add('Try uploading a smaller file');
        actions.add('Check if you have a stable connection');
      }
    }

    return actions;
  }
}

class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (statusCode != null) {
      if (statusCode! >= 500 && statusCode! < 600) {
        return 'The server is currently experiencing issues. Please try again later.';
      }
    }

    if (endpoint != null) {
      if (endpoint!.contains('/auth') || endpoint!.contains('/login')) {
        return 'The authentication service is currently unavailable. Please try again later.';
      } else if (endpoint!.contains('/data') ||
          endpoint!.contains('/api/data')) {
        return 'Unable to process data request. Our team has been notified.';
      }
    }

    return 'An unexpected server error occurred. Our team has been notified.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = [
      'Try again later',
      'Contact support if the problem persists',
    ];

    if (statusCode != null) {
      if (statusCode == 503) {
        actions.add(
          'The service may be under maintenance, please check back soon',
        );
      }
    }

    return actions;
  }
}

class AuthFailure extends Failure {
  const AuthFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (message.contains('expired')) {
      return 'Your session has expired. Please log in again.';
    } else if (message.contains('invalid credentials') ||
        message.contains('Invalid credentials')) {
      return 'Invalid username or password. Please check your credentials and try again.';
    } else if (message.contains('permission') ||
        message.contains('access denied')) {
      return 'You do not have permission to access this resource.';
    }

    return 'Authentication failed. Please log in again.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = ['Log in again'];

    if (message.contains('invalid credentials') ||
        message.contains('Invalid credentials')) {
      actions.add('Check your username and password');
      actions.add('Reset your password if you forgot it');
    } else if (message.contains('permission') ||
        message.contains('access denied')) {
      actions.add('Contact your administrator for access');
    }

    return actions;
  }
}

class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (endpoint != null) {
      if (endpoint!.contains('/register') || endpoint!.contains('/signup')) {
        return 'There was a problem with your registration information. Please check the form and try again.';
      } else if (endpoint!.contains('/profile') ||
          endpoint!.contains('/user')) {
        return 'There was a problem updating your profile. Please check the information and try again.';
      } else if (endpoint!.contains('/password')) {
        return 'There was a problem with your password change request. Please check your input and try again.';
      }
    }

    return 'The information you provided is invalid. Please check your input and try again.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = [
      'Check the form for errors',
      'Correct the highlighted fields',
    ];

    if (details != null && details!.containsKey('fieldErrors')) {
      final fieldErrors = details!['fieldErrors'] as Map<String, dynamic>?;
      if (fieldErrors != null) {
        fieldErrors.forEach((field, errors) {
          if (errors is List && errors.isNotEmpty) {
            actions.add('$field: ${errors.first}');
          }
        });
      }
    }

    return actions;
  }
}

class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    return 'Unable to access local data. Please restart the app and try again.';
  }

  @override
  List<String> getSuggestedActions() {
    return [
      'Restart the application',
      'Check device storage space',
      'Clear app cache if the problem persists',
    ];
  }
}

class StorageFailure extends Failure {
  const StorageFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (message.contains('permission')) {
      return 'Storage permission denied. Please grant storage permission to use this feature.';
    } else if (message.contains('space') || message.contains('capacity')) {
      return 'Not enough storage space. Please free up some space and try again.';
    }

    return 'Storage operation failed. Please check your device storage.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = ['Check device storage settings'];

    if (message.contains('permission')) {
      actions.add('Grant storage permission in app settings');
    } else if (message.contains('space') || message.contains('capacity')) {
      actions.add('Free up device storage space');
      actions.add('Delete unnecessary files or apps');
    }

    return actions;
  }
}

class PermissionFailure extends Failure {
  const PermissionFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (message.contains('camera')) {
      return 'Camera permission is required to use this feature.';
    } else if (message.contains('location')) {
      return 'Location permission is required to use this feature.';
    } else if (message.contains('storage')) {
      return 'Storage permission is required to use this feature.';
    }

    return 'Permission denied. Please grant the required permissions to use this feature.';
  }

  @override
  List<String> getSuggestedActions() {
    return [
      'Open app settings',
      'Grant the required permissions',
      'Restart the app after granting permissions',
    ];
  }
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    if (endpoint != null) {
      if (endpoint!.contains('/auth') || endpoint!.contains('/login')) {
        return 'Authentication request timed out. Please try again.';
      } else if (endpoint!.contains('/upload') ||
          endpoint!.contains('/files')) {
        return 'File upload timed out. Please try with a smaller file or check your connection.';
      }
    }

    return 'Request timed out. Please check your connection and try again.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = ['Check your internet connection', 'Try again later'];

    if (endpoint != null &&
        (endpoint!.contains('/upload') || endpoint!.contains('/files'))) {
      actions.add('Try uploading a smaller file');
      actions.add('Use a more stable network connection');
    }

    return actions;
  }
}

class RateLimitFailure extends Failure {
  final int? retryAfterSeconds;

  const RateLimitFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
    this.retryAfterSeconds,
  });

  @override
  List<Object?> get props => [...super.props, retryAfterSeconds];

  @override
  String getUserFriendlyMessage() {
    if (retryAfterSeconds != null) {
      final minutes = (retryAfterSeconds! / 60).ceil();
      if (minutes > 1) {
        return 'Too many requests. Please try again in $minutes minutes.';
      } else {
        return 'Too many requests. Please try again in $retryAfterSeconds seconds.';
      }
    }

    return 'Too many requests. Please try again later.';
  }

  @override
  List<String> getSuggestedActions() {
    final actions = ['Wait before trying again'];

    if (retryAfterSeconds != null) {
      final minutes = (retryAfterSeconds! / 60).ceil();
      if (minutes > 1) {
        actions.add('Try again in $minutes minutes');
      } else {
        actions.add('Try again in $retryAfterSeconds seconds');
      }
    } else {
      actions.add('Try again in a few minutes');
    }

    return actions;
  }
}

class OfflineFailure extends Failure {
  const OfflineFailure(
    super.message, {
    super.endpoint,
    super.statusCode,
    super.errorCode,
    super.details,
  });

  @override
  String getUserFriendlyMessage() {
    return 'You are offline. Please check your internet connection and try again.';
  }

  @override
  List<String> getSuggestedActions() {
    return [
      'Check your internet connection',
      'Enable Wi-Fi or mobile data',
      'Try again when you\'re back online',
    ];
  }
}
