import 'package:dio/dio.dart';

/// Resultado da verificação de healthcheck
class HealthCheckResult {
  final bool success;
  final String? message;
  final int? statusCode;

  HealthCheckResult({
    required this.success,
    this.message,
    this.statusCode,
  });
}

/// Serviço para validar healthcheck do servidor
class HealthCheckService {
  /// Verifica se o servidor está acessível e funcionando
  /// Tenta primeiro /health, depois /api/health
  static Future<HealthCheckResult> checkHealth(String baseUrl) async {
    try {
      // Normalizar URL
      String normalizedUrl = baseUrl.trim();
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'http://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      // Tentar primeiro /health
      try {
        final response = await dio.get('$normalizedUrl/health');
        if (response.statusCode == 200) {
          return HealthCheckResult(
            success: true,
            message: 'Servidor acessível',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        // Se falhar, tenta /api/health
      }

      // Tentar /api/health
      try {
        final response = await dio.get('$normalizedUrl/api/health');
        if (response.statusCode == 200) {
          return HealthCheckResult(
            success: true,
            message: 'Servidor acessível',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        // Se ambos falharem, retorna erro
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            return HealthCheckResult(
              success: false,
              message: 'Timeout ao conectar com o servidor. Verifique se o servidor está rodando.',
              statusCode: null,
            );
          } else if (e.type == DioExceptionType.connectionError) {
            return HealthCheckResult(
              success: false,
              message: 'Não foi possível conectar ao servidor. Verifique o endereço e se o servidor está acessível.',
              statusCode: null,
            );
          } else if (e.response != null) {
            return HealthCheckResult(
              success: false,
              message: 'Servidor respondeu com erro: ${e.response?.statusCode}',
              statusCode: e.response?.statusCode,
            );
          }
        }
        
        return HealthCheckResult(
          success: false,
          message: 'Erro ao verificar servidor: ${e.toString()}',
          statusCode: null,
        );
      }

      return HealthCheckResult(
        success: false,
        message: 'Servidor não respondeu corretamente',
        statusCode: null,
      );
    } catch (e) {
      return HealthCheckResult(
        success: false,
        message: 'Erro inesperado: ${e.toString()}',
        statusCode: null,
      );
    }
  }
}

