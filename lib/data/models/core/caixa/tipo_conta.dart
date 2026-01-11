/// Enum para tipo de conta bancária
enum TipoConta {
  bancaria(1),
  interna(2);

  final int value;
  const TipoConta(this.value);

  static TipoConta? fromValue(int? value) {
    if (value == null) return null;
    return TipoConta.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoConta.bancaria,
    );
  }

  String get displayName {
    switch (this) {
      case TipoConta.bancaria:
        return 'Bancária';
      case TipoConta.interna:
        return 'Interna';
    }
  }

  /// Verifica se é conta interna (cofre)
  bool get ehInterna => this == TipoConta.interna;
}

