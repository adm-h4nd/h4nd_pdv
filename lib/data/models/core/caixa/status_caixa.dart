/// Enum para status do ciclo de caixa
enum StatusCaixa {
  aberto(1),
  fechado(2),
  cancelado(3);

  final int value;
  const StatusCaixa(this.value);

  static StatusCaixa? fromValue(int? value) {
    if (value == null) return null;
    return StatusCaixa.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StatusCaixa.aberto,
    );
  }

  String get displayName {
    switch (this) {
      case StatusCaixa.aberto:
        return 'Aberto';
      case StatusCaixa.fechado:
        return 'Fechado';
      case StatusCaixa.cancelado:
        return 'Cancelado';
    }
  }
}

