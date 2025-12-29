import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/core/app_config.dart';
import '../storage/preferences_service.dart';

/// Serviço para gerenciar configuração do app obtida do backend
class AppConfigService {
  static const String _configKey = 'app_config';

  /// Busca configuração do backend usando a URL base do servidor
  /// Retorna null se não conseguir buscar
  static Future<AppConfig?> fetchFromBackend(String serverBaseUrl) async {
    try {
      // Normalizar URL (remover /api se tiver)
      String normalizedUrl = serverBaseUrl.trim();
      if (normalizedUrl.endsWith('/api')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 4);
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      final configUrl = '$normalizedUrl/api/health/config';
      
      debugPrint('🔧 [AppConfigService] Buscando config do backend: $configUrl');

      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(configUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final config = AppConfig.fromJson(json);
        
        debugPrint('✅ [AppConfigService] Config obtida:');
        debugPrint('  - s3BaseUrl: ${config.s3BaseUrl}');
        debugPrint('  - environment: ${config.environment}');
        
        return config;
      } else {
        debugPrint('❌ [AppConfigService] Erro ao buscar config: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [AppConfigService] Erro ao buscar config do backend: $e');
      return null;
    }
  }

  /// Salva configuração no storage
  static Future<void> saveConfig(AppConfig config) async {
    try {
      final jsonString = jsonEncode(config.toJson());
      await PreferencesService.setString(_configKey, jsonString);
      debugPrint('💾 [AppConfigService] Config salva no storage');
    } catch (e) {
      debugPrint('❌ [AppConfigService] Erro ao salvar config: $e');
    }
  }

  /// Carrega configuração do storage
  static AppConfig? loadFromStorage() {
    try {
      final saved = PreferencesService.getString(_configKey);
      if (saved == null || saved.isEmpty) {
        return null;
      }

      final json = jsonDecode(saved) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);
      
      debugPrint('📖 [AppConfigService] Config carregada do storage:');
      debugPrint('  - s3BaseUrl: ${config.s3BaseUrl}');
      
      return config;
    } catch (e) {
      debugPrint('❌ [AppConfigService] Erro ao carregar config do storage: $e');
      return null;
    }
  }

  /// Limpa configuração do storage
  static Future<void> clearConfig() async {
    await PreferencesService.remove(_configKey);
    debugPrint('🗑️ [AppConfigService] Config removida do storage');
  }
}

