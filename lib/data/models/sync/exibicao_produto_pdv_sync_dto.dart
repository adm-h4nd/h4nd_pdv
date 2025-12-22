import 'package:json_annotation/json_annotation.dart';
import '../core/produtos.dart';

part 'exibicao_produto_pdv_sync_dto.g.dart';

/// DTO de sincronização de grupo de exibição do backend
@JsonSerializable()
class ExibicaoProdutoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String nome;
  final String? descricao;
  @JsonKey(fromJson: _idFromJsonNullable)
  final String? categoriaPaiId;
  final int ordem;
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJson)
  final TipoRepresentacaoVisual tipoRepresentacao;
  final String? icone;
  final String? cor;
  final String? imagemFileName;
  final bool isAtiva;
  final List<ExibicaoProdutoPdvSyncDto> categoriasFilhas;
  final List<ProdutoExibicaoPdvSyncDto> produtos;

  ExibicaoProdutoPdvSyncDto({
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
    required this.categoriasFilhas,
    required this.produtos,
  });

  factory ExibicaoProdutoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ExibicaoProdutoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ExibicaoProdutoPdvSyncDtoToJson(this);

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

@JsonSerializable()
class ProdutoExibicaoPdvSyncDto {
  @JsonKey(fromJson: _idFromJson)
  final String produtoId;
  final int ordem;

  ProdutoExibicaoPdvSyncDto({
    required this.produtoId,
    required this.ordem,
  });

  factory ProdutoExibicaoPdvSyncDto.fromJson(Map<String, dynamic> json) =>
      _$ProdutoExibicaoPdvSyncDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProdutoExibicaoPdvSyncDtoToJson(this);

  static String _idFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

