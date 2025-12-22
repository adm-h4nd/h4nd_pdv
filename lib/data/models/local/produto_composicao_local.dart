import 'package:hive/hive.dart';

part 'produto_composicao_local.g.dart';

@HiveType(typeId: 5)
class ProdutoComposicaoLocal {
  @HiveField(0)
  String componenteId;

  @HiveField(1)
  String componenteNome;

  @HiveField(2)
  bool isRemovivel;

  @HiveField(3)
  int ordem;

  ProdutoComposicaoLocal({
    required this.componenteId,
    required this.componenteNome,
    required this.isRemovivel,
    required this.ordem,
  });
}

