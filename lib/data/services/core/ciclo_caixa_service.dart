import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/caixa/ciclo_caixa_dto.dart';

/// Serviço para gerenciamento de Ciclos de Caixa
class CicloCaixaService {
  final ApiClient _apiClient;

  CicloCaixaService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Obtém o ciclo de caixa aberto de um caixa específico
  /// 
  /// Endpoint: GET /api/CicloCaixa/caixa/{caixaId}/aberto
  Future<ApiResponse<CicloCaixaDto?>> getCicloAbertoPorCaixa(
    String caixaId,
  ) async {
    try {
      debugPrint('🔍 Buscando ciclo aberto do caixa: $caixaId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/CicloCaixa/caixa/$caixaId/aberto',
      );

      if (response.data == null) {
        return ApiResponse<CicloCaixaDto?>.error(
          message: 'Erro ao buscar ciclo de caixa',
        );
      }

      final data = response.data!;
      final cicloData = data['data'] as Map<String, dynamic>?;

      if (cicloData == null) {
        // Não há ciclo aberto (404 é esperado)
        debugPrint('ℹ️ Nenhum ciclo aberto encontrado para o caixa');
        return ApiResponse<CicloCaixaDto?>.success(
          data: null,
          message: data['message'] as String? ?? 'Nenhum ciclo aberto encontrado',
        );
      }

      final ciclo = CicloCaixaDto.fromJson(cicloData);
      debugPrint('✅ Ciclo aberto encontrado: ${ciclo.id}');

      return ApiResponse<CicloCaixaDto?>.success(
        data: ciclo,
        message: data['message'] as String? ?? 'Ciclo aberto encontrado',
      );
    } on DioException catch (e) {
      // Tratar 404 primeiro - é esperado quando não há ciclo aberto
      if (e.response?.statusCode == 404) {
        debugPrint('ℹ️ Nenhum ciclo aberto encontrado (404) - comportamento esperado');
        try {
          // Tentar extrair mensagem do response se disponível
          final responseData = e.response?.data;
          String message = 'Nenhum ciclo aberto encontrado';
          
          if (responseData is Map<String, dynamic>) {
            message = responseData['message'] as String? ?? message;
          }
          
          return ApiResponse<CicloCaixaDto?>.success(
            data: null,
            message: message,
          );
        } catch (_) {
          // Se não conseguir parsear, retorna mensagem padrão
          return ApiResponse<CicloCaixaDto?>.success(
            data: null,
            message: 'Nenhum ciclo aberto encontrado',
          );
        }
      }
      // Se for 404, retorna null (sem erro) - é esperado quando não há ciclo aberto
      if (e.response?.statusCode == 404) {
        debugPrint('ℹ️ Nenhum ciclo aberto encontrado (404) - comportamento esperado');
        final responseData = e.response?.data as Map<String, dynamic>?;
        return ApiResponse<CicloCaixaDto?>.success(
          data: null,
          message: responseData?['message'] as String? ?? 'Nenhum ciclo aberto encontrado',
        );
      }
      // Outros erros
      debugPrint('❌ Erro ao buscar ciclo aberto: ${e.message}');
      return ApiResponse<CicloCaixaDto?>.error(
        message: 'Erro ao buscar ciclo de caixa: ${e.message ?? "Erro desconhecido"}',
      );
    } catch (e) {
      // Se for 404, retorna null (sem erro) - tratamento adicional para garantir
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('404') || 
          errorString.contains('not found') ||
          errorString.contains('recurso não encontrado')) {
        debugPrint('ℹ️ Nenhum ciclo aberto encontrado (404) - tratamento genérico');
        return ApiResponse<CicloCaixaDto?>.success(
          data: null,
          message: 'Nenhum ciclo aberto encontrado',
        );
      }

      debugPrint('❌ Erro ao buscar ciclo aberto: $e');
      return ApiResponse<CicloCaixaDto?>.error(
        message: 'Erro ao buscar ciclo aberto: ${e.toString()}',
      );
    }
  }

  /// Abre um novo ciclo de caixa
  /// 
  /// Endpoint: POST /api/CicloCaixa/abrir?pdvId={pdvId}
  Future<ApiResponse<CicloCaixaDto>> abrirCicloCaixa({
    required String caixaId,
    required double valorInicial,
    required String pdvId,
  }) async {
    try {
      debugPrint('🔓 Abrindo ciclo de caixa: Caixa=$caixaId, Valor=$valorInicial, PDV=$pdvId');

      final dto = AbrirCicloCaixaDto(
        caixaId: caixaId,
        valorInicial: valorInicial,
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/CicloCaixa/abrir?pdvId=$pdvId',
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: 'Erro ao abrir ciclo de caixa',
        );
      }

      final data = response.data!;
      
      // Verifica se a resposta indica erro (success: false)
      final success = data['success'] as bool? ?? true;
      if (!success) {
        // Extrai mensagem e erros da resposta
        final message = data['message'] as String? ?? 'Erro ao abrir ciclo de caixa';
        final errors = (data['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        
        return ApiResponse<CicloCaixaDto>.error(
          message: message,
          errors: errors,
        );
      }

      final cicloData = data['data'] as Map<String, dynamic>?;

      if (cicloData == null) {
        final message = data['message'] as String? ?? 'Erro ao abrir ciclo de caixa';
        final errors = (data['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        
        return ApiResponse<CicloCaixaDto>.error(
          message: message,
          errors: errors,
        );
      }

      final ciclo = CicloCaixaDto.fromJson(cicloData);
      debugPrint('✅ Ciclo de caixa aberto com sucesso: ${ciclo.id}');

      return ApiResponse<CicloCaixaDto>.success(
        data: ciclo,
        message: data['message'] as String? ?? 'Ciclo de caixa aberto com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao abrir ciclo de caixa: $e');
      
      // Tenta extrair mensagem de erro da exceção DioException
      String errorMessage = 'Erro ao abrir ciclo de caixa';
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              errorMessage = errors.first.toString();
            }
          } else if (responseData['message'] != null) {
            errorMessage = responseData['message'] as String;
          }
        }
      }
      
      return ApiResponse<CicloCaixaDto>.error(
        message: errorMessage,
      );
    }
  }

  /// Fecha um ciclo de caixa aberto
  /// 
  /// Endpoint: POST /api/CicloCaixa/{cicloCaixaId}/fechar
  Future<ApiResponse<CicloCaixaDto>> fecharCicloCaixa({
    required String cicloCaixaId,
    double? valorDinheiroContado,
    double? valorCartaoCreditoContado,
    double? valorCartaoDebitoContado,
    double? valorPIXContado,
    double? valorOutrosContado,
    String? observacoesFechamento,
  }) async {
    try {
      debugPrint('🔒 Fechando ciclo de caixa: $cicloCaixaId');

      final dto = FecharCicloCaixaDto(
        valorDinheiroContado: valorDinheiroContado,
        valorCartaoCreditoContado: valorCartaoCreditoContado,
        valorCartaoDebitoContado: valorCartaoDebitoContado,
        valorPIXContado: valorPIXContado,
        valorOutrosContado: valorOutrosContado,
        observacoesFechamento: observacoesFechamento,
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/CicloCaixa/$cicloCaixaId/fechar',
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: 'Erro ao fechar ciclo de caixa',
        );
      }

      final data = response.data!;
      final cicloData = data['data'] as Map<String, dynamic>?;

      if (cicloData == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: data['message'] as String? ?? 'Erro ao fechar ciclo de caixa',
        );
      }

      final ciclo = CicloCaixaDto.fromJson(cicloData);
      debugPrint('✅ Ciclo de caixa fechado com sucesso: ${ciclo.id}');

      return ApiResponse<CicloCaixaDto>.success(
        data: ciclo,
        message: data['message'] as String? ?? 'Ciclo de caixa fechado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao fechar ciclo de caixa: $e');
      return ApiResponse<CicloCaixaDto>.error(
        message: 'Erro ao fechar ciclo de caixa: ${e.toString()}',
      );
    }
  }

  /// Adiciona reforço (crédito) a um ciclo de caixa aberto
  /// 
  /// Endpoint: POST /api/CicloCaixa/reforco?pdvId={pdvId}
  Future<ApiResponse<CicloCaixaDto>> reforcoCicloCaixa({
    required String cicloCaixaId,
    required double valor,
    required String pdvId,
    String? observacoes,
  }) async {
    try {
      debugPrint('💰 Adicionando reforço ao ciclo de caixa: $cicloCaixaId, Valor=$valor');

      final dto = ReforcoCicloCaixaDto(
        cicloCaixaId: cicloCaixaId,
        valor: valor,
        observacoes: observacoes,
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/CicloCaixa/reforco?pdvId=$pdvId',
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: 'Erro ao adicionar reforço',
        );
      }

      final data = response.data!;
      final cicloData = data['data'] as Map<String, dynamic>?;

      if (cicloData == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: data['message'] as String? ?? 'Erro ao adicionar reforço',
        );
      }

      final ciclo = CicloCaixaDto.fromJson(cicloData);
      debugPrint('✅ Reforço adicionado com sucesso: ${ciclo.id}');

      return ApiResponse<CicloCaixaDto>.success(
        data: ciclo,
        message: data['message'] as String? ?? 'Reforço adicionado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao adicionar reforço: $e');
      
      String errorMessage = 'Erro ao adicionar reforço';
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              errorMessage = errors.first.toString();
            }
          } else if (responseData['message'] != null) {
            errorMessage = responseData['message'] as String;
          }
        }
      }
      
      return ApiResponse<CicloCaixaDto>.error(
        message: errorMessage,
      );
    }
  }

  /// Realiza sangria (débito) de um ciclo de caixa aberto
  /// 
  /// Endpoint: POST /api/CicloCaixa/sangria?pdvId={pdvId}
  Future<ApiResponse<CicloCaixaDto>> sangriaCicloCaixa({
    required String cicloCaixaId,
    required double valor,
    required String pdvId,
    String? observacoes,
  }) async {
    try {
      debugPrint('💸 Realizando sangria do ciclo de caixa: $cicloCaixaId, Valor=$valor');

      final dto = SangriaCicloCaixaDto(
        cicloCaixaId: cicloCaixaId,
        valor: valor,
        observacoes: observacoes,
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/CicloCaixa/sangria?pdvId=$pdvId',
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: 'Erro ao realizar sangria',
        );
      }

      final data = response.data!;
      final cicloData = data['data'] as Map<String, dynamic>?;

      if (cicloData == null) {
        return ApiResponse<CicloCaixaDto>.error(
          message: data['message'] as String? ?? 'Erro ao realizar sangria',
        );
      }

      final ciclo = CicloCaixaDto.fromJson(cicloData);
      debugPrint('✅ Sangria realizada com sucesso: ${ciclo.id}');

      return ApiResponse<CicloCaixaDto>.success(
        data: ciclo,
        message: data['message'] as String? ?? 'Sangria realizada com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao realizar sangria: $e');
      
      String errorMessage = 'Erro ao realizar sangria';
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              errorMessage = errors.first.toString();
            }
          } else if (responseData['message'] != null) {
            errorMessage = responseData['message'] as String;
          }
        }
      }
      
      return ApiResponse<CicloCaixaDto>.error(
        message: errorMessage,
      );
    }
  }
}

