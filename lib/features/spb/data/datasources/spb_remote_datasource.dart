import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/config/api_endpoints.dart';
import '../models/spb_model.dart';
import '../models/spb_response.dart';

abstract class SpbRemoteDataSource {
  /// Fetches SPB data for a driver from the remote API
  ///
  /// Throws [ServerException] for all server errors
  /// Throws [NetworkException] for network-related errors
  Future<List<SpbModel>> getSpbForDriver({
    required String driver,
    required String kdVendor,
  });
}

class SpbRemoteDataSourceImpl implements SpbRemoteDataSource {
  final Dio dio;

  SpbRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<SpbModel>> getSpbForDriver({
    required String driver,
    required String kdVendor,
  }) async {
    try {
      // final response = await dio.get(
      //   '${ApiEndpoints.baseUrl}/SPB/api/GetSPBForDriver',
      //   queryParameters: {'driver': driver, 'kdVendor': kdVendor},
      // );
      final response = await dio.get(
        ApiServiceEndpoints.dataSPB,
        queryParameters: {'driver': driver, 'kdVendor': kdVendor},
      );
      if (response.statusCode == 200) {
        // Try to parse as SpbResponse
        try {
          final spbResponse = SpbResponse.fromJson(response.data);
          if (spbResponse.success && spbResponse.data != null) {
            return spbResponse.data!;
          } else {
            throw ServerException(
              spbResponse.message ?? 'Failed to get SPB data',
            );
          }
        } catch (e) {
          // If parsing as SpbResponse fails, try to parse directly as a list
          if (response.data is List) {
            return (response.data as List)
                .map((item) => SpbModel.fromJson(item))
                .toList();
          } else if (response.data is Map<String, dynamic> &&
              response.data.containsKey('data') &&
              response.data['data'] is List) {
            return (response.data['data'] as List)
                .map((item) => SpbModel.fromJson(item))
                .toList();
          }
          throw ServerException('Failed to parse SPB data: $e');
        }
      } else {
        throw ServerException(
          'Failed to get SPB data. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ServerException || e is NetworkException) {
        rethrow;
      }
      throw ServerException('Unexpected error: $e');
    }
  }
}
