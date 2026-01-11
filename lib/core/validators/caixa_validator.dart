import 'package:flutter/foundation.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/services/core/ciclo_caixa_service.dart';
import '../../data/repositories/configuracao_pdv_caixa_repository.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/caixa/ciclo_caixa_dto.dart';

/// Resultado da validação de caixa
class CaixaValidationResult {
  final bool isValid;
  final String? message;
  final CicloCaixaDto? cicloAberto;

  CaixaValidationResult({
    required this.isValid,
    this.message,
    this.cicloAberto,
  });

  static CaixaValidationResult success({CicloCaixaDto? cicloAberto}) {
    return CaixaValidationResult(
      isValid: true,
      cicloAberto: cicloAberto,
    );
  }

  static CaixaValidationResult error(String message) {
    return CaixaValidationResult(
      isValid: false,
      message: message,
    );
  }
}

/// Validator para validar configuração e status do caixa
class CaixaValidator {
  /// Valida se PDV/Caixa está configurado e se há ciclo aberto
  /// Retorna resultado com informações do ciclo aberto (se houver)
  static Future<CaixaValidationResult> validarCaixa({
    required AuthService authService,
    required ServicesProvider servicesProvider,
  }) async {
    try {
      debugPrint('🔍 [CaixaValidator] Validando configuração e status do caixa...');

      final configRepo = ConfiguracaoPdvCaixaRepository();

      // Verificar se há configuração salva
      if (!configRepo.temConfiguracaoSalva()) {
        debugPrint('⚠️ [CaixaValidator] Nenhuma configuração PDV/Caixa salva');
        return CaixaValidationResult.error('PDV e Caixa não configurados');
      }

      final config = configRepo.carregar();
      if (config == null) {
        debugPrint('⚠️ [CaixaValidator] Erro ao carregar configuração');
        return CaixaValidationResult.error('Erro ao carregar configuração');
      }

      // Obter empresa selecionada
      final empresaId = await authService.getSelectedEmpresa();
      if (empresaId == null || empresaId.isEmpty) {
        debugPrint('⚠️ [CaixaValidator] Nenhuma empresa selecionada');
        return CaixaValidationResult.error('Nenhuma empresa selecionada');
      }

      // Buscar ciclo aberto do caixa configurado
      final cicloCaixaService = CicloCaixaService(
        apiClient: servicesProvider.authService.apiClient,
      );

      final cicloResponse = await cicloCaixaService.getCicloAbertoPorCaixa(
        config.caixaId,
      );

      if (!cicloResponse.success) {
        debugPrint('❌ [CaixaValidator] Erro ao buscar ciclo: ${cicloResponse.message}');
        return CaixaValidationResult.error(
          cicloResponse.message.isNotEmpty 
              ? cicloResponse.message 
              : 'Erro ao verificar status do caixa',
        );
      }

      final cicloAberto = cicloResponse.data;

      if (cicloAberto == null) {
        debugPrint('⚠️ [CaixaValidator] Caixa não está aberto');
        return CaixaValidationResult.error('Caixa não está aberto');
      }

      debugPrint('✅ [CaixaValidator] Caixa está aberto: ${cicloAberto.id}');
      return CaixaValidationResult.success(cicloAberto: cicloAberto);
    } catch (e) {
      debugPrint('❌ [CaixaValidator] Erro ao validar caixa: $e');
      return CaixaValidationResult.error('Erro ao validar caixa: ${e.toString()}');
    }
  }

  /// Verifica apenas se há ciclo aberto (sem validar configuração)
  static Future<CicloCaixaDto?> verificarCicloAberto({
    required String caixaId,
    required ServicesProvider servicesProvider,
  }) async {
    try {
      final cicloCaixaService = CicloCaixaService(
        apiClient: servicesProvider.authService.apiClient,
      );

      final response = await cicloCaixaService.getCicloAbertoPorCaixa(caixaId);
      return response.data;
    } catch (e) {
      debugPrint('❌ [CaixaValidator] Erro ao verificar ciclo aberto: $e');
      return null;
    }
  }
}

