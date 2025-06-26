import 'dart:io';
import 'environment_config.dart';

/// Validates environment configuration and provides helpful error messages
class EnvironmentValidator {
  /// Validate all required environment variables are set
  static ValidationResult validateEnvironment() {
    final errors = <String>[];
    final warnings = <String>[];
    final env = Platform.environment;

    // Get current environment
    final envString = env['FLUTTER_ENV'] ?? env['ENV'] ?? 'development';

    try {
      final environment = _parseEnvironment(envString);

      // Validate based on environment
      switch (environment) {
        case Environment.development:
          _validateDevelopment(env, errors, warnings);
          break;
        case Environment.staging:
          _validateStaging(env, errors, warnings);
          break;
        case Environment.production:
          _validateProduction(env, errors, warnings);
          break;
      }
    } catch (e) {
      errors.add('Invalid environment: $envString');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

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
        throw ArgumentError('Invalid environment: $envString');
    }
  }

  static void _validateDevelopment(
    Map<String, String> env,
    List<String> errors,
    List<String> warnings,
  ) {
    // DEV_API_BASE_URL is optional (has default)
    final baseUrl = env['DEV_API_BASE_URL'];
    if (baseUrl != null) {
      _validateUrl(baseUrl, 'DEV_API_BASE_URL', errors, false);
    }

    // Check for common development issues
    if (env['DEV_ENABLE_LOGGING'] == null) {
      warnings.add('DEV_ENABLE_LOGGING not set, defaulting to true');
    }
  }

  static void _validateStaging(
    Map<String, String> env,
    List<String> errors,
    List<String> warnings,
  ) {
    // STAGING_API_BASE_URL is required
    final baseUrl = env['STAGING_API_BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      errors.add('STAGING_API_BASE_URL is required for staging environment');
    } else {
      _validateUrl(baseUrl, 'STAGING_API_BASE_URL', errors, true);
    }

    // Warn about logging in staging
    if (env['STAGING_ENABLE_LOGGING'] == 'true') {
      warnings.add('Logging is enabled in staging environment');
    }
  }

  static void _validateProduction(
    Map<String, String> env,
    List<String> errors,
    List<String> warnings,
  ) {
    // PROD_API_BASE_URL is required
    final baseUrl = env['PROD_API_BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      errors.add('PROD_API_BASE_URL is required for production environment');
    } else {
      _validateUrl(baseUrl, 'PROD_API_BASE_URL', errors, true);
    }

    // Production-specific validations
    if (env['PROD_ENABLE_LOGGING'] == 'true') {
      warnings.add('Logging is enabled in production environment');
    }

    // Check for development URLs in production
    if (baseUrl != null &&
        (baseUrl.contains('localhost') ||
            baseUrl.contains('127.0.0.1') ||
            baseUrl.contains('10.0.2.2'))) {
      errors.add('Production environment cannot use localhost URLs');
    }
  }

  static void _validateUrl(
    String url,
    String varName,
    List<String> errors,
    bool requireHttps,
  ) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      errors.add('$varName has invalid URL format: $url');
      return;
    }

    if (!['http', 'https'].contains(uri.scheme)) {
      errors.add('$varName must use HTTP or HTTPS scheme');
    }

    if (requireHttps && uri.scheme != 'https') {
      errors.add('$varName must use HTTPS in production/staging');
    }

    if (uri.host.isEmpty) {
      errors.add('$varName must have a valid host');
    }
  }

  /// Generate example environment file content
  static String generateExampleEnvFile() {
    return '''
# Environment Configuration
# Set FLUTTER_ENV to: development, staging, or production
FLUTTER_ENV=development

# Development Environment
DEV_API_BASE_URL=http://localhost:8000/api
DEV_ENABLE_LOGGING=true
DEV_TIMEOUT_SECONDS=30

# Staging Environment
STAGING_API_BASE_URL=https://api-staging.yourapp.com/api
STAGING_ENABLE_LOGGING=false
STAGING_TIMEOUT_SECONDS=60

# Production Environment
PROD_API_BASE_URL=https://api.yourapp.com/api
PROD_ENABLE_LOGGING=false
PROD_TIMEOUT_SECONDS=120
''';
  }
}

/// Result of environment validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  /// Get formatted validation report
  String getReport() {
    final buffer = StringBuffer();

    if (isValid) {
      buffer.writeln('✅ Environment validation passed');
    } else {
      buffer.writeln('❌ Environment validation failed');
    }

    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (final error in errors) {
        buffer.writeln('  • $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  • $warning');
      }
    }

    return buffer.toString();
  }
}
