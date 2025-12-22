/// Item de lista de pedido
class PedidoListItemDto {
  final String id;
  final String numero;
  final String tipo; // Orcamento, Venda
  final String status; // Aberto, Finalizado, Cancelado, etc.
  final String? mesaId;
  final String? mesaNumero;
  final String? comandaId;
  final String? comandaNumero;
  final String? clienteId;
  final String clienteNome;
  final String? vendedorId;
  final String? vendedorNome;
  final DateTime dataPedido;
  final double valorTotal;
  final bool isActive;

  PedidoListItemDto({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.status,
    this.mesaId,
    this.mesaNumero,
    this.comandaId,
    this.comandaNumero,
    this.clienteId,
    required this.clienteNome,
    this.vendedorId,
    this.vendedorNome,
    required this.dataPedido,
    required this.valorTotal,
    required this.isActive,
  });

  factory PedidoListItemDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final numero = json['numero']?.toString() ?? '';

    // TipoPedido: 1=Orcamento, 2=Venda
    final tipoValue = json['tipo'];
    String tipo = 'Orcamento';
    if (tipoValue is int) {
      tipo = tipoValue == 1 ? 'Orcamento' : 'Venda';
    } else if (tipoValue is String) {
      tipo = tipoValue;
    }

    // StatusPedido: 1=Aberto, 2=AguardandoPagamento, 3=Pago, 4=EmPreparacao, 5=Pronto, 6=EmEntrega, 7=Entregue, 8=Finalizado, 9=Cancelado
    final statusValue = json['status'];
    String status = 'Aberto';
    if (statusValue is int) {
      switch (statusValue) {
        case 1:
          status = 'Aberto';
          break;
        case 2:
          status = 'AguardandoPagamento';
          break;
        case 3:
          status = 'Pago';
          break;
        case 4:
          status = 'EmPreparacao';
          break;
        case 5:
          status = 'Pronto';
          break;
        case 6:
          status = 'EmEntrega';
          break;
        case 7:
          status = 'Entregue';
          break;
        case 8:
          status = 'Finalizado';
          break;
        case 9:
          status = 'Cancelado';
          break;
        default:
          status = 'Aberto';
      }
    } else if (statusValue is String) {
      status = statusValue;
    }

    final mesaIdValue = json['mesaId'];
    final mesaId = mesaIdValue?.toString();

    final comandaIdValue = json['comandaId'];
    final comandaId = comandaIdValue?.toString();

    final clienteIdValue = json['clienteId'];
    final clienteId = clienteIdValue?.toString();

    final vendedorIdValue = json['vendedorId'];
    final vendedorId = vendedorIdValue?.toString();

    final dataPedidoValue = json['dataPedido'];
    DateTime dataPedido;
    if (dataPedidoValue is String) {
      dataPedido = DateTime.parse(dataPedidoValue);
    } else if (dataPedidoValue is DateTime) {
      dataPedido = dataPedidoValue;
    } else {
      dataPedido = DateTime.now();
    }

    final valorTotal = json['valorTotal'] is num
        ? (json['valorTotal'] as num).toDouble()
        : double.tryParse(json['valorTotal']?.toString() ?? '0') ?? 0.0;

    final isActive = json['isActive'] is bool 
        ? json['isActive'] as bool 
        : (json['isActive']?.toString().toLowerCase() == 'true');

    return PedidoListItemDto(
      id: id,
      numero: numero,
      tipo: tipo,
      status: status,
      mesaId: mesaId,
      mesaNumero: json['mesaNumero'] as String?,
      comandaId: comandaId,
      comandaNumero: json['comandaNumero'] as String?,
      clienteId: clienteId,
      clienteNome: json['clienteNome']?.toString() ?? '',
      vendedorId: vendedorId,
      vendedorNome: json['vendedorNome'] as String?,
      dataPedido: dataPedido,
      valorTotal: valorTotal,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'tipo': tipo,
      'status': status,
      'mesaId': mesaId,
      'mesaNumero': mesaNumero,
      'comandaId': comandaId,
      'comandaNumero': comandaNumero,
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'vendedorId': vendedorId,
      'vendedorNome': vendedorNome,
      'dataPedido': dataPedido.toIso8601String(),
      'valorTotal': valorTotal,
      'isActive': isActive,
    };
  }
}
