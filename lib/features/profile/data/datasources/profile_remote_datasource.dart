import 'package:dio/dio.dart';
import '../../../../core/config/api_endpoints.dart';

abstract class ProfileRemoteDataSource {
  Future<void> changePassword(Map<String, dynamic> data);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;

  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<void> changePassword(Map<String, dynamic> data) async {
    await _dio.put(ApiEndpoints.changePassword, data: data);
  }
}
