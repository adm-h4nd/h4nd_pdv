import 'package:hive/hive.dart';
import 'home_widget_type.dart';

part 'home_widget_config.g.dart';

/// Tamanho do widget na home (mantido para compatibilidade)
@HiveType(typeId: 15)
enum HomeWidgetSize {
  @HiveField(0)
  pequeno, // 1x1

  @HiveField(1)
  medio, // 2x1

  @HiveField(2)
  grande, // 2x2
}

/// Configuração de posição e tamanho de um widget
@HiveType(typeId: 16)
class HomeWidgetPosition {
  @HiveField(0)
  final double x; // Posição X em porcentagem (0.0 a 1.0)

  @HiveField(1)
  final double y; // Posição Y em porcentagem (0.0 a 1.0)

  @HiveField(2)
  final double width; // Largura em porcentagem (0.0 a 1.0)

  @HiveField(3)
  final double height; // Altura em porcentagem (0.0 a 1.0)

  HomeWidgetPosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  HomeWidgetPosition copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return HomeWidgetPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  /// Cria uma posição padrão baseada no índice
  factory HomeWidgetPosition.defaultPosition(int index) {
    // Layout em grid 3 colunas
    final col = index % 3;
    final row = (index / 3).floor();
    return HomeWidgetPosition(
      x: col * 0.33,
      y: row * 0.25,
      width: 0.31, // ~1/3 da largura com espaçamento
      height: 0.23, // ~1/4 da altura com espaçamento
    );
  }
}

/// Configuração de um widget na home do usuário
@HiveType(typeId: 14)
class HomeWidgetUserConfig {
  @HiveField(0)
  final HomeWidgetType type;

  @HiveField(1)
  final bool enabled;

  @HiveField(2)
  final int order; // Ordem de exibição (menor = primeiro)

  @HiveField(3)
  final HomeWidgetSize? size; // Tamanho antigo (mantido para compatibilidade)

  @HiveField(4)
  final HomeWidgetPosition? position; // Posição e tamanho livre

  /// Posição do widget, retorna padrão se for null
  HomeWidgetPosition get positionOrDefault => position ?? HomeWidgetPosition.defaultPosition(order);

  /// Tamanho do widget, retorna o valor padrão se for null
  HomeWidgetSize get sizeOrDefault => size ?? HomeWidgetSize.medio;

  HomeWidgetUserConfig({
    required this.type,
    this.enabled = true,
    this.order = 0,
    this.size,
    this.position,
  });

  HomeWidgetUserConfig copyWith({
    HomeWidgetType? type,
    bool? enabled,
    int? order,
    HomeWidgetSize? size,
    HomeWidgetPosition? position,
  }) {
    return HomeWidgetUserConfig(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      size: size ?? this.size,
      position: position ?? this.position,
    );
  }
}

