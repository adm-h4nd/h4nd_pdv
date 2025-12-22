import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../config/flavor_config.dart';

/// Configuração de pagamento baseada no flavor
class PaymentConfig {
  final List<String> availableProviders;
  final String? defaultProvider;
  final bool enableAutoDetection;
  final Map<String, dynamic>? providerSettings;
  
  PaymentConfig({
    required this.availableProviders,
    this.defaultProvider,
    this.enableAutoDetection = false,
    this.providerSettings,
  });
  
  /// Carrega configuração baseada no flavor atual
  static Future<PaymentConfig> load() async {
    try {
      // Detecta flavor de forma assíncrona (mais confiável)
      final flavor = await FlavorConfig.detectFlavorAsync();
      debugPrint('🔍 Flavor detectado: $flavor');
      // Normaliza nome do flavor para nome de arquivo (stoneP2 -> stone_p2)
      final flavorFileName = _normalizeFlavorFileName(flavor);
      debugPrint('📝 Flavor normalizado: $flavorFileName');
      final configPath = 'assets/config/payment_$flavorFileName.json';
      
      debugPrint('💳 Carregando payment config: $configPath');
      
      final configJson = await rootBundle.loadString(configPath);
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      
      return PaymentConfig.fromJson(configMap);
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar payment config: $e');
      // Fallback para configuração padrão (mobile)
      return PaymentConfig.defaultConfig();
    }
  }
  
  /// Normaliza nome do flavor para nome de arquivo
  /// stoneP2 -> stone_p2, mobile -> mobile
  static String _normalizeFlavorFileName(String flavor) {
    // Converte camelCase para snake_case
    // stoneP2 -> stone_p2
    return flavor.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    ).toLowerCase();
  }
  
  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    return PaymentConfig(
      availableProviders: List<String>.from(json['availableProviders'] ?? []),
      defaultProvider: json['defaultProvider'] as String?,
      enableAutoDetection: json['enableAutoDetection'] ?? false,
      providerSettings: json['providerSettings'] as Map<String, dynamic>?,
    );
  }
  
  static PaymentConfig defaultConfig() {
    return PaymentConfig(
      availableProviders: ['cash'],
    );
  }
  
  bool canUseProvider(String providerKey) {
    return availableProviders.contains(providerKey);
  }
  
  List<String> getAvailableProviders() {
    return List.from(availableProviders);
  }
}

