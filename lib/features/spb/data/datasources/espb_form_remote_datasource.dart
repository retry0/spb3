import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/espb_form_data.dart';

abstract class EspbFormRemoteDataSource {
  /// Submits form data to remote API
  ///
  /// Throws [ServerException] for server errors
  /// Throws [NetworkException] for network errors
  Future<void> submitFormData(EspbFormData formData);
  
  /// Checks if a form has already been processed on the server
  ///
  /// Throws [ServerException] for server errors
  /// Throws [NetworkException] for network errors
  Future<bool> checkFormProcessed(String noSpb, String status);
}

class EspbFormRemoteDataSourceImpl implements EspbFormRemoteDataSource {
  final Dio _dio;

  EspbFormRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<void> submitFormData(EspbFormData formData) async {
    try {
      // Determine which endpoint to use based on form type
      final String endpoint = formData.formType == EspbFormType.acceptance
          ? ApiServiceEndpoints.AcceptSPBDriver
          : ApiServiceEndpoints.AdjustSPBDriver;

      // Convert form data to API format
      final apiData = formData.toApiJson();
      
      // Log the submission attempt
      AppLogger.info('Submitting form data to $endpoint: $apiData');
      
      // Make API request
      final response = await _dio.put(
        endpoint,
        data: apiData,
      );

      // Check response
      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to submit form data: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      
      // Log success
      AppLogger.info('Form data submitted successfully: ${formData.id}');
    } on DioException catch (e) {
      // Handle Dio errors
      AppLogger.error('Network error submitting form data: ${e.message}', e);
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw TimeoutException('Connection timed out while submitting form data');
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkException('Network connection error while submitting form data');
      } else if (e.response != null) {
        throw ServerException(
          'Server error: ${e.response?.statusMessage ?? "Unknown error"}',
          statusCode: e.response?.statusCode,
          details: e.response?.data,
        );
      } else {
        throw NetworkException('Network error: ${e.message}');
      }
    } catch (e) {
      // Log and rethrow other errors
      AppLogger.error('Unexpected error submitting form data: $e');
      throw ServerException('Unexpected error submitting form data: $e');
    }
  }

  @override
  Future<bool> checkFormProcessed(String noSpb, String status) async {
    try {
      // Get SPB data to check its current status
      final response = await _dio.get(
        ApiServiceEndpoints.dataSPB,
        queryParameters: {
          'noSpb': noSpb,
        },
      );

      // Check response
      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to check SPB status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse response data
      final responseData = response.data;
      
      // Check if data exists and has the expected format
      if (responseData == null || 
          (responseData is! Map && responseData is! List)) {
        return false;
      }
      
      // Extract SPB data
      List<dynamic> spbList = [];
      if (responseData is Map && responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) {
          spbList = data;
        } else {
          return false;
        }
      } else if (responseData is List) {
        spbList = responseData;
      }
      
      // Find the SPB with matching number
      for (final spb in spbList) {
        if (spb is Map && spb.containsKey('noSpb') && spb['noSpb'] == noSpb) {
          // Check if the status matches or is more advanced
          final serverStatus = spb['status']?.toString() ?? '';
          
          // If server status matches our status or is more advanced, it's already processed
          if (serverStatus == status || 
              (status == "1" && serverStatus == "2") || 
              (status == "1" && serverStatus == "3") ||
              (status == "2" && serverStatus == "3")) {
            return true;
          }
        }
      }
      
      return false;
    } on DioException catch (e) {
      // For network errors, assume not processed to be safe
      AppLogger.error('Network error checking SPB status: ${e.message}', e);
      return false;
    } catch (e) {
      // Log error but assume not processed to be safe
      AppLogger.error('Error checking SPB status: $e');
      return false;
    }
  }
}