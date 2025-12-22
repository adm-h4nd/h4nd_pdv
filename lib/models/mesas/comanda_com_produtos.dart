import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/models/core/vendas/venda_dto.dart';

/// Dados de uma comanda com seus produtos
class ComandaComProdutos {
  final ComandaListItemDto comanda;
  final List<ProdutoAgrupado> produtos;
  final VendaDto? venda;

  ComandaComProdutos({
    required this.comanda,
    required this.produtos,
    this.venda,
  });
}
