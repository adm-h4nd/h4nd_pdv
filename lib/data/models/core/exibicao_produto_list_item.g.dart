// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exibicao_produto_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExibicaoProdutoListItemDto _$ExibicaoProdutoListItemDtoFromJson(
        Map<String, dynamic> json) =>
    ExibicaoProdutoListItemDto(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      tipoRepresentacao: ExibicaoProdutoListItemDto._tipoRepresentacaoFromJson(
          json['tipoRepresentacao']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
      isAtiva: json['isAtiva'] as bool,
      categoriaPaiId: json['categoriaPaiId'] as String?,
      quantidadeCategoriasFilhas:
          (json['quantidadeCategoriasFilhas'] as num).toInt(),
      quantidadeProdutos: (json['quantidadeProdutos'] as num).toInt(),
    );

Map<String, dynamic> _$ExibicaoProdutoListItemDtoToJson(
        ExibicaoProdutoListItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'ordem': instance.ordem,
      'tipoRepresentacao': ExibicaoProdutoListItemDto._tipoRepresentacaoToJson(
          instance.tipoRepresentacao),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
      'isAtiva': instance.isAtiva,
      'categoriaPaiId': instance.categoriaPaiId,
      'quantidadeCategoriasFilhas': instance.quantidadeCategoriasFilhas,
      'quantidadeProdutos': instance.quantidadeProdutos,
    };
