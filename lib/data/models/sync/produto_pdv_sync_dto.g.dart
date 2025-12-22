// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_pdv_sync_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProdutoPdvSyncDto _$ProdutoPdvSyncDtoFromJson(Map<String, dynamic> json) =>
    ProdutoPdvSyncDto(
      id: ProdutoPdvSyncDto._idFromJson(json['id']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      sku: json['sku'] as String?,
      referencia: json['referencia'] as String?,
      tipo: ProdutoPdvSyncDto._tipoFromJson(json['tipo']),
      precoVenda: ProdutoPdvSyncDto._decimalToDouble(json['precoVenda']),
      isControlaEstoque: json['isControlaEstoque'] as bool,
      isControlaEstoquePorVariacao:
          json['isControlaEstoquePorVariacao'] as bool,
      unidadeBase: json['unidadeBase'] as String,
      grupoId: ProdutoPdvSyncDto._idFromJsonNullable(json['grupoId']),
      grupoNome: json['grupoNome'] as String?,
      grupoTipoRepresentacao: ProdutoPdvSyncDto._tipoRepresentacaoFromJson(
          json['grupoTipoRepresentacao']),
      grupoIcone: json['grupoIcone'] as String?,
      grupoCor: json['grupoCor'] as String?,
      grupoImagemFileName: json['grupoImagemFileName'] as String?,
      subgrupoId: ProdutoPdvSyncDto._idFromJsonNullable(json['subgrupoId']),
      subgrupoNome: json['subgrupoNome'] as String?,
      subgrupoTipoRepresentacao: ProdutoPdvSyncDto._tipoRepresentacaoFromJson(
          json['subgrupoTipoRepresentacao']),
      subgrupoIcone: json['subgrupoIcone'] as String?,
      subgrupoCor: json['subgrupoCor'] as String?,
      subgrupoImagemFileName: json['subgrupoImagemFileName'] as String?,
      tipoRepresentacao: ProdutoPdvSyncDto._tipoRepresentacaoFromJson(
          json['tipoRepresentacao']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
      atributos: (json['atributos'] as List<dynamic>)
          .map((e) =>
              ProdutoAtributoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      variacoes: (json['variacoes'] as List<dynamic>)
          .map((e) =>
              ProdutoVariacaoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      composicao: (json['composicao'] as List<dynamic>)
          .map((e) =>
              ProdutoComposicaoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      isAtivo: json['isAtivo'] as bool,
      isVendavel: json['isVendavel'] as bool,
      temVariacoes: json['temVariacoes'] as bool,
    );

Map<String, dynamic> _$ProdutoPdvSyncDtoToJson(ProdutoPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'sku': instance.sku,
      'referencia': instance.referencia,
      'tipo': instance.tipo,
      'precoVenda': instance.precoVenda,
      'isControlaEstoque': instance.isControlaEstoque,
      'isControlaEstoquePorVariacao': instance.isControlaEstoquePorVariacao,
      'unidadeBase': instance.unidadeBase,
      'grupoId': instance.grupoId,
      'grupoNome': instance.grupoNome,
      'grupoTipoRepresentacao':
          ProdutoPdvSyncDto._tipoRepresentacaoToJsonNullable(
              instance.grupoTipoRepresentacao),
      'grupoIcone': instance.grupoIcone,
      'grupoCor': instance.grupoCor,
      'grupoImagemFileName': instance.grupoImagemFileName,
      'subgrupoId': instance.subgrupoId,
      'subgrupoNome': instance.subgrupoNome,
      'subgrupoTipoRepresentacao':
          ProdutoPdvSyncDto._tipoRepresentacaoToJsonNullable(
              instance.subgrupoTipoRepresentacao),
      'subgrupoIcone': instance.subgrupoIcone,
      'subgrupoCor': instance.subgrupoCor,
      'subgrupoImagemFileName': instance.subgrupoImagemFileName,
      'tipoRepresentacao': ProdutoPdvSyncDto._tipoRepresentacaoToJson(
          instance.tipoRepresentacao),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
      'atributos': instance.atributos,
      'variacoes': instance.variacoes,
      'composicao': instance.composicao,
      'isAtivo': instance.isAtivo,
      'isVendavel': instance.isVendavel,
      'temVariacoes': instance.temVariacoes,
    };

ProdutoAtributoPdvSyncDto _$ProdutoAtributoPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoAtributoPdvSyncDto(
      id: ProdutoAtributoPdvSyncDto._idFromJson(json['id']),
      produtoId: ProdutoAtributoPdvSyncDto._idFromJson(json['produtoId']),
      atributoId: ProdutoAtributoPdvSyncDto._idFromJson(json['atributoId']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      permiteSelecaoProporcional: json['permiteSelecaoProporcional'] as bool,
      ordem: (json['ordem'] as num).toInt(),
      valores: (json['valores'] as List<dynamic>)
          .map((e) => ProdutoAtributoValorPdvSyncDto.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProdutoAtributoPdvSyncDtoToJson(
        ProdutoAtributoPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoId': instance.produtoId,
      'atributoId': instance.atributoId,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'permiteSelecaoProporcional': instance.permiteSelecaoProporcional,
      'ordem': instance.ordem,
      'valores': instance.valores,
    };

ProdutoAtributoValorPdvSyncDto _$ProdutoAtributoValorPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoAtributoValorPdvSyncDto(
      id: ProdutoAtributoValorPdvSyncDto._idFromJson(json['id']),
      atributoValorId:
          ProdutoAtributoValorPdvSyncDto._idFromJson(json['atributoValorId']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$ProdutoAtributoValorPdvSyncDtoToJson(
        ProdutoAtributoValorPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'atributoValorId': instance.atributoValorId,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'ordem': instance.ordem,
      'isActive': instance.isActive,
    };

ProdutoVariacaoPdvSyncDto _$ProdutoVariacaoPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoVariacaoPdvSyncDto(
      id: ProdutoVariacaoPdvSyncDto._idFromJson(json['id']),
      produtoId: ProdutoVariacaoPdvSyncDto._idFromJson(json['produtoId']),
      nome: json['nome'] as String?,
      nomeCompleto: json['nomeCompleto'] as String,
      descricao: json['descricao'] as String?,
      precoVenda:
          ProdutoVariacaoPdvSyncDto._decimalToDouble(json['precoVenda']),
      precoEfetivo: ProdutoVariacaoPdvSyncDto._decimalToDoubleRequired(
          json['precoEfetivo']),
      sku: json['sku'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      valores: (json['valores'] as List<dynamic>)
          .map((e) => ProdutoVariacaoValorPdvSyncDto.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      tipoRepresentacaoVisual:
          ProdutoVariacaoPdvSyncDto._tipoRepresentacaoFromJsonNullable(
              json['tipoRepresentacaoVisual']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
      composicao: (json['composicao'] as List<dynamic>)
          .map((e) =>
              ProdutoComposicaoPdvSyncDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProdutoVariacaoPdvSyncDtoToJson(
        ProdutoVariacaoPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoId': instance.produtoId,
      'nome': instance.nome,
      'nomeCompleto': instance.nomeCompleto,
      'descricao': instance.descricao,
      'precoVenda': instance.precoVenda,
      'precoEfetivo': instance.precoEfetivo,
      'sku': instance.sku,
      'ordem': instance.ordem,
      'valores': instance.valores,
      'tipoRepresentacaoVisual':
          ProdutoVariacaoPdvSyncDto._tipoRepresentacaoToJsonNullable(
              instance.tipoRepresentacaoVisual),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
      'composicao': instance.composicao,
    };

ProdutoVariacaoValorPdvSyncDto _$ProdutoVariacaoValorPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoVariacaoValorPdvSyncDto(
      id: ProdutoVariacaoValorPdvSyncDto._idFromJson(json['id']),
      produtoVariacaoId:
          ProdutoVariacaoValorPdvSyncDto._idFromJson(json['produtoVariacaoId']),
      atributoValorId:
          ProdutoVariacaoValorPdvSyncDto._idFromJson(json['atributoValorId']),
      nomeAtributo: json['nomeAtributo'] as String,
      nomeValor: json['nomeValor'] as String,
    );

Map<String, dynamic> _$ProdutoVariacaoValorPdvSyncDtoToJson(
        ProdutoVariacaoValorPdvSyncDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoVariacaoId': instance.produtoVariacaoId,
      'atributoValorId': instance.atributoValorId,
      'nomeAtributo': instance.nomeAtributo,
      'nomeValor': instance.nomeValor,
    };

ProdutoComposicaoPdvSyncDto _$ProdutoComposicaoPdvSyncDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoComposicaoPdvSyncDto(
      componenteId:
          ProdutoComposicaoPdvSyncDto._idFromJson(json['componenteId']),
      componenteNome: json['componenteNome'] as String,
      isRemovivel: json['isRemovivel'] as bool,
      ordem: (json['ordem'] as num).toInt(),
    );

Map<String, dynamic> _$ProdutoComposicaoPdvSyncDtoToJson(
        ProdutoComposicaoPdvSyncDto instance) =>
    <String, dynamic>{
      'componenteId': instance.componenteId,
      'componenteNome': instance.componenteNome,
      'isRemovivel': instance.isRemovivel,
      'ordem': instance.ordem,
    };
