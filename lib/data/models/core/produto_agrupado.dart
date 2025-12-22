import 'pedido_com_itens_pdv_dto.dart';

/// Modelo para agrupar produtos de múltiplos pedidos
class ProdutoAgrupado {
  final String produtoId;
  final String produtoNome;
  final String? produtoVariacaoId;
  final String? produtoVariacaoNome;
  final double precoUnitario; // Preço unitário (assumindo que seja o mesmo para todas as ocorrências)
  int quantidadeTotal; // Quantidade total somada de todos os pedidos
  double precoTotal; // Preço total (precoUnitario * quantidadeTotal)
  final List<ProdutoVariacaoAtributoValorDto> variacaoAtributosValores;

  ProdutoAgrupado({
    required this.produtoId,
    required this.produtoNome,
    this.produtoVariacaoId,
    this.produtoVariacaoNome,
    required this.precoUnitario,
    required this.quantidadeTotal,
    this.variacaoAtributosValores = const [],
  }) : precoTotal = precoUnitario * quantidadeTotal;

  /// Adiciona quantidade ao produto agrupado
  void adicionarQuantidade(int quantidade) {
    quantidadeTotal += quantidade;
    precoTotal = precoUnitario * quantidadeTotal;
  }

  /// Chave única para agrupamento (produtoId + variaçãoId se houver)
  String get chaveAgrupamento {
    if (produtoVariacaoId != null && produtoVariacaoId!.isNotEmpty) {
      return '$produtoId|$produtoVariacaoId';
    }
    return produtoId;
  }
}
