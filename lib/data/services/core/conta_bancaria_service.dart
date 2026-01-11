import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/caixa/conta_bancaria_dto.dart';

/// Serviço para gerenciamento de Contas Bancárias
class ContaBancariaService {
  final ApiClient _apiClient;

  ContaBancariaService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Obtém lista de contas bancárias de uma empresa específica
  /// Filtra apenas contas internas (cofre) e ativas
  /// 
  /// Endpoint: POST /api/ContaBancaria/search com filtro EmpresaId e Tipo=Interna
  Future<ApiResponse<List<ContaBancariaListItemDto>>> getContasInternasPorEmpresa(
    String empresaId,
  ) async {
    try {
      debugPrint('🔍 Buscando contas internas da empresa: $empresaId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ContaBancaria/search',
        data: {
          'filter': {
            'empresaId': empresaId,
            'tipo': 2, // TipoConta.Interna
            'isActive': true, // Apenas contas ativas
          },
          'pagination': {
            'page': 1,
            'pageSize': 1000, // Buscar todas
          },
        },
      );

      if (response.data == null) {
        return ApiResponse<List<ContaBancariaListItemDto>>.error(
          message: 'Erro ao buscar contas bancárias',
        );
      }

      final data = response.data!;
      final dataObj = data['data'] as Map<String, dynamic>?;
      final contasData = dataObj?['list'] as List<dynamic>?;

      if (contasData == null || contasData.isEmpty) {
        debugPrint('⚠️ Nenhuma conta interna encontrada');
        return ApiResponse<List<ContaBancariaListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhuma conta interna encontrada',
        );
      }

      final contas = <ContaBancariaListItemDto>[];
      for (var c in contasData) {
        try {
          final conta = ContaBancariaListItemDto.fromJson(c as Map<String, dynamic>);
          contas.add(conta);
          debugPrint('  ✅ Conta parseada: ${conta.nome} (ID: ${conta.id}, Tipo: ${conta.tipo.displayName})');
        } catch (e) {
          debugPrint('  ❌ Erro ao parsear conta: $e');
          debugPrint('  📄 Dados: $c');
        }
      }

      debugPrint('✅ Contas internas encontradas: ${contas.length}');

      return ApiResponse<List<ContaBancariaListItemDto>>.success(
        data: contas,
        message: data['message'] as String? ?? 'Contas encontradas',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar contas bancárias: $e');
      return ApiResponse<List<ContaBancariaListItemDto>>.error(
        message: 'Erro ao buscar contas bancárias: ${e.toString()}',
      );
    }
  }
}

