/// Tipo de entidade para filtro de pedidos
enum TipoEntidade {
  mesa,
  comanda,
}

/// Informações básicas de uma mesa ou comanda no restaurante
class MesaComandaInfo {
  final String id;
  final String numero;
  final String? descricao;
  final String status;
  final TipoEntidade tipo;
  final String? codigoBarras; // Apenas para comanda

  MesaComandaInfo({
    required this.id,
    required this.numero,
    this.descricao,
    required this.status,
    required this.tipo,
    this.codigoBarras,
  });
}
