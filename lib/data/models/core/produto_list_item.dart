import 'package:flutter/foundation.dart';

/// Item de lista de produto
class ProdutoListItemDto {
  final String id;
  final String nome;
  final String? descricao;
  final String? sku;
  final String? referencia;
  final String tipo; // TipoProduto enum
  final double? precoVenda;
  final double? precoCusto;
  final bool isControlaEstoque;
  final String unidadeBase;
  final String? grupoId;
  final String? grupoNome;
  final String? subgrupoId;
  final String? subgrupoNome;
  final bool isVendavel;
  final bool isCompravel;
  final bool temVariacoes;
  final bool isActive;
  final DateTime createdAt;
  
  // Representação visual
  final String tipoRepresentacao; // TipoRepresentacaoVisual enum
  final String? icone;
  final String? cor;
  final String? imagemFileName;

  ProdutoListItemDto({
    required this.id,
    required this.nome,
    this.descricao,
    this.sku,
    this.referencia,
    required this.tipo,
    this.precoVenda,
    this.precoCusto,
    required this.isControlaEstoque,
    required this.unidadeBase,
    this.grupoId,
    this.grupoNome,
    this.subgrupoId,
    this.subgrupoNome,
    required this.isVendavel,
    required this.isCompravel,
    required this.temVariacoes,
    required this.isActive,
    required this.createdAt,
    required this.tipoRepresentacao,
    this.icone,
    this.cor,
    this.imagemFileName,
  });

  factory ProdutoListItemDto.fromJson(Map<String, dynamic> json) {
    return ProdutoListItemDto(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] as String? ?? '',
      descricao: json['descricao'] as String?,
      sku: json['sku'] as String?,
      referencia: json['referencia'] as String?,
      tipo: json['tipo']?.toString() ?? '',
      precoVenda: json['precoVenda'] != null 
          ? (json['precoVenda'] as num).toDouble() 
          : null,
      precoCusto: json['precoCusto'] != null 
          ? (json['precoCusto'] as num).toDouble() 
          : null,
      isControlaEstoque: json['isControlaEstoque'] as bool? ?? false,
      unidadeBase: json['unidadeBase'] as String? ?? 'UN',
      grupoId: json['grupoId']?.toString(),
      grupoNome: json['grupoNome'] as String?,
      subgrupoId: json['subgrupoId']?.toString(),
      subgrupoNome: json['subgrupoNome'] as String?,
      isVendavel: json['isVendavel'] as bool? ?? false,
      isCompravel: json['isCompravel'] as bool? ?? false,
      temVariacoes: json['temVariacoes'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      tipoRepresentacao: json['tipoRepresentacao']?.toString() ?? 'Icone',
      icone: json['icone'] as String?,
      cor: json['cor'] as String?,
      imagemFileName: json['imagemFileName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'sku': sku,
      'referencia': referencia,
      'tipo': tipo,
      'precoVenda': precoVenda,
      'precoCusto': precoCusto,
      'isControlaEstoque': isControlaEstoque,
      'unidadeBase': unidadeBase,
      'grupoId': grupoId,
      'grupoNome': grupoNome,
      'subgrupoId': subgrupoId,
      'subgrupoNome': subgrupoNome,
      'isVendavel': isVendavel,
      'isCompravel': isCompravel,
      'temVariacoes': temVariacoes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'tipoRepresentacao': tipoRepresentacao,
      'icone': icone,
      'cor': cor,
      'imagemFileName': imagemFileName,
    };
  }
}
