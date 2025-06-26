import 'environment_config.dart';

/// API endpoints configuration that adapts based on environment
class ApiEndpoints {
  static String get baseUrl => EnvironmentConfig.baseUrl;

  // Auth endpoints
  static String get login => '$baseUrl:8097/v1/Account/LoginUser';

  // Password management
  static String get changePassword =>
      '$baseUrl:8097/v1/Account/api/ChangePassword';

  /// Get endpoint with query parameters
  static String withQuery(String endpoint, Map<String, String> params) {
    if (params.isEmpty) return endpoint;

    final uri = Uri.parse(endpoint);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...params},
    );

    return newUri.toString();
  }

  /// Get all endpoints for debugging
  static Map<String, String> getAllEndpoints() {
    return {
      'baseUrl': baseUrl,
      'login': login,
      'changePassword': changePassword,
    };
  }
}

class ApiServiceEndpoints {
  static String get baseUrl => EnvironmentConfig.baseUrl;
  // Data endpoints
  static String get dataSPB => '$baseUrl:8098/v1/SPB/api/GetSPBForDriver';

  static String get AcceptSPBDriver =>
      '$baseUrl:8098/v1/SPB/api/AcceptSPBByDriver';

  static String get AdjustSPBDriver =>
      '$baseUrl:8098/v1/SPB/api/AdjustSPBByDriver';

  /// Get endpoint with query parameters
  static String withQuery(String endpoint, Map<String, String> params) {
    if (params.isEmpty) return endpoint;

    final uri = Uri.parse(endpoint);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...params},
    );

    return newUri.toString();
  }

  /// Get all endpoints for debugging
  static Map<String, String> getAllEndpoints() {
    return {'baseUrl': baseUrl, 'dataSPB': dataSPB};
  }
}
