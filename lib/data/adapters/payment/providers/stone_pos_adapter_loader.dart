// Arquivo de loader para Stone POS Adapter
// IMPORTANTE: Este arquivo importa o SDK Stone, então só deve ser usado no flavor stoneP2
// No flavor mobile, este arquivo NÃO deve ser importado
// 
// SOLUÇÃO: Este arquivo só será importado no flavor stoneP2 via import condicional
// No flavor mobile, a função padrão em payment_provider_registry.dart será usada
//
// NOTA: Para que este arquivo funcione corretamente, ele precisa ser importado
// apenas quando o flavor for stoneP2. No flavor mobile, o import deste arquivo
// causará erro porque stone_pos_adapter.dart importa o SDK Stone.

import '../../../../core/payment/payment_provider.dart';
import '../../../../core/config/flavor_config.dart';
// Este import só funciona no flavor stoneP2
// No flavor mobile, este import causará erro se o SDK Stone não estiver disponível
// Por isso, este arquivo só deve ser importado quando o flavor for stoneP2
import 'stone_pos_adapter.dart';

/// Factory function para criar Stone POS Adapter apenas quando necessário
/// Esta função substitui a função padrão em payment_provider_registry.dart
/// IMPORTANTE: Esta função só deve ser chamada no flavor stoneP2
/// 
/// Para usar este loader no flavor stoneP2, importe este arquivo em payment_provider_registry.dart:
/// ```dart
/// if (FlavorConfig.isStoneP2) {
///   import 'providers/stone_pos_adapter_loader.dart';
/// }
/// ```
/// Mas como Dart não suporta imports condicionais, a solução é usar ProGuard/R8
/// para remover as classes Stone no flavor mobile.
PaymentProvider Function(Map<String, dynamic>?) createStonePosAdapterLoader() {
  // Retorna uma função que cria o adapter Stone
  // Esta implementação só será usada no flavor stoneP2
  return (settings) {
    return StonePOSAdapter(settings: settings);
  };
}

