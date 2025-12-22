import 'package:dio/dio.dart';

/// Interceptor para logging de requisições (apenas em desenvolvimento)
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────────────────');
    print('│ REQUEST: ${options.method} ${options.uri}');
    print('│ Headers: ${options.headers}');
    if (options.data != null) {
      print('│ Data: ${options.data}');
    }
    print('└─────────────────────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────────────────');
    print('│ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
    print('│ Data: ${response.data}');
    print('└─────────────────────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────────────────');
    print('│ ERROR: ${err.type}');
    print('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
    print('│ Status: ${err.response?.statusCode}');
    print('│ Message: ${err.message}');
    if (err.response?.data != null) {
      print('│ Data: ${err.response?.data}');
    }
    print('└─────────────────────────────────────────────────────────────');
    handler.next(err);
  }
}



