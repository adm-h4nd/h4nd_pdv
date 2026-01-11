import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/caixa/pdv_dto.dart';

/// Serviço para gerenciamento de PDVs
class PDVService {
  final ApiClient _apiClient;

  PDVService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Obtém lista de PDVs disponíveis para vinculação (não vinculados)
  /// Também inclui o PDV vinculado ao deviceId fornecido (se houver)
  /// 
  /// Endpoint: POST /api/PDV/search
  /// Nota: O filtro de empresa é automático via header X-Company-Id
  /// 
  /// [deviceId] - ID do dispositivo atual. Se fornecido, também inclui o PDV vinculado a esse dispositivo
  Future<ApiResponse<List<PDVListItemDto>>> getPDVsDisponiveis({String? deviceId}) async {
    try {
      debugPrint('🔍 Buscando PDVs disponíveis para vinculação${deviceId != null ? ' (incluindo PDV vinculado ao dispositivo atual)' : ''}');

      final filter = <String, dynamic>{
        'disponivelParaVinculacao': true, // Apenas PDVs não vinculados + o PDV vinculado ao deviceId (se fornecido)
      };
      
      if (deviceId != null && deviceId.isNotEmpty) {
        filter['deviceId'] = deviceId;
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/PDV/search',
        data: {
          'filter': filter,
          'pagination': {
            'page': 1,
            'pageSize': 1000, // Buscar todos
          },
        },
      );

      if (response.data == null) {
        return ApiResponse<List<PDVListItemDto>>.error(
          message: 'Erro ao buscar PDVs',
        );
      }

      final data = response.data!;
      debugPrint('📄 [PDVService] Resposta completa: $data');
      
      // O endpoint retorna data como objeto com 'list' e 'pagination' (padronizado com Caixa)
      final dataObj = data['data'] as Map<String, dynamic>?;
      debugPrint('📄 [PDVService] dataObj: $dataObj');
      
      final pdvsData = dataObj?['list'] as List<dynamic>?;
      debugPrint('📄 [PDVService] pdvsData: $pdvsData (tipo: ${pdvsData.runtimeType}, tamanho: ${pdvsData?.length ?? 0})');

      if (pdvsData == null || pdvsData.isEmpty) {
        debugPrint('⚠️ [PDVService] Nenhum PDV encontrado na resposta');
        // Retornar lista vazia ao invés de erro, para permitir que a tela mostre a mensagem apropriada
        return ApiResponse<List<PDVListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum PDV encontrado',
        );
      }

      final pdvs = <PDVListItemDto>[];
      for (var p in pdvsData) {
        try {
          final pdv = PDVListItemDto.fromJson(p as Map<String, dynamic>);
          pdvs.add(pdv);
          debugPrint('  ✅ PDV parseado: ${pdv.nome} (ID: ${pdv.id})');
        } catch (e) {
          debugPrint('  ❌ Erro ao parsear PDV: $e');
          debugPrint('  📄 Dados: $p');
        }
      }

      debugPrint('✅ PDVs encontrados: ${pdvs.length}');

      return ApiResponse<List<PDVListItemDto>>.success(
        data: pdvs,
        message: data['message'] as String? ?? 'PDVs encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar PDVs: $e');
      return ApiResponse<List<PDVListItemDto>>.error(
        message: 'Erro ao buscar PDVs: ${e.toString()}',
      );
    }
  }

  /// Obtém lista de PDVs da empresa atual (todos, sem filtro de disponibilidade)
  /// 
  /// Endpoint: POST /api/PDV/search
  /// Nota: O filtro de empresa é automático via header X-Company-Id
  Future<ApiResponse<List<PDVListItemDto>>> getPDVsPorEmpresa() async {
    try {
      debugPrint('🔍 Buscando PDVs da empresa atual');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/PDV/search',
        data: {
          'filter': {},
          'pagination': {
            'page': 1,
            'pageSize': 1000, // Buscar todos
          },
        },
      );

      if (response.data == null) {
        return ApiResponse<List<PDVListItemDto>>.error(
          message: 'Erro ao buscar PDVs',
        );
      }

      final data = response.data!;
      debugPrint('📄 [PDVService] Resposta completa: $data');
      
      // O endpoint retorna data como objeto com 'list' e 'pagination' (padronizado com Caixa)
      final dataObj = data['data'] as Map<String, dynamic>?;
      debugPrint('📄 [PDVService] dataObj: $dataObj');
      
      final pdvsData = dataObj?['list'] as List<dynamic>?;
      debugPrint('📄 [PDVService] pdvsData: $pdvsData (tipo: ${pdvsData.runtimeType}, tamanho: ${pdvsData?.length ?? 0})');

      if (pdvsData == null || pdvsData.isEmpty) {
        debugPrint('⚠️ [PDVService] Nenhum PDV encontrado na resposta');
        // Retornar lista vazia ao invés de erro, para permitir que a tela mostre a mensagem apropriada
        return ApiResponse<List<PDVListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum PDV encontrado',
        );
      }

      final pdvs = <PDVListItemDto>[];
      for (var p in pdvsData) {
        try {
          final pdv = PDVListItemDto.fromJson(p as Map<String, dynamic>);
          pdvs.add(pdv);
          debugPrint('  ✅ PDV parseado: ${pdv.nome} (ID: ${pdv.id})');
        } catch (e) {
          debugPrint('  ❌ Erro ao parsear PDV: $e');
          debugPrint('  📄 Dados: $p');
        }
      }

      debugPrint('✅ PDVs encontrados: ${pdvs.length}');

      return ApiResponse<List<PDVListItemDto>>.success(
        data: pdvs,
        message: data['message'] as String? ?? 'PDVs encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar PDVs: $e');
      return ApiResponse<List<PDVListItemDto>>.error(
        message: 'Erro ao buscar PDVs: ${e.toString()}',
      );
    }
  }

  /// Vincula um dispositivo a um PDV
  /// 
  /// Endpoint: POST /api/PDV/{id}/vincular-dispositivo
  Future<ApiResponse<PDVDto>> vincularDispositivo({
    required String pdvId,
    required String deviceId,
    String? observacoesVinculacao,
  }) async {
    try {
      debugPrint('🔗 Vinculando dispositivo $deviceId ao PDV $pdvId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/PDV/$pdvId/vincular-dispositivo',
        data: {
          'deviceId': deviceId,
          if (observacoesVinculacao != null && observacoesVinculacao.isNotEmpty)
            'observacoesVinculacao': observacoesVinculacao,
        },
      );

      if (response.data == null) {
        return ApiResponse<PDVDto>.error(
          message: 'Erro ao vincular dispositivo ao PDV',
        );
      }

      final data = response.data!;
      final pdvData = data['data'] as Map<String, dynamic>?;

      if (pdvData == null) {
        return ApiResponse<PDVDto>.error(
          message: data['message'] as String? ?? 'Erro ao vincular dispositivo',
        );
      }

      final pdv = PDVDto.fromJson(pdvData);

      debugPrint('✅ Dispositivo vinculado com sucesso ao PDV: ${pdv.nome}');

      return ApiResponse<PDVDto>.success(
        data: pdv,
        message: data['message'] as String? ?? 'Dispositivo vinculado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao vincular dispositivo: $e');
      return ApiResponse<PDVDto>.error(
        message: 'Erro ao vincular dispositivo: ${e.toString()}',
      );
    }
  }

  /// Obtém um PDV por ID
  /// 
  /// Endpoint: GET /api/PDV/{id}
  Future<ApiResponse<PDVDto>> getById(String id) async {
    try {
      debugPrint('🔍 Buscando PDV com ID: $id');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/PDV/$id',
      );

      if (response.data == null) {
        return ApiResponse<PDVDto>.error(
          message: 'Erro ao buscar PDV',
        );
      }

      final data = response.data!;
      final pdvData = data['data'] as Map<String, dynamic>?;

      if (pdvData == null) {
        return ApiResponse<PDVDto>.error(
          message: data['message'] as String? ?? 'PDV não encontrado',
        );
      }

      final pdv = PDVDto.fromJson(pdvData);

      debugPrint('✅ PDV encontrado: ${pdv.nome}');

      return ApiResponse<PDVDto>.success(
        data: pdv,
        message: data['message'] as String? ?? 'PDV encontrado',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar PDV: $e');
      return ApiResponse<PDVDto>.error(
        message: 'Erro ao buscar PDV: ${e.toString()}',
      );
    }
  }
}

