import 'package:hive/hive.dart';

part 'item_pedido_local.g.dart';

/// Modelo local para item do pedido com todas as informações necessárias
@HiveType(typeId: 6)
class ItemPedidoLocal {
  @HiveField(0)
  String id; // ID único do item no pedido local

  @HiveField(1)
  String produtoId;

  @HiveField(2)
  String produtoNome;

  @HiveField(3)
  String? produtoVariacaoId;

  @HiveField(4)
  String? produtoVariacaoNome;

  @HiveField(5)
  double precoUnitario;

  @HiveField(6)
  int quantidade;

  @HiveField(7)
  String? observacoes;

  @HiveField(8)
  Map<String, double>? proporcoesAtributos; // Map<valorId, proporcao> para atributos proporcionais

  @HiveField(9)
  List<String> componentesRemovidos; // Lista de IDs dos componentes removidos da composição

  @HiveField(12)
  Map<String, List<String>>? valoresAtributosSelecionados; // Map<atributoId, List<valorId>> - valores selecionados para cada atributo

  @HiveField(11)
  String? syncStatus; // status de sync opcional por item (placeholder se precisar granular)

  @HiveField(10)
  DateTime dataAdicao;

  ItemPedidoLocal({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    this.produtoVariacaoId,
    this.produtoVariacaoNome,
    required this.precoUnitario,
    required this.quantidade,
    this.observacoes,
    this.proporcoesAtributos,
    this.componentesRemovidos = const [],
    this.valoresAtributosSelecionados,
    this.syncStatus,
    DateTime? dataAdicao,
  }) : dataAdicao = dataAdicao ?? DateTime.now();

  /// Calcula o preço total do item (preço unitário * quantidade)
  double get precoTotal => precoUnitario * quantidade;

  /// Retorna uma descrição resumida do item
  String get descricaoResumida {
    final parts = <String>[];
    if (produtoVariacaoNome != null) {
      parts.add(produtoVariacaoNome!);
    } else {
      parts.add(produtoNome);
    }
    if (componentesRemovidos.isNotEmpty) {
      parts.add('(${componentesRemovidos.length} removido${componentesRemovidos.length == 1 ? '' : 's'})');
    }
    if (observacoes != null && observacoes!.isNotEmpty) {
      parts.add('Obs');
    }
    return parts.join(' • ');
  }
}

