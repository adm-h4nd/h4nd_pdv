import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../config/flavor_config.dart';

/// Tipo de documento para impressão
enum DocumentType {
  comandaConferencia,
  orcamento,
  parcialVenda,
  nfce,
  cupomFiscal,
  recibo,
}

/// Estratégia de saída de impressão
enum OutputStrategy {
  thermalPrinter,
  networkPrinter,
  pdf,
  share,
  preview,
}

/// Configuração de impressão baseada no flavor
class PrintConfig {
  final Map<DocumentType, DocumentOutputConfig> documentConfigs;
  final List<String> supportedProviders;
  final String? defaultProvider;
  final Map<String, dynamic>? providerSettings;
  
  PrintConfig({
    required this.documentConfigs,
    required this.supportedProviders,
    this.defaultProvider,
    this.providerSettings,
  });
  
  /// Carrega configuração baseada no flavor atual
  static Future<PrintConfig> load() async {
    try {
      // Detecta flavor de forma assíncrona (mais confiável)
      final flavor = await FlavorConfig.detectFlavorAsync();
      debugPrint('🔍 Flavor detectado: $flavor');
      // Normaliza nome do flavor para nome de arquivo (stoneP2 -> stone_p2)
      final flavorFileName = _normalizeFlavorFileName(flavor);
      debugPrint('📝 Flavor normalizado: $flavorFileName');
      final configPath = 'assets/config/print_$flavorFileName.json';
      
      debugPrint('🖨️ Carregando print config: $configPath');
      
      final configJson = await rootBundle.loadString(configPath);
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      
      return PrintConfig.fromJson(configMap);
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar print config: $e');
      return PrintConfig.defaultConfig();
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
  
  factory PrintConfig.fromJson(Map<String, dynamic> json) {
    final documentConfigs = <DocumentType, DocumentOutputConfig>{};
    
    final docs = json['documents'] as Map<String, dynamic>? ?? {};
    docs.forEach((key, value) {
      try {
        final docType = DocumentType.values.firstWhere(
          (e) => e.name == key,
        );
        
        documentConfigs[docType] = DocumentOutputConfig.fromJson(value);
      } catch (e) {
        debugPrint('⚠️ DocumentType $key não encontrado: $e');
      }
    });
    
    return PrintConfig(
      documentConfigs: documentConfigs,
      supportedProviders: List<String>.from(json['supportedProviders'] ?? []),
      defaultProvider: json['defaultProvider'] as String?,
      providerSettings: json['providerSettings'] as Map<String, dynamic>?,
    );
  }
  
  static PrintConfig defaultConfig() {
    return PrintConfig(
      documentConfigs: {
        DocumentType.comandaConferencia: DocumentOutputConfig(
          defaultOutput: OutputStrategy.pdf,
          availableOutputs: [OutputStrategy.pdf, OutputStrategy.share],
        ),
      },
      supportedProviders: ['pdf'],
    );
  }
  
  DocumentOutputConfig? getConfigFor(DocumentType type) {
    return documentConfigs[type];
  }
  
  bool canUseProvider(String providerKey) {
    return supportedProviders.contains(providerKey);
  }
}

/// Configuração de saída para um tipo de documento
class DocumentOutputConfig {
  final OutputStrategy defaultOutput;
  final List<OutputStrategy> availableOutputs;
  final String? providerKey;
  
  DocumentOutputConfig({
    required this.defaultOutput,
    required this.availableOutputs,
    this.providerKey,
  });
  
  factory DocumentOutputConfig.fromJson(Map<String, dynamic> json) {
    return DocumentOutputConfig(
      defaultOutput: OutputStrategy.values.firstWhere(
        (e) => e.name == json['defaultOutput'],
      ),
      availableOutputs: (json['availableOutputs'] as List)
          .map((e) => OutputStrategy.values.firstWhere(
                (s) => s.name == e,
              ))
          .toList(),
      providerKey: json['providerKey'] as String?,
    );
  }
}

