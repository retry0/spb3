import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment types supported by the application
enum Environment { development, staging, production }

/// Environment configuration class that manages endpoint URLs and settings
/// based on environment variables with security best practices
class EnvironmentConfig {
  static Environment? _currentEnvironment;
  static String? _baseUrl;
  static bool? _enableLogging;
  static Duration? _timeout;
  static bool _initialized = false;

  /// Initialize the environment configuration
  /// Must be called before accessing any configuration values
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Determine environment from ENV variable
      final envString = dotenv.env['FLUTTER_ENV'] ?? 'development';

      _currentEnvironment = _parseEnvironment(envString);

      // Load configuration based on environment
      await _loadConfiguration();

      _initialized = true;
    } catch (e) {
      throw EnvironmentConfigException(
        'Failed to initialize environment configuration: $e',
      );
    }
  }

  /// Parse environment string to Environment enum
  static Environment _parseEnvironment(String envString) {
    switch (envString.toLowerCase()) {
      case 'dev':
      case 'development':
        return Environment.development;
      case 'stage':
      case 'staging':
        return Environment.staging;
      case 'prod':
      case 'production':
        return Environment.production;
      default:
        throw EnvironmentConfigException(
          'Invalid environment: $envString. '
          'Valid values: development, staging, production',
        );
    }
  }

  /// Load configuration based on current environment
  static Future<void> _loadConfiguration() async {
    switch (_currentEnvironment!) {
      case Environment.development:
        _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.160.225';
        _enableLogging = _getBoolEnvVar('ENABLE_LOGGING', true);
        _timeout = Duration(
          seconds: _getIntEnvVar('API_TIMEOUT_SECONDS', 30),
        );
        break;

      case Environment.staging:
        _baseUrl = _getRequiredEnvVar('API_BASE_URL');
        _enableLogging = _getBoolEnvVar('ENABLE_LOGGING', false);
        _timeout = Duration(
          seconds: _getIntEnvVar('API_TIMEOUT_SECONDS', 60),
        );
        break;

      case Environment.production:
        _baseUrl = _getRequiredEnvVar('API_BASE_URL');
        _enableLogging = _getBoolEnvVar('ENABLE_LOGGING', false);
        _timeout = Duration(
          seconds: _getIntEnvVar('API_TIMEOUT_SECONDS', 120),
        );
        break;
    }

    // Validate URL format
    _validateUrl(_baseUrl!);
  }

  /// Get required environment variable with optional default
  static String _getRequiredEnvVar(String key, [String? defaultValue]) {
    final value = dotenv.env[key] ?? defaultValue;
    if (value == null || value.isEmpty) {
      throw EnvironmentConfigException(
        'Required environment variable $key is not set',
      );
    }
    return value;
  }

  /// Get boolean environment variable with default
  static bool _getBoolEnvVar(String key, bool defaultValue) {
    final value = dotenv.env[key];
    if (value == null) return defaultValue;

    switch (value.toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        throw EnvironmentConfigException(
          'Invalid boolean value for $key: $value. '
          'Valid values: true, false, 1, 0, yes, no',
        );
    }
  }

  /// Get integer environment variable with default
  static int _getIntEnvVar(String key, int defaultValue) {
    final value = dotenv.env[key];
    if (value == null) return defaultValue;

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw EnvironmentConfigException(
        'Invalid integer value for $key: $value',
      );
    }
    return parsed;
  }

  /// Validate URL format and security requirements
  static void _validateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw EnvironmentConfigException('Invalid URL format: $url');
    }

    // Ensure HTTPS in production
    if (_currentEnvironment == Environment.production &&
        uri.scheme != 'https') {
      throw EnvironmentConfigException(
        'Production environment requires HTTPS URLs. Got: ${uri.scheme}',
      );
    }

    // Validate scheme
    if (!['http', 'https'].contains(uri.scheme)) {
      throw EnvironmentConfigException(
        'Invalid URL scheme: ${uri.scheme}. Only HTTP and HTTPS are allowed',
      );
    }

    // Validate host
    if (uri.host.isEmpty) {
      throw EnvironmentConfigException('URL must have a valid host');
    }
  }

  /// Get current environment
  static Environment get currentEnvironment {
    _ensureInitialized();
    return _currentEnvironment!;
  }

  /// Get base API URL
  static String get baseUrl {
    _ensureInitialized();
    return _baseUrl!;
  }

  /// Check if logging is enabled
  static bool get isLoggingEnabled {
    _ensureInitialized();
    return _enableLogging!;
  }

  /// Get request timeout duration
  static Duration get timeout {
    _ensureInitialized();
    return _timeout!;
  }

  /// Check if running in development mode
  static bool get isDevelopment =>
      currentEnvironment == Environment.development;

  /// Check if running in staging mode
  static bool get isStaging => currentEnvironment == Environment.staging;

  /// Check if running in production mode
  static bool get isProduction => currentEnvironment == Environment.production;

  /// Get environment name as string
  static String get environmentName {
    switch (currentEnvironment) {
      case Environment.development:
        return 'development';
      case Environment.staging:
        return 'staging';
      case Environment.production:
        return 'production';
    }
  }

  /// Ensure configuration is initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      throw EnvironmentConfigException(
        'EnvironmentConfig not initialized. Call EnvironmentConfig.initialize() first.',
      );
    }
  }

  /// Reset configuration (for testing purposes)
  static void reset() {
    _currentEnvironment = null;
    _baseUrl = null;
    _enableLogging = null;
    _timeout = null;
    _initialized = false;
  }

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    _ensureInitialized();
    return {
      'environment': environmentName,
      'baseUrl': baseUrl,
      'loggingEnabled': isLoggingEnabled,
      'timeout': '${timeout.inSeconds}s',
      'isProduction': isProduction,
    };
  }
}

/// Exception thrown when environment configuration fails
class EnvironmentConfigException implements Exception {
  final String message;

  const EnvironmentConfigException(this.message);

  @override
  String toString() => 'EnvironmentConfigException: $message';
}