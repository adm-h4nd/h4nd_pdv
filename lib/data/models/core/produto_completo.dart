import 'package:json_annotation/json_annotation.dart';
import 'produtos.dart';

part 'produto_completo.g.dart';

/// DTO completo de produto com atributos e variações
@JsonSerializable()
class ProdutoCompletoDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String nome;
  final String? descricao;
  final String? sku;
  final String? referencia;
  @JsonKey(fromJson: _tipoFromJson, toJson: _tipoToJson)
  final String tipo; // TipoProduto enum
  final double? precoVenda;
  final double? precoCusto;
  final bool isControlaEstoque;
  final bool isControlaEstoquePorVariacao;
  final String unidadeBase;
  final bool temVariacoes;
  final bool temComposicao;
  
  // Representação visual
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJson)
  final TipoRepresentacaoVisual tipoRepresentacao;
  final String? icone;
  final String? cor;
  final String? imagemFileName;
  
  // Listas relacionadas
  final List<ProdutoAtributoDto> atributos;
  final List<ProdutoVariacaoDto> variacoes;
  
  ProdutoCompletoDto({
    required this.id,
    required this.nome,
    this.descricao,
    this.sku,
    this.referencia,
    required this.tipo,
    this.precoVenda,
    this.precoCusto,
    required this.isControlaEstoque,
    required this.isControlaEstoquePorVariacao,
    required this.unidadeBase,
    required this.temVariacoes,
    required this.temComposicao,
    required this.tipoRepresentacao,
    this.icone,
    this.cor,
    this.imagemFileName,
    required this.atributos,
    required this.variacoes,
  });

  factory ProdutoCompletoDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoCompletoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoCompletoDtoToJson(this);

  // Conversores customizados
  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String _tipoFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  static String _tipoToJson(String value) => value;

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
}

/// DTO para atributo de produto
@JsonSerializable()
class ProdutoAtributoDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoId;
  final String nome;
  final String? descricao;
  final int ordem;
  final bool permiteSelecaoProporcional;
  @JsonKey(fromJson: _idFromJson)
  final String atributoId;
  final int totalValores;
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<AtributoValorDto>? valores; // Valores disponíveis deste atributo (carregados separadamente)

  ProdutoAtributoDto({
    required this.id,
    required this.produtoId,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.permiteSelecaoProporcional,
    required this.atributoId,
    required this.totalValores,
    this.valores,
  });

  factory ProdutoAtributoDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoAtributoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoAtributoDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

/// DTO para valor de atributo
@JsonSerializable()
class AtributoValorDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String nome;
  final String? descricao;
  final int ordem;
  final bool isActive;

  AtributoValorDto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.isActive,
  });

  factory AtributoValorDto.fromJson(Map<String, dynamic> json) =>
      _$AtributoValorDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AtributoValorDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

/// DTO para variação de produto
@JsonSerializable()
class ProdutoVariacaoDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoId;
  final String? nome;
  final String nomeCompleto;
  final String? descricao;
  final double? precoVenda;
  final double precoEfetivo;
  final double? precoCusto;
  final String? sku;
  final String? ean;
  final int ordem;
  final List<ProdutoVariacaoValorDto> valores;
  final bool usaGrade;
  @JsonKey(fromJson: _tipoRepresentacaoVisualFromJson, toJson: _tipoRepresentacaoVisualToJson)
  final TipoRepresentacaoVisual? tipoRepresentacaoVisual;
  final String? icone;
  final String? cor;
  final String? imagemFileName;

  ProdutoVariacaoDto({
    required this.id,
    required this.produtoId,
    this.nome,
    required this.nomeCompleto,
    this.descricao,
    this.precoVenda,
    required this.precoEfetivo,
    this.precoCusto,
    this.sku,
    this.ean,
    required this.ordem,
    required this.valores,
    required this.usaGrade,
    this.tipoRepresentacaoVisual,
    this.icone,
    this.cor,
    this.imagemFileName,
  });

  factory ProdutoVariacaoDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoVariacaoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoVariacaoDtoToJson(this);

  // Conversor customizado para tipoRepresentacaoVisual
  static TipoRepresentacaoVisual? _tipoRepresentacaoVisualFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return TipoRepresentacaoVisual.fromValue(value);
    }
    if (value is String) {
      return TipoRepresentacaoVisual.fromString(value);
    }
    return null;
  }

  static int? _tipoRepresentacaoVisualToJson(TipoRepresentacaoVisual? value) => value?.value;

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

/// DTO para valor de variação (ligação entre variação e valor de atributo)
@JsonSerializable()
class ProdutoVariacaoValorDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(fromJson: _idFromJson)
  final String produtoVariacaoId;
  @JsonKey(fromJson: _idFromJson)
  final String atributoValorId;
  final String nomeAtributo;
  final String nomeValor;

  ProdutoVariacaoValorDto({
    required this.id,
    required this.produtoVariacaoId,
    required this.atributoValorId,
    required this.nomeAtributo,
    required this.nomeValor,
  });

  factory ProdutoVariacaoValorDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoVariacaoValorDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoVariacaoValorDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

