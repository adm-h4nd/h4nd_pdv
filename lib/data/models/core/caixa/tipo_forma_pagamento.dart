/// Enum de tipos de forma de pagamento
/// 
/// Valores correspondem ao enum do backend (MXCloud.Domain.Enums.TipoFormaPagamento)
enum TipoFormaPagamento {
  dinheiro(1),
  cartaoCredito(2),
  cartaoDebito(3),
  pix(4),
  boleto(5),
  cheque(6),
  valeRefeicao(7),
  valeAlimentacao(8),
  outro(99);

  final int value;
  const TipoFormaPagamento(this.value);

  /// Converte de int para enum
  static TipoFormaPagamento? fromValue(int? value) {
    if (value == null) return null;
    return TipoFormaPagamento.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoFormaPagamento.outro,
    );
  }

  /// Converte de enum para int
  int toValue() => value;
}

