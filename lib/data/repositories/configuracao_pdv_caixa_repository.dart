import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/preferences_service.dart';
import '../models/core/caixa/pdv_dto.dart';
import '../models/core/caixa/caixa_dto.dart';

/// Modelo para configuração de PDV e Caixa
class ConfiguracaoPdvCaixa {
  final String pdvId;
  final String pdvNome;
  final String caixaId;
  final String caixaNome;

  ConfiguracaoPdvCaixa({
    required this.pdvId,
    required this.pdvNome,
    required this.caixaId,
    required this.caixaNome,
  });

  Map<String, dynamic> toJson() => {
        'pdvId': pdvId,
        'pdvNome': pdvNome,
        'caixaId': caixaId,
        'caixaNome': caixaNome,
      };

  factory ConfiguracaoPdvCaixa.fromJson(Map<String, dynamic> json) =>
      ConfiguracaoPdvCaixa(
        pdvId: json['pdvId'] as String,
        pdvNome: json['pdvNome'] as String,
        caixaId: json['caixaId'] as String,
        caixaNome: json['caixaNome'] as String,
      );
}

/// Repositório para gerenciar configuração de PDV e Caixa
class ConfiguracaoPdvCaixaRepository {
  static const String _keyConfiguracao = 'configuracao_pdv_caixa';

  /// Salva a configuração localmente
  Future<void> salvar(ConfiguracaoPdvCaixa config) async {
    try {
      final jsonString = jsonEncode(config.toJson());
      await PreferencesService.setString(_keyConfiguracao, jsonString);
      debugPrint('✅ Configuração PDV/Caixa salva: PDV=${config.pdvNome}, Caixa=${config.caixaNome}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar configuração PDV/Caixa: $e');
    }
  }

  /// Carrega a configuração localmente
  ConfiguracaoPdvCaixa? carregar() {
    try {
      final jsonString = PreferencesService.getString(_keyConfiguracao);
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('ℹ️ Nenhuma configuração PDV/Caixa encontrada');
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final config = ConfiguracaoPdvCaixa.fromJson(json);
      debugPrint('✅ Configuração PDV/Caixa carregada: PDV=${config.pdvNome}, Caixa=${config.caixaNome}');
      return config;
    } catch (e) {
      debugPrint('❌ Erro ao carregar configuração PDV/Caixa: $e');
      return null;
    }
  }

  /// Limpa a configuração local
  Future<void> limpar() async {
    try {
      await PreferencesService.remove(_keyConfiguracao);
      debugPrint('✅ Configuração PDV/Caixa removida');
    } catch (e) {
      debugPrint('❌ Erro ao limpar configuração PDV/Caixa: $e');
    }
  }

  /// Verifica se há configuração salva
  bool temConfiguracaoSalva() {
    return PreferencesService.containsKey(_keyConfiguracao);
  }

  /// Valida se a configuração salva ainda é válida
  /// Retorna true se ambos PDV e Caixa existem e estão ativos nas listas fornecidas
  bool validarConfiguracaoSalva({
    required List<PDVListItemDto> pdvs,
    required List<CaixaListItemDto> caixas,
  }) {
    final config = carregar();
    if (config == null) {
      debugPrint('⚠️ Nenhuma configuração salva para validar');
      return false;
    }

    // Verificar se PDV existe e está ativo
    final pdvValido = pdvs.any(
      (p) => p.id == config.pdvId && p.isActive == true,
    );

    if (!pdvValido) {
      debugPrint('⚠️ PDV salvo não encontrado ou inativo: ${config.pdvId}');
      return false;
    }

    // Verificar se Caixa existe e está ativo
    final caixaValido = caixas.any(
      (c) => c.id == config.caixaId && c.isActive == true,
    );

    if (!caixaValido) {
      debugPrint('⚠️ Caixa salvo não encontrado ou inativo: ${config.caixaId}');
      return false;
    }

    debugPrint('✅ Configuração PDV/Caixa válida: PDV=${config.pdvNome}, Caixa=${config.caixaNome}');
    return true;
  }
}

