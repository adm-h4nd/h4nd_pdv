import 'package:hive/hive.dart';

part 'home_widget_type.g.dart';

/// Tipos de widgets disponíveis para a home
@HiveType(typeId: 13)
enum HomeWidgetType {
  @HiveField(0)
  sincronizarProdutos,

  @HiveField(1)
  sincronizarVendas,

  @HiveField(2)
  mesas,

  @HiveField(3)
  comandas,

  @HiveField(4)
  configuracoes,

  @HiveField(5)
  perfil,

  @HiveField(6)
  realizarPedido,

  @HiveField(7)
  patio, // Apenas para Oficina

  @HiveField(8)
  pedidos, // Para Varejo
}

/// Configuração de disponibilidade de widgets por setor
class HomeWidgetAvailability {
  /// Mapeia setor (null = Varejo padrão) para widgets disponíveis
  static Map<int?, List<HomeWidgetType>> getWidgetsBySetor() {
    return {
      null: [ // Varejo (padrão)
        HomeWidgetType.sincronizarProdutos,
        HomeWidgetType.sincronizarVendas,
        HomeWidgetType.configuracoes,
        HomeWidgetType.perfil,
        HomeWidgetType.realizarPedido,
        HomeWidgetType.pedidos,
      ],
      2: [ // Restaurante
        HomeWidgetType.sincronizarProdutos,
        HomeWidgetType.sincronizarVendas,
        HomeWidgetType.mesas,
        HomeWidgetType.comandas,
        HomeWidgetType.configuracoes,
        HomeWidgetType.perfil,
        HomeWidgetType.realizarPedido,
      ],
      3: [ // Oficina
        HomeWidgetType.sincronizarProdutos,
        HomeWidgetType.sincronizarVendas,
        HomeWidgetType.configuracoes,
        HomeWidgetType.perfil,
        HomeWidgetType.realizarPedido,
        HomeWidgetType.patio,
      ],
    };
  }

  /// Retorna widgets disponíveis para um setor específico
  static List<HomeWidgetType> getAvailableWidgets(int? setor) {
    return getWidgetsBySetor()[setor] ?? getWidgetsBySetor()[null]!;
  }
}

