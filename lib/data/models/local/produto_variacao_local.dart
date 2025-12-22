import 'package:hive/hive.dart';
import '../core/produtos.dart';
import 'produto_composicao_local.dart';

part 'produto_variacao_local.g.dart';

@HiveType(typeId: 3)
class ProdutoVariacaoLocal {
  @HiveField(0)
  String id;

  @HiveField(1)
  String produtoId;

  @HiveField(2)
  String? nome;

  @HiveField(3)
  String nomeCompleto;

  @HiveField(4)
  String? descricao;

  @HiveField(5)
  double? precoVenda;

  @HiveField(6)
  double precoEfetivo;

  @HiveField(7)
  String? sku;

  @HiveField(8)
  int ordem;

  @HiveField(9)
  List<ProdutoVariacaoValorLocal> valores;

  @HiveField(10)
  int? tipoRepresentacaoVisual;

  @HiveField(11)
  String? icone;

  @HiveField(12)
  String? cor;

  @HiveField(13)
  String? imagemFileName;

  @HiveField(14)
  List<ProdutoComposicaoLocal> composicao;

  ProdutoVariacaoLocal({
    required this.id,
    required this.produtoId,
    this.nome,
    required this.nomeCompleto,
    this.descricao,
    this.precoVenda,
    required this.precoEfetivo,
    this.sku,
    required this.ordem,
    required this.valores,
    this.tipoRepresentacaoVisual,
    this.icone,
    this.cor,
    this.imagemFileName,
    required this.composicao,
  });

  TipoRepresentacaoVisual? get tipoRepresentacaoVisualEnum =>
      tipoRepresentacaoVisual != null
          ? TipoRepresentacaoVisual.fromValue(tipoRepresentacaoVisual)
          : null;
}

@HiveType(typeId: 4)
class ProdutoVariacaoValorLocal {
  @HiveField(0)
  String id;

  @HiveField(1)
  String produtoVariacaoId;

  @HiveField(2)
  String atributoValorId;

  @HiveField(3)
  String nomeAtributo;

  @HiveField(4)
  String nomeValor;

  ProdutoVariacaoValorLocal({
    required this.id,
    required this.produtoVariacaoId,
    required this.atributoValorId,
    required this.nomeAtributo,
    required this.nomeValor,
  });
}

