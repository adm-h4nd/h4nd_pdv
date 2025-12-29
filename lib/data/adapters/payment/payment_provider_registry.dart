import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'providers/cash_payment_adapter.dart';
import '../../../../core/payment/payment_config.dart';
import '../../../../core/config/flavor_config.dart';

// IMPORTANTE: NÃO importamos stone_pos_adapter.dart aqui para evitar incluir SDK Stone no flavor mobile
// O adapter Stone só será importado dinamicamente quando necessário via factory

/// Cria o adapter Stone POS apenas quando o flavor for stoneP2
/// No flavor mobile, retorna null sem tentar importar
PaymentProvider _createStonePosAdapter(Map<String, dynamic>? settings) {
  // Só importa se for flavor stoneP2
  if (!FlavorConfig.isStoneP2) {
    throw Exception('Stone POS Adapter não disponível no flavor mobile');
  }
  
  // Importação condicional usando o loader
  // No flavor mobile, a função padrão createStonePosAdapterLoader() será usada
  // No flavor stoneP2, esta função será substituída pelo import do loader
  // IMPORTANTE: Esta função só será chamada quando FlavorConfig.isStoneP2 for true
  // No flavor mobile, este código nunca será executado
  final loader = createStonePosAdapterLoader();
  return loader(settings);
}

/// Factory function para criar o loader do adapter Stone
/// Esta função será implementada diferentemente para cada flavor
/// No flavor mobile, retorna uma função que lança exceção
/// No flavor stoneP2, retorna uma função que cria o adapter real
/// 
/// IMPORTANTE: Esta função deve ser sobrescrita no arquivo stone_pos_adapter_loader.dart
/// apenas quando o flavor for stoneP2. No flavor mobile, esta implementação padrão será usada.
PaymentProvider Function(Map<String, dynamic>?) createStonePosAdapterLoader() {
  // No flavor mobile, retorna uma função que lança exceção
  // No flavor stoneP2, esta função será substituída por uma que importa o adapter real
  return (settings) {
    throw Exception('Stone POS Adapter não disponível neste flavor');
  };
}

/// Registry para gerenciar providers de pagamento
class PaymentProviderRegistry {
  static final Map<String, PaymentProvider Function(Map<String, dynamic>?)> _factories = {};
  static final Map<String, PaymentProvider> _instances = {};
  
  /// Registra um provider factory
  static void registerProvider(
    String key,
    PaymentProvider Function(Map<String, dynamic>?) factory,
  ) {
    _factories[key] = factory;
    debugPrint('✅ Payment provider registrado: $key');
  }
  
  /// Obtém um provider pelo key
  static PaymentProvider? getProvider(String key, {Map<String, dynamic>? settings}) {
    // Verifica se já existe instância
    if (_instances.containsKey(key)) {
      return _instances[key];
    }
    
    // Cria nova instância
    final factory = _factories[key];
    if (factory == null) {
      debugPrint('⚠️ Payment provider não encontrado: $key');
      return null;
    }
    
    final provider = factory(settings);
    _instances[key] = provider;
    return provider;
  }
  
  /// Registra todos os providers disponíveis baseado na configuração
  static Future<void> registerAll(PaymentConfig config) async {
    // Dinheiro sempre disponível
    registerProvider('cash', (_) => CashPaymentAdapter());
    
    if (config.canUseProvider('stone_pos')) {
      // Só registra se o flavor for stoneP2
      // No flavor mobile, o adapter não será criado, evitando importar o SDK Stone
      if (FlavorConfig.isStoneP2) {
        try {
          // Importação condicional - só cria o adapter quando necessário
          registerProvider('stone_pos', (settings) {
            return _createStonePosAdapter(settings);
          });
        } catch (e) {
          debugPrint('⚠️ Stone POS Adapter não disponível no flavor atual: $e');
        }
      } else {
        debugPrint('ℹ️ Stone POS Adapter não registrado (flavor mobile não suporta)');
      }
    }
    
    // Adicionar outros providers aqui conforme necessário
    // if (config.canUseProvider('getnet_pos')) {
    //   registerProvider('getnet_pos', (settings) => GetNetPOSAdapter(settings: settings));
    // }
    
    debugPrint('📦 Total de payment providers registrados: ${_factories.length}');
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
