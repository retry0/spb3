import 'package:dio/dio.dart';

import '../../utils/logger.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.info('REQUEST[${options.method}] => PATH: ${options.path}');
    AppLogger.info('Headers: ${options.headers}');
    if (options.data != null) {
      AppLogger.info('Data: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.info('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    AppLogger.info('Data: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error('ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
    AppLogger.error('Message: ${err.message}');
    if (err.response?.data != null) {
      AppLogger.error('Error Data: ${err.response?.data}');
    }
    handler.next(err);
  }
}