import 'package:flutter/foundation.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/services/core/pdv_service.dart';
import '../../data/services/core/caixa_service.dart';
import '../../core/services/device_id_service.dart';
import '../../data/repositories/configuracao_pdv_caixa_repository.dart';
import '../../presentation/providers/services_provider.dart';

/// Validator para validar configuração de PDV e Caixa
class ConfiguracaoPdvCaixaValidator {
  /// Valida se a configuração de PDV e Caixa está salva e é válida
  /// Retorna true se a configuração existe e ambos PDV e Caixa estão ativos
  static Future<bool> validarConfiguracao({
    required AuthService authService,
    required ServicesProvider servicesProvider,
  }) async {
    try {
      debugPrint('🔍 [ConfigValidator] Validando configuração PDV/Caixa...');

      final configRepo = ConfiguracaoPdvCaixaRepository();

      // Verificar se há configuração salva
      if (!configRepo.temConfiguracaoSalva()) {
        debugPrint('⚠️ [ConfigValidator] Nenhuma configuração salva');
        return false;
      }

      // Obter empresa selecionada
      final empresaId = await authService.getSelectedEmpresa();
      if (empresaId == null || empresaId.isEmpty) {
        debugPrint('⚠️ [ConfigValidator] Nenhuma empresa selecionada');
        return false;
      }

      final config = configRepo.carregar();
      if (config == null) {
        debugPrint('⚠️ [ConfigValidator] Nenhuma configuração salva');
        return false;
      }

      // Criar serviços
      final pdvService = PDVService(apiClient: servicesProvider.authService.apiClient);
      final caixaService = CaixaService(apiClient: servicesProvider.authService.apiClient);

      // VALIDAÇÃO CRÍTICA: Buscar o PDV completo do backend para verificar o deviceId
      debugPrint('🔍 [ConfigValidator] Buscando PDV completo do backend: ${config.pdvId}');
      final pdvCompletoResponse = await pdvService.getById(config.pdvId);

      if (!pdvCompletoResponse.success || pdvCompletoResponse.data == null) {
        debugPrint('❌ [ConfigValidator] Erro ao buscar PDV do backend: ${pdvCompletoResponse.message}');
        // Se não conseguir buscar o PDV, limpar configuração e exigir nova
        await configRepo.limpar();
        debugPrint('🧹 [ConfigValidator] Configuração limpa devido a erro ao buscar PDV');
        return false;
      }

      final pdvCompleto = pdvCompletoResponse.data!;

      // Verificar se PDV está ativo
      if (!pdvCompleto.isActive) {
        debugPrint('⚠️ [ConfigValidator] PDV está inativo: ${pdvCompleto.nome}');
        await configRepo.limpar();
        debugPrint('🧹 [ConfigValidator] Configuração limpa devido a PDV inativo');
        return false;
      }

      // VALIDAÇÃO DO DEVICE ID: Comparar deviceId do PDV com o deviceId do dispositivo atual
      final deviceIdAtual = await DeviceIdService.getDeviceId();
      final deviceIdPdv = pdvCompleto.deviceId;

      debugPrint('📱 [ConfigValidator] Device ID atual: ${deviceIdAtual.substring(0, 8)}...');
      debugPrint('📱 [ConfigValidator] Device ID do PDV: ${deviceIdPdv != null && deviceIdPdv.isNotEmpty ? deviceIdPdv.substring(0, 8) : "null"}...');

      // Se o PDV está vinculado a um dispositivo, verificar se é o dispositivo atual
      if (deviceIdPdv != null && deviceIdPdv.isNotEmpty) {
        if (deviceIdPdv != deviceIdAtual) {
          debugPrint('❌ [ConfigValidator] Device ID não confere! PDV vinculado a outro dispositivo.');
          debugPrint('   PDV Device ID: ${deviceIdPdv.substring(0, 8)}...');
          debugPrint('   Dispositivo atual: ${deviceIdAtual.substring(0, 8)}...');
          // Limpar configuração e exigir nova configuração
          await configRepo.limpar();
          debugPrint('🧹 [ConfigValidator] Configuração limpa devido a Device ID não confere');
          return false;
        }
        debugPrint('✅ [ConfigValidator] Device ID confere');
      } else {
        // PDV não está vinculado a nenhum dispositivo - isso não deveria acontecer se foi configurado corretamente
        // Mas vamos permitir por enquanto (pode ser um PDV antigo que não foi vinculado ainda)
        debugPrint('⚠️ [ConfigValidator] PDV não está vinculado a nenhum dispositivo');
      }

      // Buscar listas para validar Caixa
      final caixaResponse = await caixaService.getCaixasPorEmpresa();

      if (!caixaResponse.success || caixaResponse.data == null) {
        debugPrint('❌ [ConfigValidator] Erro ao buscar Caixas: ${caixaResponse.message}');
        return false;
      }

      // Verificar se Caixa existe e está ativo
      final caixas = caixaResponse.data!;
      final caixaValido = caixas.any(
        (c) => c.id == config.caixaId && c.isActive == true,
      );

      if (!caixaValido) {
        debugPrint('⚠️ [ConfigValidator] Caixa salvo não encontrado ou inativo: ${config.caixaId}');
        await configRepo.limpar();
        debugPrint('🧹 [ConfigValidator] Configuração limpa devido a Caixa inválido');
        return false;
      }

      debugPrint('✅ [ConfigValidator] Configuração válida: PDV=${config.pdvNome}, Caixa=${config.caixaNome}');
      return true;
    } catch (e) {
      debugPrint('❌ [ConfigValidator] Erro ao validar configuração: $e');
      return false;
    }
  }
}

