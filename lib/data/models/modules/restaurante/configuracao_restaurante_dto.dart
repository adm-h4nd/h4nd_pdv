/// DTO para configuração do restaurante
class ConfiguracaoRestauranteDto {
  final String id;
  final String empresaId;
  final String empresaNome;
  
  // Visualização
  final int tipoVisualizacaoMesas; // TipoVisualizacaoMesas enum
  
  // Configurações de Mesas
  final bool permiteMesasSemPosicao;
  
  // Configurações de Pedidos
  final bool permitePedidosSemMesa;
  final bool permiteMultiplosPedidosPorMesa;
  
  // Controle de Vendas
  final int tipoControleVenda; // TipoControleVenda enum (1 = PorMesa, 2 = PorComanda)
  
  // Propriedades calculadas
  final bool mapaDisponivel;
  final bool listaDisponivel;
  final bool controlePorMesa;
  final bool controlePorComanda;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  ConfiguracaoRestauranteDto({
    required this.id,
    required this.empresaId,
    required this.empresaNome,
    required this.tipoVisualizacaoMesas,
    required this.permiteMesasSemPosicao,
    required this.permitePedidosSemMesa,
    required this.permiteMultiplosPedidosPorMesa,
    required this.tipoControleVenda,
    required this.mapaDisponivel,
    required this.listaDisponivel,
    required this.controlePorMesa,
    required this.controlePorComanda,
    required this.createdAt,
    this.updatedAt,
  });

  factory ConfiguracaoRestauranteDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final empresaIdValue = json['empresaId'];
    final empresaId = empresaIdValue is String 
        ? empresaIdValue 
        : empresaIdValue?.toString() ?? '';

    final tipoVisualizacaoMesasValue = json['tipoVisualizacaoMesas'];
    final tipoVisualizacaoMesas = tipoVisualizacaoMesasValue is int 
        ? tipoVisualizacaoMesasValue 
        : (tipoVisualizacaoMesasValue != null ? int.tryParse(tipoVisualizacaoMesasValue.toString()) ?? 0 : 0);

    final tipoControleVendaValue = json['tipoControleVenda'];
    final tipoControleVenda = tipoControleVendaValue is int 
        ? tipoControleVendaValue 
        : (tipoControleVendaValue != null ? int.tryParse(tipoControleVendaValue.toString()) ?? 1 : 1);

    final createdAtValue = json['createdAt'];
    final createdAt = createdAtValue is String 
        ? DateTime.tryParse(createdAtValue) ?? DateTime.now()
        : (createdAtValue is DateTime ? createdAtValue : DateTime.now());

    final updatedAtValue = json['updatedAt'];
    final DateTime? updatedAt = updatedAtValue != null
        ? (updatedAtValue is String 
            ? DateTime.tryParse(updatedAtValue)
            : (updatedAtValue is DateTime ? updatedAtValue : null))
        : null;

    return ConfiguracaoRestauranteDto(
      id: id,
      empresaId: empresaId,
      empresaNome: json['empresaNome'] as String? ?? '',
      tipoVisualizacaoMesas: tipoVisualizacaoMesas,
      permiteMesasSemPosicao: json['permiteMesasSemPosicao'] as bool? ?? true,
      permitePedidosSemMesa: json['permitePedidosSemMesa'] as bool? ?? true,
      permiteMultiplosPedidosPorMesa: json['permiteMultiplosPedidosPorMesa'] as bool? ?? false,
      tipoControleVenda: tipoControleVenda,
      mapaDisponivel: json['mapaDisponivel'] as bool? ?? false,
      listaDisponivel: json['listaDisponivel'] as bool? ?? false,
      controlePorMesa: json['controlePorMesa'] as bool? ?? (tipoControleVenda == 1),
      controlePorComanda: json['controlePorComanda'] as bool? ?? (tipoControleVenda == 2),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'tipoVisualizacaoMesas': tipoVisualizacaoMesas,
      'permiteMesasSemPosicao': permiteMesasSemPosicao,
      'permitePedidosSemMesa': permitePedidosSemMesa,
      'permiteMultiplosPedidosPorMesa': permiteMultiplosPedidosPorMesa,
      'tipoControleVenda': tipoControleVenda,
      'mapaDisponivel': mapaDisponivel,
      'listaDisponivel': listaDisponivel,
      'controlePorMesa': controlePorMesa,
      'controlePorComanda': controlePorComanda,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
