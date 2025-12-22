/// Filtros para busca de mesas
class MesaFilterDto {
  final String? numero; // Identificação da mesa (pode ser número ou texto)
  final String? status; // Livre, Ocupada, Reservada, Suspensa
  final bool? ativa;
  final bool? permiteReserva;
  final String? layoutId;
  final String? searchTerm; // Busca geral

  MesaFilterDto({
    this.numero,
    this.status,
    this.ativa,
    this.permiteReserva,
    this.layoutId,
    this.searchTerm,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (numero != null && numero!.isNotEmpty) map['numero'] = numero;
    if (status != null) map['status'] = status;
    if (ativa != null) map['ativa'] = ativa;
    if (permiteReserva != null) map['permiteReserva'] = permiteReserva;
    if (layoutId != null) map['layoutId'] = layoutId;
    if (searchTerm != null && searchTerm!.isNotEmpty) {
      map['searchTerm'] = searchTerm;
    }
    return map;
  }
}

