import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API endpoints configuration that adapts based on environment
class ApiEndpoints {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.160.225';

  // Auth endpoints
  static String get login => '$baseUrl${dotenv.env['API_LOGIN_ENDPOINT'] ?? ':8097/v1/Account/LoginUser'}';

  // Password management
  static String get changePassword =>
      '$baseUrl${dotenv.env['API_CHANGE_PASSWORD_ENDPOINT'] ?? ':8097/v1/Account/api/ChangePassword'}';

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
  static String get baseUrl => dotenv.env['API_SERVICE_URL'] ?? 'http://192.168.160.225';
  
  // Data endpoints
  static String get dataSPB => '$baseUrl${dotenv.env['API_SPB_DATA_ENDPOINT'] ?? ':8098/v1/SPB/api/GetSPBForDriver'}';

  static String get AcceptSPBDriver =>
      '$baseUrl${dotenv.env['API_ACCEPT_SPB_ENDPOINT'] ?? ':8098/v1/SPB/api/AcceptSPBByDriver'}';

  static String get AdjustSPBDriver =>
      '$baseUrl${dotenv.env['API_ADJUST_SPB_ENDPOINT'] ?? ':8098/v1/SPB/api/AdjustSPBByDriver'}';

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