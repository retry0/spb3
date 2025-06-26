import 'package:dio/dio.dart';

abstract class HomeRemoteDataSource {
  Future<Map<String, dynamic>> getDashboardMetrics();
  Future<List<Map<String, dynamic>>> getActivities();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio _dio;

  HomeRemoteDataSourceImpl(this._dio);

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final response = await _dio.get('/dashboard/metrics');
    return response.data;
  }

  @override
  Future<List<Map<String, dynamic>>> getActivities() async {
    final response = await _dio.get('/dashboard/activities');
    return List<Map<String, dynamic>>.from(response.data);
  }
}