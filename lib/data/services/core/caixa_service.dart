import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/caixa/caixa_dto.dart';

/// Serviço para gerenciamento de Caixas
class CaixaService {
  final ApiClient _apiClient;

  CaixaService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Obtém lista de Caixas da empresa atual
  /// 
  /// Endpoint: POST /api/Caixa/search
  /// Nota: O filtro de empresa é automático via header X-Company-Id
  Future<ApiResponse<List<CaixaListItemDto>>> getCaixasPorEmpresa() async {
    try {
      debugPrint('🔍 Buscando Caixas da empresa atual');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/Caixa/search',
        data: {
          'filter': {},
          'pagination': {
            'page': 1,
            'pageSize': 1000, // Buscar todos
          },
        },
      );

      if (response.data == null) {
        return ApiResponse<List<CaixaListItemDto>>.error(
          message: 'Erro ao buscar Caixas',
        );
      }

      final data = response.data!;
      debugPrint('📄 [CaixaService] Resposta completa: $data');
      
      // O endpoint retorna data como objeto com 'list' e 'pagination'
      final dataObj = data['data'] as Map<String, dynamic>?;
      debugPrint('📄 [CaixaService] dataObj: $dataObj');
      
      final caixasData = dataObj?['list'] as List<dynamic>?;
      debugPrint('📄 [CaixaService] caixasData: $caixasData (tipo: ${caixasData.runtimeType})');

      if (caixasData == null || caixasData.isEmpty) {
        debugPrint('⚠️ [CaixaService] Nenhum Caixa encontrado na resposta');
        // Retornar lista vazia ao invés de erro, para permitir que a tela mostre a mensagem apropriada
        return ApiResponse<List<CaixaListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum Caixa encontrado',
        );
      }

      final caixas = <CaixaListItemDto>[];
      for (var c in caixasData) {
        try {
          final caixa = CaixaListItemDto.fromJson(c as Map<String, dynamic>);
          caixas.add(caixa);
          debugPrint('  ✅ Caixa parseado: ${caixa.nome} (ID: ${caixa.id})');
        } catch (e) {
          debugPrint('  ❌ Erro ao parsear Caixa: $e');
          debugPrint('  📄 Dados: $c');
        }
      }

      debugPrint('✅ Caixas encontrados: ${caixas.length}');

      return ApiResponse<List<CaixaListItemDto>>.success(
        data: caixas,
        message: data['message'] as String? ?? 'Caixas encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar Caixas: $e');
      return ApiResponse<List<CaixaListItemDto>>.error(
        message: 'Erro ao buscar Caixas: ${e.toString()}',
      );
    }
  }

  /// Obtém um Caixa por ID
  /// 
  /// Endpoint: GET /api/Caixa/{id}
  Future<ApiResponse<CaixaDto>> getById(String id) async {
    try {
      debugPrint('🔍 Buscando Caixa com ID: $id');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/Caixa/$id',
      );

      if (response.data == null) {
        return ApiResponse<CaixaDto>.error(
          message: 'Erro ao buscar Caixa',
        );
      }

      final data = response.data!;
      final caixaData = data['data'] as Map<String, dynamic>?;

      if (caixaData == null) {
        return ApiResponse<CaixaDto>.error(
          message: data['message'] as String? ?? 'Caixa não encontrado',
        );
      }

      final caixa = CaixaDto.fromJson(caixaData);

      debugPrint('✅ Caixa encontrado: ${caixa.nome}');

      return ApiResponse<CaixaDto>.success(
        data: caixa,
        message: data['message'] as String? ?? 'Caixa encontrado',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar Caixa: $e');
      return ApiResponse<CaixaDto>.error(
        message: 'Erro ao buscar Caixa: ${e.toString()}',
      );
    }
  }
}

