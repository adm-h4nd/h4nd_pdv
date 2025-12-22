import 'package:hive/hive.dart';
import '../core/produtos.dart';
import 'produto_atributo_local.dart';
import 'produto_variacao_local.dart';
import 'produto_composicao_local.dart';

part 'produto_local.g.dart';

@HiveType(typeId: 0)
class ProdutoLocal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nome;

  @HiveField(2)
  String? descricao;

  @HiveField(3)
  String? sku;

  @HiveField(4)
  String? referencia;

  @HiveField(5)
  String tipo;

  @HiveField(6)
  double? precoVenda;

  @HiveField(7)
  bool isControlaEstoque;

  @HiveField(8)
  bool isControlaEstoquePorVariacao;

  @HiveField(9)
  String unidadeBase;

  @HiveField(10)
  String? grupoId;

  @HiveField(11)
  String? grupoNome;

  @HiveField(12)
  int? grupoTipoRepresentacao;

  @HiveField(13)
  String? grupoIcone;

  @HiveField(14)
  String? grupoCor;

  @HiveField(15)
  String? grupoImagemFileName;

  @HiveField(16)
  String? subgrupoId;

  @HiveField(17)
  String? subgrupoNome;

  @HiveField(18)
  int? subgrupoTipoRepresentacao;

  @HiveField(19)
  String? subgrupoIcone;

  @HiveField(20)
  String? subgrupoCor;

  @HiveField(21)
  String? subgrupoImagemFileName;

  @HiveField(22)
  int tipoRepresentacao;

  @HiveField(23)
  String? icone;

  @HiveField(24)
  String? cor;

  @HiveField(25)
  String? imagemFileName;

  @HiveField(26)
  List<ProdutoAtributoLocal> atributos;

  @HiveField(27)
  List<ProdutoVariacaoLocal> variacoes;

  @HiveField(28)
  bool isAtivo;

  @HiveField(29)
  bool isVendavel;

  @HiveField(30)
  bool temVariacoes;

  @HiveField(31)
  DateTime ultimaSincronizacao;

  @HiveField(32)
  List<ProdutoComposicaoLocal> composicao;

  ProdutoLocal({
    required this.id,
    required this.nome,
    this.descricao,
    this.sku,
    this.referencia,
    required this.tipo,
    this.precoVenda,
    required this.isControlaEstoque,
    required this.isControlaEstoquePorVariacao,
    required this.unidadeBase,
    this.grupoId,
    this.grupoNome,
    this.grupoTipoRepresentacao,
    this.grupoIcone,
    this.grupoCor,
    this.grupoImagemFileName,
    this.subgrupoId,
    this.subgrupoNome,
    this.subgrupoTipoRepresentacao,
    this.subgrupoIcone,
    this.subgrupoCor,
    this.subgrupoImagemFileName,
    required this.tipoRepresentacao,
    this.icone,
    this.cor,
    this.imagemFileName,
    required this.atributos,
    required this.variacoes,
    required this.isAtivo,
    required this.isVendavel,
    required this.temVariacoes,
    required this.ultimaSincronizacao,
    required this.composicao,
  });

  // Getters para conversão de tipos
  TipoRepresentacaoVisual get tipoRepresentacaoEnum =>
      TipoRepresentacaoVisual.fromValue(tipoRepresentacao) ?? TipoRepresentacaoVisual.icon;

  TipoRepresentacaoVisual? get grupoTipoRepresentacaoEnum =>
      grupoTipoRepresentacao != null
          ? TipoRepresentacaoVisual.fromValue(grupoTipoRepresentacao)
          : null;

  TipoRepresentacaoVisual? get subgrupoTipoRepresentacaoEnum =>
      subgrupoTipoRepresentacao != null
          ? TipoRepresentacaoVisual.fromValue(subgrupoTipoRepresentacao)
          : null;
}

