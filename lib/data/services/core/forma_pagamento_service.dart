import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/caixa/forma_pagamento_disponivel_dto.dart';

/// Serviço para gerenciamento de formas de pagamento
class FormaPagamentoService {
  final ApiClient _apiClient;
  
  FormaPagamentoService({required ApiClient apiClient}) : _apiClient = apiClient;
  
  /// Obtém formas de pagamento disponíveis para uma empresa (usado no PDV)
  /// 
  /// Endpoint: GET /api/FormaPagamento/empresa/{empresaId}/disponiveis
  /// 
  /// Retorna apenas formas de pagamento com:
  /// - ExibirNoPDV = true
  /// - Ordenadas por OrdemExibicao
  /// - Inclui configurações específicas da empresa (IsIntegrada, EmitirNotaFiscal, etc.)
  Future<ApiResponse<List<FormaPagamentoDisponivelDto>>> getFormasPagamentoDisponiveisPorEmpresa(
    String empresaId,
  ) async {
    try {
      debugPrint('🔍 Buscando formas de pagamento disponíveis para empresa: $empresaId');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/FormaPagamento/empresa/$empresaId/disponiveis',
      );
      
      if (response.data == null) {
        return ApiResponse<List<FormaPagamentoDisponivelDto>>.error(
          message: 'Erro ao buscar formas de pagamento',
        );
      }
      
      final data = response.data!;
      final formasPagamentoData = data['data'] as List<dynamic>?;
      
      if (formasPagamentoData == null) {
        return ApiResponse<List<FormaPagamentoDisponivelDto>>.error(
          message: data['message'] as String? ?? 'Erro ao buscar formas de pagamento',
        );
      }
      
      final formasPagamento = formasPagamentoData
          .map((fp) => FormaPagamentoDisponivelDto.fromJson(fp as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ Formas de pagamento encontradas: ${formasPagamento.length} formas');
      
      return ApiResponse<List<FormaPagamentoDisponivelDto>>.success(
        data: formasPagamento,
        message: data['message'] as String? ?? 'Formas de pagamento carregadas com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar formas de pagamento disponíveis: $e');
      return ApiResponse<List<FormaPagamentoDisponivelDto>>.error(
        message: 'Erro ao buscar formas de pagamento: ${e.toString()}',
      );
    }
  }
}

