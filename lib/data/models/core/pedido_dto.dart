import 'pedido_list_item.dart';

/// DTO completo para Pedido (retornado pelo backend após criação)
class PedidoDto extends PedidoListItemDto {
  final String tipoContexto;
  final String? contextoNome;
  final String? contextoDescricao;
  final String? clienteCPF;
  final String? clienteCNPJ;
  final DateTime? dataPrevisaoEntrega;
  final DateTime? dataFinalizacao;
  final DateTime? dataCancelamento;
  final double subtotal;
  final double descontoTotal;
  final double percentualDesconto;
  final double acrescimoTotal;
  final double impostosTotal;
  final double freteTotal;
  final String? observacoes;
  final String? motivoCancelamento;
  final String? transacaoEstoqueId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  /// ID da venda vinculada ao pedido (retornado para facilitar acesso direto)
  final String? vendaId;

  PedidoDto({
    required super.id,
    required super.numero,
    required super.tipo,
    required super.status,
    super.mesaId,
    super.mesaNumero,
    super.comandaId,
    super.comandaNumero,
    super.clienteId,
    required super.clienteNome,
    super.vendedorId,
    super.vendedorNome,
    required super.dataPedido,
    required super.valorTotal,
    required super.isActive,
    required this.tipoContexto,
    this.contextoNome,
    this.contextoDescricao,
    this.clienteCPF,
    this.clienteCNPJ,
    this.dataPrevisaoEntrega,
    this.dataFinalizacao,
    this.dataCancelamento,
    required this.subtotal,
    required this.descontoTotal,
    required this.percentualDesconto,
    required this.acrescimoTotal,
    required this.impostosTotal,
    required this.freteTotal,
    this.observacoes,
    this.motivoCancelamento,
    this.transacaoEstoqueId,
    required this.createdAt,
    this.updatedAt,
    this.vendaId,
  });

  factory PedidoDto.fromJson(Map<String, dynamic> json) {
    // Primeiro, cria o PedidoListItemDto base
    final base = PedidoListItemDto.fromJson(json);

    // Processa tipoContexto
    final tipoContextoValue = json['tipoContexto'];
    String tipoContexto = 'Direto';
    if (tipoContextoValue is int) {
      // TipoContextoPedido: 1=Direto, 2=Mesa, 3=Comanda, 4=Veiculo
      switch (tipoContextoValue) {
        case 1:
          tipoContexto = 'Direto';
          break;
        case 2:
          tipoContexto = 'Mesa';
          break;
        case 3:
          tipoContexto = 'Comanda';
          break;
        case 4:
          tipoContexto = 'Veiculo';
          break;
        default:
          tipoContexto = 'Direto';
      }
    } else if (tipoContextoValue is String) {
      tipoContexto = tipoContextoValue;
    }

    // Processa datas opcionais
    DateTime? parseOptionalDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      if (value is DateTime) return value;
      return null;
    }

    // Processa valores numéricos
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Processa vendaId
    final vendaIdValue = json['vendaId'];
    final vendaId = vendaIdValue?.toString();

    return PedidoDto(
      id: base.id,
      numero: base.numero,
      tipo: base.tipo,
      status: base.status,
      mesaId: base.mesaId,
      mesaNumero: base.mesaNumero,
      comandaId: base.comandaId,
      comandaNumero: base.comandaNumero,
      clienteId: base.clienteId,
      clienteNome: base.clienteNome,
      vendedorId: base.vendedorId,
      vendedorNome: base.vendedorNome,
      dataPedido: base.dataPedido,
      valorTotal: base.valorTotal,
      isActive: base.isActive,
      tipoContexto: tipoContexto,
      contextoNome: json['contextoNome'] as String?,
      contextoDescricao: json['contextoDescricao'] as String?,
      clienteCPF: json['clienteCPF'] as String?,
      clienteCNPJ: json['clienteCNPJ'] as String?,
      dataPrevisaoEntrega: parseOptionalDateTime(json['dataPrevisaoEntrega']),
      dataFinalizacao: parseOptionalDateTime(json['dataFinalizacao']),
      dataCancelamento: parseOptionalDateTime(json['dataCancelamento']),
      subtotal: parseDouble(json['subtotal']),
      descontoTotal: parseDouble(json['descontoTotal']),
      percentualDesconto: parseDouble(json['percentualDesconto']),
      acrescimoTotal: parseDouble(json['acrescimoTotal']),
      impostosTotal: parseDouble(json['impostosTotal']),
      freteTotal: parseDouble(json['freteTotal']),
      observacoes: json['observacoes'] as String?,
      motivoCancelamento: json['motivoCancelamento'] as String?,
      transacaoEstoqueId: json['transacaoEstoqueId']?.toString(),
      createdAt: parseOptionalDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      vendaId: vendaId,
    );
  }

  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson.addAll({
      'tipoContexto': tipoContexto,
      'contextoNome': contextoNome,
      'contextoDescricao': contextoDescricao,
      'clienteCPF': clienteCPF,
      'clienteCNPJ': clienteCNPJ,
      'dataPrevisaoEntrega': dataPrevisaoEntrega?.toIso8601String(),
      'dataFinalizacao': dataFinalizacao?.toIso8601String(),
      'dataCancelamento': dataCancelamento?.toIso8601String(),
      'subtotal': subtotal,
      'descontoTotal': descontoTotal,
      'percentualDesconto': percentualDesconto,
      'acrescimoTotal': acrescimoTotal,
      'impostosTotal': impostosTotal,
      'freteTotal': freteTotal,
      'observacoes': observacoes,
      'motivoCancelamento': motivoCancelamento,
      'transacaoEstoqueId': transacaoEstoqueId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'vendaId': vendaId,
    });
    return baseJson;
  }
}

