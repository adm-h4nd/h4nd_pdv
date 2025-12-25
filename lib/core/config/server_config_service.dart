import '../storage/preferences_service.dart';
import '../constants/storage_keys.dart';

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

  /// Salva a URL do servidor
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
    
    return await PreferencesService.setString(StorageKeys.serverUrl, normalizedUrl);
  }

  /// Limpa a configuração do servidor
  static Future<bool> clearServerConfig() async {
    return await PreferencesService.remove(StorageKeys.serverUrl);
  }

  /// Obtém a URL base da API (adiciona /api se necessário)
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

