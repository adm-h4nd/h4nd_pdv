// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exibicao_produto_pdv_sync_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExibicaoProdutoPdvSyncDto _$ExibicaoProdutoPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ExibicaoProdutoPdvSyncDto(
      id: ExibicaoProdutoPdvSyncDto._idFromJson(json['id']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      categoriaPaiId:
          ExibicaoProdutoPdvSyncDto._idFromJsonNullable(json['categoriaPaiId']),
      ordem: (json['ordem'] as num).toInt(),
      tipoRepresentacao: ExibicaoProdutoPdvSyncDto._tipoRepresentacaoFromJson(
          json['tipoRepresentacao']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
      isAtiva: json['isAtiva'] as bool,
      categoriasFilhas: (json['categoriasFilhas'] as List<dynamic>)
          .map((e) =>
              ExibicaoProdutoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      produtos: (json['produtos'] as List<dynamic>)
          .map((e) =>
              ProdutoExibicaoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ExibicaoProdutoPdvSyncDtoToJson(
        ExibicaoProdutoPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'categoriaPaiId': instance.categoriaPaiId,
      'ordem': instance.ordem,
      'tipoRepresentacao': ExibicaoProdutoPdvSyncDto._tipoRepresentacaoToJson(
          instance.tipoRepresentacao),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
      'isAtiva': instance.isAtiva,
      'categoriasFilhas': instance.categoriasFilhas,
      'produtos': instance.produtos,
    };

ProdutoExibicaoPdvSyncDto _$ProdutoExibicaoPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoExibicaoPdvSyncDto(
      produtoId: ProdutoExibicaoPdvSyncDto._idFromJson(json['produtoId']),
      ordem: (json['ordem'] as num).toInt(),
    );

Map<String, dynamic> _$ProdutoExibicaoPdvSyncDtoToJson(
        ProdutoExibicaoPdvSyncDto instance) =>
    <String, dynamic>{
      'produtoId': instance.produtoId,
      'ordem': instance.ordem,
    };
