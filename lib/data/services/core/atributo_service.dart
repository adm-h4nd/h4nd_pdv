import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/produto_completo.dart';

/// Serviço para gerenciamento de atributos
class AtributoService {
  final ApiClient _apiClient;

  AtributoService({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Obtém um atributo completo com seus valores
  Future<ApiResponse<AtributoCompletoDto>> getAtributoCompleto(String atributoId) async {
    try {
      debugPrint('Buscando atributo completo: $atributoId');
      final response = await _apiClient.get<Map<String, dynamic>>('/atributos/$atributoId');
      
      debugPrint('Resposta do atributo: ${response.data}');
      
      final result = ApiResponse<AtributoCompletoDto>.fromJson(
        response.data!,
        (json) => AtributoCompletoDto.fromJson(json as Map<String, dynamic>),
      );
      
      if (result.success && result.data != null) {
        debugPrint('Atributo carregado: ${result.data!.nome} com ${result.data!.valores.length} valores');
      } else {
        debugPrint('Erro ao carregar atributo: ${result.message}');
      }
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('Erro ao buscar atributo $atributoId: $e');
      debugPrint('Stack trace: $stackTrace');
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is Exception) return error;
    return Exception(error.toString());
  }
}

/// DTO completo de atributo com valores (mapeado do backend)
class AtributoCompletoDto {
  final String id;
  final String nome;
  final String? descricao;
  final int totalValores;
  final bool isActive;
  final List<AtributoValorDto> valores;

  AtributoCompletoDto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.totalValores,
    required this.isActive,
    required this.valores,
  });

  factory AtributoCompletoDto.fromJson(Map<String, dynamic> json) {
    // O backend retorna AtributoDto com lista de AtributoValorBasicoDto
    final valoresJson = json['valores'] as List<dynamic>? ?? [];
    return AtributoCompletoDto(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      totalValores: json['totalValores'] as int? ?? valoresJson.length,
      isActive: json['isActive'] as bool? ?? true,
      valores: valoresJson
          .map((v) => AtributoValorDto.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

