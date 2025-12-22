import 'pedido_com_itens_pdv_dto.dart';
import '../modules/restaurante/comanda_list_item.dart';
import '../core/vendas/venda_dto.dart';

/// DTO para resposta completa de pedidos por mesa (inclui pedidos, venda e comandas)
class PedidosComVendaComandasDto {
  final List<PedidoComItensPdvDto> pedidos;
  final VendaDto? venda;
  final List<ComandaListItemDto>? comandas;

  PedidosComVendaComandasDto({
    required this.pedidos,
    this.venda,
    this.comandas,
  });

  factory PedidosComVendaComandasDto.fromJson(Map<String, dynamic> json) {
    // Processa pedidos
    final pedidosData = json['pedidos'] as List<dynamic>? ?? [];
    final pedidos = pedidosData
        .map((item) => PedidoComItensPdvDto.fromJson(item as Map<String, dynamic>))
        .toList();

    // Processa venda (se existir)
    VendaDto? venda;
    if (json['venda'] != null) {
      venda = VendaDto.fromJson(json['venda'] as Map<String, dynamic>);
    }

    // Processa comandas (se existirem)
    List<ComandaListItemDto>? comandas;
    if (json['comandas'] != null) {
      final comandasData = json['comandas'] as List<dynamic>;
      comandas = comandasData
          .map((item) => ComandaListItemDto.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return PedidosComVendaComandasDto(
      pedidos: pedidos,
      venda: venda,
      comandas: comandas,
    );
  }
}

