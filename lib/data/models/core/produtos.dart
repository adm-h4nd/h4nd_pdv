/// Enum para tipo de representação visual
enum TipoRepresentacaoVisual {
  icon(1),
  imagem(2);

  final int value;
  const TipoRepresentacaoVisual(this.value);

  static TipoRepresentacaoVisual? fromValue(int? value) {
    if (value == null) return null;
    return TipoRepresentacaoVisual.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoRepresentacaoVisual.icon,
    );
  }

  static TipoRepresentacaoVisual? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'icone':
      case 'icon':
        return TipoRepresentacaoVisual.icon;
      case 'imagem':
      case 'imagem':
        return TipoRepresentacaoVisual.imagem;
      default:
        return TipoRepresentacaoVisual.icon;
    }
  }
}

