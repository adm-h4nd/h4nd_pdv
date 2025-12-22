import 'package:hive/hive.dart';

part 'produto_atributo_local.g.dart';

@HiveType(typeId: 1)
class ProdutoAtributoLocal {
  @HiveField(0)
  String id;

  @HiveField(1)
  String produtoId;

  @HiveField(2)
  String atributoId;

  @HiveField(3)
  String nome;

  @HiveField(4)
  String? descricao;

  @HiveField(5)
  bool permiteSelecaoProporcional;

  @HiveField(6)
  int ordem;

  @HiveField(7)
  List<ProdutoAtributoValorLocal> valores;

  ProdutoAtributoLocal({
    required this.id,
    required this.produtoId,
    required this.atributoId,
    required this.nome,
    this.descricao,
    required this.permiteSelecaoProporcional,
    required this.ordem,
    required this.valores,
  });
}

@HiveType(typeId: 2)
class ProdutoAtributoValorLocal {
  @HiveField(0)
  String id;

  @HiveField(1)
  String atributoValorId;

  @HiveField(2)
  String nome;

  @HiveField(3)
  String? descricao;

  @HiveField(4)
  int ordem;

  @HiveField(5)
  bool isActive;

  ProdutoAtributoValorLocal({
    required this.id,
    required this.atributoValorId,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.isActive,
  });
}

