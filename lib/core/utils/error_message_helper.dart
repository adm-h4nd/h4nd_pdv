import 'package:dio/dio.dart';
import '../../data/models/core/api_response.dart';

/// Helper para formatar mensagens de erro de forma amigável
class ErrorMessageHelper {
  /// Extrai e formata a mensagem de erro de uma ApiResponse
  /// Prioriza: errors[0] > message > mensagem padrão
  static String getErrorMessage(ApiResponse response, {String? defaultMessage}) {
    // Se tiver erros, usa o primeiro erro
    if (response.errors.isNotEmpty) {
      return response.errors.first;
    }
    
    // Se tiver message, usa ela
    if (response.message.isNotEmpty) {
      return response.message;
    }
    
    // Usa mensagem padrão ou genérica
    return defaultMessage ?? 'Ocorreu um erro ao processar sua solicitação.';
  }

  /// Extrai mensagem de erro de uma exceção DioException
  static String getErrorMessageFromException(dynamic exception) {
    if (exception is DioException) {
      // Tenta extrair da resposta
      final responseData = exception.response?.data;
      if (responseData is Map<String, dynamic>) {
        // Tenta obter do array de erros primeiro
        if (responseData['errors'] != null && responseData['errors'] is List) {
          final errors = responseData['errors'] as List;
          if (errors.isNotEmpty) {
            return errors.first.toString();
          }
        }
        // Se não tiver erros, tenta message
        if (responseData['message'] != null && responseData['message'] is String) {
          return responseData['message'] as String;
        }
      }
      // Se não conseguir extrair, usa a mensagem do Dio
      return exception.message ?? 'Erro de conexão';
    }
    
    return exception.toString();
  }
}

