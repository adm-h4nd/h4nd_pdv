// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_exibicao_basico.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProdutoExibicaoBasicoDto _$ProdutoExibicaoBasicoDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoExibicaoBasicoDto(
      produtoId: json['produtoId'] as String,
      produtoNome: json['produtoNome'] as String,
      produtoSKU: json['produtoSKU'] as String?,
      produtoPrecoVenda: (json['produtoPrecoVenda'] as num?)?.toDouble(),
      produtoImagemFileName: json['produtoImagemFileName'] as String?,
      produtoTipoRepresentacao:
          ProdutoExibicaoBasicoDto._tipoRepresentacaoFromJson(
              json['produtoTipoRepresentacao']),
      produtoIcone: json['produtoIcone'] as String?,
      produtoCor: json['produtoCor'] as String?,
      ordem: (json['ordem'] as num).toInt(),
    );

Map<String, dynamic> _$ProdutoExibicaoBasicoDtoToJson(
        ProdutoExibicaoBasicoDto instance) =>
    <String, dynamic>{
      'produtoId': instance.produtoId,
      'produtoNome': instance.produtoNome,
      'produtoSKU': instance.produtoSKU,
      'produtoPrecoVenda': instance.produtoPrecoVenda,
      'produtoImagemFileName': instance.produtoImagemFileName,
      'produtoTipoRepresentacao':
          ProdutoExibicaoBasicoDto._tipoRepresentacaoToJson(
              instance.produtoTipoRepresentacao),
      'produtoIcone': instance.produtoIcone,
      'produtoCor': instance.produtoCor,
      'ordem': instance.ordem,
    };
