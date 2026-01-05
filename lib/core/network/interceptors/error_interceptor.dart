import 'package:dio/dio.dart';

/// Interceptor para tratamento de erros HTTP
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Não processa 401 e 403 aqui - deixar o AuthInterceptor tratar primeiro
    // Se o AuthInterceptor não resolver, o erro continuará sendo processado
    final statusCode = err.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      // Deixa o AuthInterceptor tratar primeiro
      handler.next(err);
      return;
    }
    
    // Converte erros HTTP em exceções mais amigáveis
    DioException error = err;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        error = DioException(
          requestOptions: err.requestOptions,
          error: 'Tempo de conexão esgotado. Verifique sua internet.',
          type: err.type,
        );
        break;
      case DioExceptionType.badResponse:
        String message = 'Erro desconhecido';
        
        if (statusCode != null) {
          switch (statusCode) {
            case 400:
              message = 'Requisição inválida';
              break;
            case 404:
              message = 'Recurso não encontrado';
              break;
            case 500:
              message = 'Erro interno do servidor';
              break;
            default:
              message = 'Erro ${statusCode}';
          }
        }
        
        error = DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          error: message,
          type: err.type,
        );
        break;
      case DioExceptionType.cancel:
        error = DioException(
          requestOptions: err.requestOptions,
          error: 'Requisição cancelada',
          type: err.type,
        );
        break;
      case DioExceptionType.unknown:
        error = DioException(
          requestOptions: err.requestOptions,
          error: 'Erro de conexão. Verifique sua internet.',
          type: err.type,
        );
        break;
      default:
        break;
    }

    handler.next(error);
  }
}



