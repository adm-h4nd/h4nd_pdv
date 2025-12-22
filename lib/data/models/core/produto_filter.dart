/// Filtros para busca de produtos
class ProdutoFilterDto {
  final String? nome;
  final String? sku;
  final String? referencia;
  final String? tipo;
  final String? grupoId;
  final String? subgrupoId;
  final bool? isVendavel;
  final bool? isActive;
  final String? searchTerm; // Busca geral

  ProdutoFilterDto({
    this.nome,
    this.sku,
    this.referencia,
    this.tipo,
    this.grupoId,
    this.subgrupoId,
    this.isVendavel,
    this.isActive,
    this.searchTerm,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (nome != null && nome!.isNotEmpty) map['nome'] = nome;
    if (sku != null && sku!.isNotEmpty) map['sku'] = sku;
    if (referencia != null && referencia!.isNotEmpty) map['referencia'] = referencia;
    if (tipo != null && tipo!.isNotEmpty) map['tipo'] = tipo;
    if (grupoId != null && grupoId!.isNotEmpty) map['grupoId'] = grupoId;
    if (subgrupoId != null && subgrupoId!.isNotEmpty) map['subgrupoId'] = subgrupoId;
    if (isVendavel != null) map['isVendavel'] = isVendavel;
    if (isActive != null) map['isActive'] = isActive;
    if (searchTerm != null && searchTerm!.isNotEmpty) {
      map['searchTerm'] = searchTerm;
    }
    return map;
  }
}
