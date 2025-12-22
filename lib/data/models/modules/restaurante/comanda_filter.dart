/// Filtro para busca de comandas
class ComandaFilterDto {
  final String? search;
  final int? status; // 1=Ativa, 2=Encerrada, 3=Cancelada
  final bool? ativa;

  ComandaFilterDto({
    this.search,
    this.status,
    this.ativa,
  });

  Map<String, dynamic> toJson() {
    return {
      if (search != null && search!.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
      if (ativa != null) 'isAtiva': ativa,
    };
  }
}
