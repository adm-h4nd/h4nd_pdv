import 'package:hive/hive.dart';
import '../core/produtos.dart';

part 'exibicao_produto_local.g.dart';

@HiveType(typeId: 10)
class ExibicaoProdutoLocal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nome;

  @HiveField(2)
  String? descricao;

  @HiveField(3)
  String? categoriaPaiId;

  @HiveField(4)
  int ordem;

  @HiveField(5)
  int tipoRepresentacao;

  @HiveField(6)
  String? icone;

  @HiveField(7)
  String? cor;

  @HiveField(8)
  String? imagemFileName;

  @HiveField(9)
  bool isAtiva;

  @HiveField(10)
  List<String> produtoIds; // IDs dos produtos vinculados (ordenados)

  @HiveField(11)
  List<ExibicaoProdutoLocal> categoriasFilhas; // Hierarquia

  @HiveField(12)
  DateTime ultimaSincronizacao;

  ExibicaoProdutoLocal({
    required this.id,
    required this.nome,
    this.descricao,
    this.categoriaPaiId,
    required this.ordem,
    required this.tipoRepresentacao,
    this.icone,
    this.cor,
    this.imagemFileName,
    required this.isAtiva,
    required this.produtoIds,
    required this.categoriasFilhas,
    required this.ultimaSincronizacao,
  });

  TipoRepresentacaoVisual get tipoRepresentacaoEnum =>
      TipoRepresentacaoVisual.fromValue(tipoRepresentacao) ?? TipoRepresentacaoVisual.icon;
}

