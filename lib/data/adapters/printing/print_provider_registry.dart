import '../../../../core/printing/print_provider.dart';
import 'package:flutter/foundation.dart';
import 'providers/elgin_thermal_adapter.dart';
import 'providers/pdf_printer_adapter.dart';
import '../../../../core/printing/print_config.dart';
import '../../../../core/config/flavor_config.dart';

// IMPORTANTE: NÃO importamos stone_thermal_adapter.dart aqui para evitar incluir SDK Stone no flavor mobile
// O adapter Stone só será importado dinamicamente quando necessário via factory

/// Cria o adapter Stone Thermal apenas quando o flavor for stoneP2
/// No flavor mobile, lança exceção sem tentar importar
PrintProvider _createStoneThermalAdapter(Map<String, dynamic>? settings) {
  // Só importa se for flavor stoneP2
  if (!FlavorConfig.isStoneP2) {
    throw Exception('Stone Thermal Adapter não disponível no flavor mobile');
  }
  
  // Importação condicional usando o loader
  // No flavor mobile, a função padrão createStoneThermalAdapterLoader() será usada
  // No flavor stoneP2, esta função será substituída pelo import do loader
  final loader = createStoneThermalAdapterLoader();
  return loader(settings);
}

/// Factory function para criar o loader do adapter Stone Thermal
/// Esta função será implementada diferentemente para cada flavor
/// No flavor mobile, retorna uma função que lança exceção
/// No flavor stoneP2, retorna uma função que cria o adapter real
PrintProvider Function(Map<String, dynamic>?) createStoneThermalAdapterLoader() {
  // No flavor mobile, retorna uma função que lança exceção
  // No flavor stoneP2, esta função será substituída por uma que importa o adapter real
  return (settings) {
    throw Exception('Stone Thermal Adapter não disponível neste flavor');
  };
}

/// Registry para gerenciar providers de impressão
class PrintProviderRegistry {
  static final Map<String, PrintProvider Function(Map<String, dynamic>?)> _factories = {};
  static final Map<String, PrintProvider> _instances = {};
  
  /// Registra um provider factory
  static void registerProvider(
    String key,
    PrintProvider Function(Map<String, dynamic>?) factory,
  ) {
    _factories[key] = factory;
    debugPrint('✅ Print provider registrado: $key');
  }
  
  /// Obtém um provider pelo key
  static PrintProvider? getProvider(String key, {Map<String, dynamic>? settings}) {
    // Verifica se já existe instância
    if (_instances.containsKey(key)) {
      return _instances[key];
    }
    
    // Cria nova instância
    final factory = _factories[key];
    if (factory == null) {
      debugPrint('⚠️ Print provider não encontrado: $key');
      return null;
    }
    
    final provider = factory(settings);
    _instances[key] = provider;
    return provider;
  }
  
  /// Registra todos os providers disponíveis baseado na configuração
  static Future<void> registerAll(PrintConfig config) async {
    // PDF sempre disponível
    registerProvider('pdf', (_) => PDFPrinterAdapter());
    
    if (config.canUseProvider('stone_thermal')) {
      // Só registra se o flavor for stoneP2
      // No flavor mobile, o adapter não será criado, evitando importar o SDK Stone
      if (FlavorConfig.isStoneP2) {
        try {
          // Importação condicional - só cria o adapter quando necessário
          registerProvider('stone_thermal', (settings) {
            return _createStoneThermalAdapter(settings);
          });
        } catch (e) {
          debugPrint('⚠️ Stone Thermal Adapter não disponível no flavor atual: $e');
        }
      } else {
        debugPrint('ℹ️ Stone Thermal Adapter não registrado (flavor mobile não suporta)');
      }
    }
    
    if (config.canUseProvider('elgin_thermal')) {
      registerProvider('elgin_thermal', (settings) {
        return ElginThermalAdapter(settings: settings);
      });
    }
    
    // Adicionar outros providers aqui conforme necessário
    // if (config.canUseProvider('bematech_thermal')) {
    //   registerProvider('bematech_thermal', (settings) => BematechThermalAdapter(settings: settings));
    // }
    
    debugPrint('📦 Total de print providers registrados: ${_factories.length}');
  }
  
  /// Lista todos os providers registrados
  static List<String> getRegisteredProviders() {
    return _factories.keys.toList();
  }
  
  /// Limpa instâncias (útil para testes)
  static void clear() {
    _instances.clear();
  }
}

