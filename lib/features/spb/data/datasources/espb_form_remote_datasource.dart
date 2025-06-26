import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_data.dart';

abstract class EspbFormRemoteDataSource {
  /// Submit ESPB form data to the API
  /// 
  /// Returns true if submission was successful
  Future<bool> submitEspbFormData(EspbFormData formData);
  
  /// Check if SPB data was already processed on the server
  /// 
  /// Returns true if the SPB has already been processed
  Future<bool> checkSpbProcessStatus(String spbNumber);
}

class EspbFormRemoteDataSourceImpl implements EspbFormRemoteDataSource {
  final Dio _dio;
  
  EspbFormRemoteDataSourceImpl({required Dio dio}) : _dio = dio;
  
  @override
  Future<bool> submitEspbFormData(EspbFormData formData) async {
    try {
      // Determine which endpoint to use based on status
      final String endpoint = formData.status == "1" 
          ? ApiServiceEndpoints.AcceptSPBDriver  // Accept SPB
          : ApiServiceEndpoints.AdjustSPBDriver; // Report kendala
      
      // Prepare request data
      final requestData = formData.toApiRequest();
      
      AppLogger.info('Submitting ESPB form data to $endpoint: $requestData');
      
      // Make API request
      final response = await _dio.put(
        endpoint,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      // Check response
      if (response.statusCode == 200) {
        AppLogger.info('Successfully submitted ESPB form data for SPB: ${formData.noSpb}');
        return true;
      } else {
        final errorMessage = 'Failed to submit ESPB form data: ${response.statusCode} - ${response.statusMessage}';
        AppLogger.error(errorMessage);
        throw ServerException(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = 'Network error submitting ESPB form data: ${e.message}';
      AppLogger.error(errorMessage);
      
      // Check if it's a network connectivity issue
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(errorMessage);
      }
      
      throw ServerException(errorMessage);
    } catch (e) {
      final errorMessage = 'Unexpected error submitting ESPB form data: $e';
      AppLogger.error(errorMessage);
      throw ServerException(errorMessage);
    }
  }
  
  @override
  Future<bool> checkSpbProcessStatus(String spbNumber) async {
    try {
      // Get SPB data from API to check its status
      final response = await _dio.get(
        ApiServiceEndpoints.dataSPB,
        queryParameters: {'noSpb': spbNumber},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        // Check if data exists and has a status other than "0" (pending)
        if (response.data != null && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data.containsKey('data') && data['data'] is List && (data['data'] as List).isNotEmpty) {
            final spbData = (data['data'] as List).first;
            final status = spbData['status']?.toString() ?? "0";
            
            // If status is not "0", it means the SPB has been processed
            return status != "0";
          }
        }
        
        // If we can't determine the status, assume it's not processed
        return false;
      } else {
        AppLogger.warning('Failed to check SPB status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.warning('Error checking SPB status: $e');
      return false; // Assume not processed on error
    }
  }
}