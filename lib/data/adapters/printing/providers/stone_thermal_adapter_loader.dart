// Arquivo de loader para Stone Thermal Adapter
// IMPORTANTE: Este arquivo importa o SDK Stone, então só deve ser usado no flavor stoneP2
// No flavor mobile, este arquivo NÃO deve ser importado
// 
// SOLUÇÃO: Este arquivo só será importado no flavor stoneP2 via import condicional
// No flavor mobile, a função padrão em print_provider_registry.dart será usada

import '../../../../core/printing/print_provider.dart';
import '../../../../core/config/flavor_config.dart';
// Este import só funciona no flavor stoneP2
// No flavor mobile, este import causará erro se o SDK Stone não estiver disponível
// Por isso, este arquivo só deve ser importado quando o flavor for stoneP2
import 'stone_thermal_adapter.dart';

/// Factory function para criar Stone Thermal Adapter apenas quando necessário
/// Esta função substitui a função padrão em print_provider_registry.dart
/// IMPORTANTE: Esta função só deve ser chamada no flavor stoneP2
PrintProvider Function(Map<String, dynamic>?) createStoneThermalAdapterLoader() {
  // Retorna uma função que cria o adapter Stone
  // Esta implementação só será usada no flavor stoneP2
  return (settings) {
    return StoneThermalAdapter(settings: settings);
  };
}

