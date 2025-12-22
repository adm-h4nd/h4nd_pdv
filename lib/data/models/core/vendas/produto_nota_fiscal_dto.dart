/// DTO para produto a ser incluído em uma nota fiscal
/// O backend busca os dados fiscais diretamente dos ItemPedido e resolve quais usar (FIFO)
/// A nota fiscal trabalha com produtos, não com itens específicos do pedido
class ProdutoNotaFiscalDto {
  /// ID do produto
  final String produtoId;

  /// Quantidade a incluir na nota fiscal.
  /// O backend resolve quais ItemPedido usar (FIFO) para essa quantidade.
  final double quantidade;

  ProdutoNotaFiscalDto({
    required this.produtoId,
    required this.quantidade,
  });

  /// Cria a partir de JSON
  factory ProdutoNotaFiscalDto.fromJson(Map<String, dynamic> json) {
    final produtoIdValue = json['produtoId'];
    final produtoId = produtoIdValue is String 
        ? produtoIdValue 
        : produtoIdValue?.toString() ?? '';

    final quantidadeValue = json['quantidade'];
    final quantidade = quantidadeValue is num 
        ? quantidadeValue.toDouble() 
        : (quantidadeValue != null ? double.tryParse(quantidadeValue.toString()) ?? 0.0 : 0.0);

    return ProdutoNotaFiscalDto(
      produtoId: produtoId,
      quantidade: quantidade,
    );
  }

  /// Converte para JSON (usado no payload da API)
  Map<String, dynamic> toJson() {
    return {
      'produtoId': produtoId,
      'quantidade': quantidade,
    };
  }
}
