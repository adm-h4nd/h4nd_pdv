import 'package:flutter/foundation.dart';
import '../storage/preferences_service.dart';
import '../constants/storage_keys.dart';
import 'app_config_service.dart';

/// Serviço para gerenciar configuração do servidor
class ServerConfigService {
  /// Verifica se o servidor está configurado
  static bool isConfigured() {
    final url = getServerUrl();
    return url != null && url.isNotEmpty;
  }

  /// Obtém a URL do servidor salva
  static String? getServerUrl() {
    return PreferencesService.getString(StorageKeys.serverUrl);
  }

  /// Salva a URL do servidor e busca configurações do backend
  static Future<bool> saveServerUrl(String url) async {
    // Normalizar URL (adicionar http:// se não tiver protocolo)
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'http://$normalizedUrl';
    }
    
    // Remover barra final se houver
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    // Salvar URL do servidor
    final saved = await PreferencesService.setString(StorageKeys.serverUrl, normalizedUrl);
    
    if (saved) {
      // Buscar configurações do backend e salvar
      debugPrint('🔧 [ServerConfigService] Buscando configurações do backend...');
      final config = await AppConfigService.fetchFromBackend(normalizedUrl);
      
      if (config != null) {
        await AppConfigService.saveConfig(config);
        debugPrint('✅ [ServerConfigService] Configurações obtidas e salvas');
      } else {
        debugPrint('⚠️ [ServerConfigService] Não foi possível obter configurações do backend');
      }
    }
    
    return saved;
  }

  /// Limpa a configuração do servidor e as configurações do app
  static Future<bool> clearServerConfig() async {
    await AppConfigService.clearConfig();
    return await PreferencesService.remove(StorageKeys.serverUrl);
  }

  /// Obtém a URL base da API (adiciona /api se necessário)
  /// Usa a URL do servidor configurada pelo usuário
  static String getApiUrl() {
    final baseUrl = getServerUrl() ?? '';
    if (baseUrl.isEmpty) return '';
    
    // Se já termina com /api, retorna como está
    if (baseUrl.endsWith('/api')) {
      return baseUrl;
    }
    
    // Adiciona /api
    return '$baseUrl/api';
  }
}

