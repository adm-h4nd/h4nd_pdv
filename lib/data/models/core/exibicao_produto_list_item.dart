import 'package:json_annotation/json_annotation.dart';
import 'produtos.dart';

part 'exibicao_produto_list_item.g.dart';

/// DTO para item de lista de Exibição de Produtos
@JsonSerializable()
class ExibicaoProdutoListItemDto {
  final String id;
  final String nome;
  final String? descricao;
  final int ordem;
  @JsonKey(fromJson: _tipoRepresentacaoFromJson, toJson: _tipoRepresentacaoToJson)
  final TipoRepresentacaoVisual tipoRepresentacao;
  final String? icone;
  final String? cor;
  final String? imagemFileName;
  final bool isAtiva;
  final String? categoriaPaiId;
  final int quantidadeCategoriasFilhas;
  final int quantidadeProdutos;

  ExibicaoProdutoListItemDto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.tipoRepresentacao,
    this.icone,
    this.cor,
    this.imagemFileName,
    required this.isAtiva,
    this.categoriaPaiId,
    required this.quantidadeCategoriasFilhas,
    required this.quantidadeProdutos,
  });

  factory ExibicaoProdutoListItemDto.fromJson(Map<String, dynamic> json) =>
      _$ExibicaoProdutoListItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ExibicaoProdutoListItemDtoToJson(this);

  static TipoRepresentacaoVisual _tipoRepresentacaoFromJson(dynamic value) {
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

