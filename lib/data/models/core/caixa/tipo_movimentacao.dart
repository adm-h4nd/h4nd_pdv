/// Enum de tipos de movimentação
/// 
/// Valores correspondem ao enum do backend (MXCloud.Domain.Enums.TipoMovimentacao)
enum TipoMovimentacao {
  entrada(1),
  saida(2);

  final int value;
  const TipoMovimentacao(this.value);

  /// Converte de int para enum
  static TipoMovimentacao? fromValue(int? value) {
    if (value == null) return null;
    return TipoMovimentacao.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoMovimentacao.entrada,
    );
  }

  /// Converte de enum para int
  int toValue() => value;
}

