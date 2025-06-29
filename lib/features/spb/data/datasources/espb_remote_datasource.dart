import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_model.dart';

abstract class EspbRemoteDataSource {
  /// Submits ESPB form data to the server
  Future<bool> submitEspbForm(EspbFormModel formData);
  
  /// Gets the sync status of an ESPB form from the server
  Future<bool> checkEspbFormSyncStatus(String noSpb);
}

class EspbRemoteDataSourceImpl implements EspbRemoteDataSource {
  final Dio _dio;
  
  EspbRemoteDataSourceImpl({required Dio dio}) : _dio = dio;
  
  @override
  Future<bool> submitEspbForm(EspbFormModel formData) async {
    try {
      // Prepare data for API
      final apiData = formData.toApiRequest();
      
      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
      
      // Determine which endpoint to use based on status
      final endpoint = formData.status == "1" 
          ? ApiServiceEndpoints.AcceptSPBDriver  // Status 1 = Accept
          : ApiServiceEndpoints.AdjustSPBDriver; // Status 2 = Kendala
      
      // Make API request
      final response = await _dio.put(
        endpoint,
        data: apiData,
        options: options,
      );
      
      // Check response
      if (response.statusCode == 200) {
        AppLogger.info('Successfully submitted ESPB form for SPB: ${formData.noSpb}');
        return true;
      } else {
        AppLogger.warning(
          'Failed to submit ESPB form for SPB: ${formData.noSpb}. Status: ${response.statusCode}',
        );
        return false;
      }
    } on DioException catch (e) {
      AppLogger.error('DioException submitting ESPB form: ${e.message}');
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw TimeoutException('Request timed out');
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkException('Network connection error');
      } else if (e.response != null) {
        throw ServerException(
          'Server error: ${e.response?.statusCode} - ${e.response?.statusMessage}',
          statusCode: e.response?.statusCode,
        );
      } else {
        throw ServerException('Failed to submit ESPB form: ${e.message}');
      }
    } catch (e) {
      AppLogger.error('Unexpected error submitting ESPB form: $e');
      throw ServerException('Unexpected error: $e');
    }
  }
  
  @override
  Future<bool> checkEspbFormSyncStatus(String noSpb) async {
    try {
      // This would typically be an API call to check if the form exists on the server
      // For now, we'll simulate this with a simple check
      
      // In a real implementation, you might have an endpoint like:
      // final response = await _dio.get('${ApiServiceEndpoints.baseUrl}/espb/status/$noSpb');
      // return response.statusCode == 200;
      
      // For demonstration purposes, we'll return true to indicate successful sync
      return true;
    } catch (e) {
      AppLogger.error('Failed to check ESPB form sync status: $e');
      return false;
    }
  }
}