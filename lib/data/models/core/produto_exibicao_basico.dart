import 'package:json_annotation/json_annotation.dart';
import 'produtos.dart';

part 'produto_exibicao_basico.g.dart';

/// DTO básico para produto vinculado a uma categoria de exibição
@JsonSerializable()
class ProdutoExibicaoBasicoDto {
  final String produtoId;
  final String produtoNome;
  final String? produtoSKU;
  final double? produtoPrecoVenda;
  final String? produtoImagemFileName;
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJson)
  final TipoRepresentacaoVisual? produtoTipoRepresentacao;
  final String? produtoIcone;
  final String? produtoCor;
  final int ordem;

  ProdutoExibicaoBasicoDto({
    required this.produtoId,
    required this.produtoNome,
    this.produtoSKU,
    this.produtoPrecoVenda,
    this.produtoImagemFileName,
    this.produtoTipoRepresentacao,
    this.produtoIcone,
    this.produtoCor,
    required this.ordem,
  });

  factory ProdutoExibicaoBasicoDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoExibicaoBasicoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoExibicaoBasicoDtoToJson(this);

  static TipoRepresentacaoVisual? _tipoRepresentacaoFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return TipoRepresentacaoVisual.fromValue(value);
    }
    if (value is String) {
      return TipoRepresentacaoVisual.fromString(value);
    }
    return null;
  }

  static int? _tipoRepresentacaoToJson(TipoRepresentacaoVisual? value) => value?.value;
}

