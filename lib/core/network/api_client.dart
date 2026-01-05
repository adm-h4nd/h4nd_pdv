import 'package:dio/dio.dart';
import '../config/env_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Cliente HTTP base usando Dio
class ApiClient {
  late final Dio _dio;
  final EnvConfig _config;

  ApiClient({
    required EnvConfig config,
    required AuthInterceptor authInterceptor,
  }) : _config = config {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.apiUrl,
        connectTimeout: config.requestTimeout,
        receiveTimeout: config.requestTimeout,
        sendTimeout: config.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Adiciona interceptors
    // IMPORTANTE: A ordem importa! O AuthInterceptor deve ser o ÚLTIMO para interceptar erros 401/403 ANTES do ErrorInterceptor
    // No Dio, os interceptors são executados na ordem inversa para onError (o último adicionado é o primeiro a receber)
    _dio.interceptors.addAll([
      if (!config.isProduction) LoggingInterceptor(),
      ErrorInterceptor(),
      authInterceptor, // Deve ser o último para interceptar 401/403 antes do ErrorInterceptor
    ]);
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}



