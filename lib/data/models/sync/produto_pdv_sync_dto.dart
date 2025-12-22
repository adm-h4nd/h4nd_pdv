import 'package:json_annotation/json_annotation.dart';
import '../core/produtos.dart';

part 'produto_pdv_sync_dto.g.dart';

/// DTO de sincronização de produto do backend
@JsonSerializable()
class ProdutoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String nome;
  final String? descricao;
  final String? sku;
  final String? referencia;
  @JsonKey(fromJson: _tipoFromJson)
  final String tipo; // TipoProduto enum
  @JsonKey(fromJson: _decimalToDouble)
  final double? precoVenda;
  final bool isControlaEstoque;
  final bool isControlaEstoquePorVariacao;
  final String unidadeBase;
  
  // Classificação
  @JsonKey(fromJson: _idFromJsonNullable)
  final String? grupoId;
  final String? grupoNome;
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJsonNullable)
  final TipoRepresentacaoVisual? grupoTipoRepresentacao;
  final String? grupoIcone;
  final String? grupoCor;
  final String? grupoImagemFileName;
  
  @JsonKey(fromJson: _idFromJsonNullable)
  final String? subgrupoId;
  final String? subgrupoNome;
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJsonNullable)
  final TipoRepresentacaoVisual? subgrupoTipoRepresentacao;
  final String? subgrupoIcone;
  final String? subgrupoCor;
  final String? subgrupoImagemFileName;
  
  // Representação visual
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJson)
  final TipoRepresentacaoVisual tipoRepresentacao;
  final String? icone;
  final String? cor;
  final String? imagemFileName;
  
  // Atributos e variações
  final List<ProdutoAtributoPdvSyncDto> atributos;
  final List<ProdutoVariacaoPdvSyncDto> variacoes;
  
  // Composição (itens removíveis)
  final List<ProdutoComposicaoPdvSyncDto> composicao;
  
  // Flags
  final bool isAtivo;
  final bool isVendavel;
  final bool temVariacoes;

  ProdutoPdvSyncDto({
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
    required this.composicao,
    required this.isAtivo,
    required this.isVendavel,
    required this.temVariacoes,
  });

  factory ProdutoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _idFromJsonNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static String _tipoFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  static double? _decimalToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static TipoRepresentacaoVisual _tipoRepresentacaoFromJson(dynamic value) {
    if (value == null) return TipoRepresentacaoVisual.icon;
    if (value is int) {
      return TipoRepresentacaoVisual.fromValue(value) ?? TipoRepresentacaoVisual.icon;
    }
    if (value is String) {
      return TipoRepresentacaoVisual.fromString(value) ?? TipoRepresentacaoVisual.icon;
    }
    return TipoRepresentacaoVisual.icon;
  }

  static int _tipoRepresentacaoToJson(TipoRepresentacaoVisual value) => value.value;
  
  static int? _tipoRepresentacaoToJsonNullable(TipoRepresentacaoVisual? value) => value?.value;
}

@JsonSerializable()
class ProdutoAtributoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoId;
  @JsonKey(fromJson: _idFromJson)
  final String atributoId;
  final String nome;
  final String? descricao;
  final bool permiteSelecaoProporcional;
  final int ordem;
  final List<ProdutoAtributoValorPdvSyncDto> valores;

  ProdutoAtributoPdvSyncDto({
    required this.id,
    required this.produtoId,
    required this.atributoId,
    required this.nome,
    this.descricao,
    required this.permiteSelecaoProporcional,
    required this.ordem,
    required this.valores,
  });

  factory ProdutoAtributoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoAtributoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoAtributoPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

@JsonSerializable()
class ProdutoAtributoValorPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String atributoValorId;
  final String nome;
  final String? descricao;
  final int ordem;
  final bool isActive;

  ProdutoAtributoValorPdvSyncDto({
    required this.id,
    required this.atributoValorId,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.isActive,
  });

  factory ProdutoAtributoValorPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoAtributoValorPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoAtributoValorPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

@JsonSerializable()
class ProdutoVariacaoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoId;
  final String? nome;
  final String nomeCompleto;
  final String? descricao;
  @JsonKey(fromJson: _decimalToDouble)
  final double? precoVenda;
  @JsonKey(fromJson: _decimalToDoubleRequired)
  final double precoEfetivo;
  final String? sku;
  final int ordem;
  final List<ProdutoVariacaoValorPdvSyncDto> valores;
  @JsonKey(fromJson: _tipoRepresentacaoFromJsonNullable, toJson: _tipoRepresentacaoToJsonNullable)
  final TipoRepresentacaoVisual? tipoRepresentacaoVisual;
  final String? icone;
  final String? cor;
  final String? imagemFileName;
  
  // Composição (itens removíveis)
  final List<ProdutoComposicaoPdvSyncDto> composicao;

  ProdutoVariacaoPdvSyncDto({
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

  factory ProdutoVariacaoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoVariacaoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoVariacaoPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double? _decimalToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double _decimalToDoubleRequired(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static TipoRepresentacaoVisual? _tipoRepresentacaoFromJsonNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return TipoRepresentacaoVisual.fromValue(value);
    }
    if (value is String) {
      return TipoRepresentacaoVisual.fromString(value);
    }
    return null;
  }

  static int? _tipoRepresentacaoToJsonNullable(TipoRepresentacaoVisual? value) => value?.value;
}

@JsonSerializable()
class ProdutoVariacaoValorPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoVariacaoId;
  @JsonKey(fromJson: _idFromJson)
  final String atributoValorId;
  final String nomeAtributo;
  final String nomeValor;

  ProdutoVariacaoValorPdvSyncDto({
    required this.id,
    required this.produtoVariacaoId,
    required this.atributoValorId,
    required this.nomeAtributo,
    required this.nomeValor,
  });

  factory ProdutoVariacaoValorPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoVariacaoValorPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoVariacaoValorPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

@JsonSerializable()
class ProdutoComposicaoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String componenteId;
  final String componenteNome;
  final bool isRemovivel;
  final int ordem;

  ProdutoComposicaoPdvSyncDto({
    required this.componenteId,
    required this.componenteNome,
    required this.isRemovivel,
    required this.ordem,
  });

  factory ProdutoComposicaoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoComposicaoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoComposicaoPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

