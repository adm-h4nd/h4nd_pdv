// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_completo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProdutoCompletoDto _$ProdutoCompletoDtoFromJson(Map<String, dynamic> json) =>
    ProdutoCompletoDto(
      id: ProdutoCompletoDto._idFromJson(json['id']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      sku: json['sku'] as String?,
      referencia: json['referencia'] as String?,
      tipo: ProdutoCompletoDto._tipoFromJson(json['tipo']),
      precoVenda: (json['precoVenda'] as num?)?.toDouble(),
      precoCusto: (json['precoCusto'] as num?)?.toDouble(),
      isControlaEstoque: json['isControlaEstoque'] as bool,
      isControlaEstoquePorVariacao:
          json['isControlaEstoquePorVariacao'] as bool,
      unidadeBase: json['unidadeBase'] as String,
      temVariacoes: json['temVariacoes'] as bool,
      temComposicao: json['temComposicao'] as bool,
      tipoRepresentacao: ProdutoCompletoDto._tipoRepresentacaoFromJson(
          json['tipoRepresentacao']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
      atributos: (json['atributos'] as List<dynamic>)
          .map((e) => ProdutoAtributoDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      variacoes: (json['variacoes'] as List<dynamic>)
          .map((e) => ProdutoVariacaoDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProdutoCompletoDtoToJson(ProdutoCompletoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'sku': instance.sku,
      'referencia': instance.referencia,
      'tipo': ProdutoCompletoDto._tipoToJson(instance.tipo),
      'precoVenda': instance.precoVenda,
      'precoCusto': instance.precoCusto,
      'isControlaEstoque': instance.isControlaEstoque,
      'isControlaEstoquePorVariacao': instance.isControlaEstoquePorVariacao,
      'unidadeBase': instance.unidadeBase,
      'temVariacoes': instance.temVariacoes,
      'temComposicao': instance.temComposicao,
      'tipoRepresentacao': ProdutoCompletoDto._tipoRepresentacaoToJson(
          instance.tipoRepresentacao),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
      'atributos': instance.atributos,
      'variacoes': instance.variacoes,
    };

ProdutoAtributoDto _$ProdutoAtributoDtoFromJson(Map<String, dynamic> json) =>
    ProdutoAtributoDto(
      id: ProdutoAtributoDto._idFromJson(json['id']),
      produtoId: ProdutoAtributoDto._idFromJson(json['produtoId']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      permiteSelecaoProporcional: json['permiteSelecaoProporcional'] as bool,
      atributoId: ProdutoAtributoDto._idFromJson(json['atributoId']),
      totalValores: (json['totalValores'] as num).toInt(),
    );

Map<String, dynamic> _$ProdutoAtributoDtoToJson(ProdutoAtributoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoId': instance.produtoId,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'ordem': instance.ordem,
      'permiteSelecaoProporcional': instance.permiteSelecaoProporcional,
      'atributoId': instance.atributoId,
      'totalValores': instance.totalValores,
    };

AtributoValorDto _$AtributoValorDtoFromJson(Map<String, dynamic> json) =>
    AtributoValorDto(
      id: AtributoValorDto._idFromJson(json['id']),
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$AtributoValorDtoToJson(AtributoValorDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'ordem': instance.ordem,
      'isActive': instance.isActive,
    };

ProdutoVariacaoDto _$ProdutoVariacaoDtoFromJson(Map<String, dynamic> json) =>
    ProdutoVariacaoDto(
      id: ProdutoVariacaoDto._idFromJson(json['id']),
      produtoId: ProdutoVariacaoDto._idFromJson(json['produtoId']),
      nome: json['nome'] as String?,
      nomeCompleto: json['nomeCompleto'] as String,
      descricao: json['descricao'] as String?,
      precoVenda: (json['precoVenda'] as num?)?.toDouble(),
      precoEfetivo: (json['precoEfetivo'] as num).toDouble(),
      precoCusto: (json['precoCusto'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
      ean: json['ean'] as String?,
      ordem: (json['ordem'] as num).toInt(),
      valores: (json['valores'] as List<dynamic>)
          .map((e) =>
              ProdutoVariacaoValorDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      usaGrade: json['usaGrade'] as bool,
      tipoRepresentacaoVisual:
          ProdutoVariacaoDto._tipoRepresentacaoVisualFromJson(
              json['tipoRepresentacaoVisual']),
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
    );

Map<String, dynamic> _$ProdutoVariacaoDtoToJson(ProdutoVariacaoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoId': instance.produtoId,
      'nome': instance.nome,
      'nomeCompleto': instance.nomeCompleto,
      'descricao': instance.descricao,
      'precoVenda': instance.precoVenda,
      'precoEfetivo': instance.precoEfetivo,
      'precoCusto': instance.precoCusto,
      'sku': instance.sku,
      'ean': instance.ean,
      'ordem': instance.ordem,
      'valores': instance.valores,
      'usaGrade': instance.usaGrade,
      'tipoRepresentacaoVisual':
          ProdutoVariacaoDto._tipoRepresentacaoVisualToJson(
              instance.tipoRepresentacaoVisual),
      'icone': instance.icone,
      'cor': instance.cor,
      'imagemFileName': instance.imagemFileName,
    };

ProdutoVariacaoValorDto _$ProdutoVariacaoValorDtoFromJson(
        Map<String, dynamic> json) =>
    ProdutoVariacaoValorDto(
      id: ProdutoVariacaoValorDto._idFromJson(json['id']),
      produtoVariacaoId:
          ProdutoVariacaoValorDto._idFromJson(json['produtoVariacaoId']),
      atributoValorId:
          ProdutoVariacaoValorDto._idFromJson(json['atributoValorId']),
      nomeAtributo: json['nomeAtributo'] as String,
      nomeValor: json['nomeValor'] as String,
    );

Map<String, dynamic> _$ProdutoVariacaoValorDtoToJson(
        ProdutoVariacaoValorDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'produtoVariacaoId': instance.produtoVariacaoId,
      'atributoValorId': instance.atributoValorId,
      'nomeAtributo': instance.nomeAtributo,
      'nomeValor': instance.nomeValor,
    };
