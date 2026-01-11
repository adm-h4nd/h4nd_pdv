import 'tipo_movimentacao.dart';

/// DTO de movimentação de caixa
class MovimentacaoCaixaDto {
  final String id;
  final String cicloCaixaId;
  final String pdvId;
  final String pdvNome;
  final TipoMovimentacao tipo;
  final double valor;
  final String? contaOrigemId;
  final String? contaOrigemNome;
  final String? contaDestinoId;
  final String? contaDestinoNome;
  final String? pagamentoVendaId;
  final String? formaPagamentoId;
  final String? formaPagamentoNome;
  final String? observacoes;
  final String usuarioNome;
  final String dataHora;
  final String createdAt;
  final String? updatedAt;

  MovimentacaoCaixaDto({
    required this.id,
    required this.cicloCaixaId,
    required this.pdvId,
    required this.pdvNome,
    required this.tipo,
    required this.valor,
    this.contaOrigemId,
    this.contaOrigemNome,
    this.contaDestinoId,
    this.contaDestinoNome,
    this.pagamentoVendaId,
    this.formaPagamentoId,
    this.formaPagamentoNome,
    this.observacoes,
    required this.usuarioNome,
    required this.dataHora,
    required this.createdAt,
    this.updatedAt,
  });

  factory MovimentacaoCaixaDto.fromJson(Map<String, dynamic> json) {
    return MovimentacaoCaixaDto(
      id: json['id']?.toString() ?? '',
      cicloCaixaId: json['cicloCaixaId']?.toString() ?? '',
      pdvId: json['pdvId']?.toString() ?? '',
      pdvNome: json['pdvNome'] as String? ?? '',
      tipo: TipoMovimentacao.fromValue(json['tipo'] as int?) ?? TipoMovimentacao.entrada,
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      contaOrigemId: json['contaOrigemId']?.toString(),
      contaOrigemNome: json['contaOrigemNome'] as String?,
      contaDestinoId: json['contaDestinoId']?.toString(),
      contaDestinoNome: json['contaDestinoNome'] as String?,
      pagamentoVendaId: json['pagamentoVendaId']?.toString(),
      formaPagamentoId: json['formaPagamentoId']?.toString(),
      formaPagamentoNome: json['formaPagamentoNome'] as String?,
      observacoes: json['observacoes'] as String?,
      usuarioNome: json['usuarioNome'] as String? ?? '',
      dataHora: json['dataHora'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cicloCaixaId': cicloCaixaId,
      'pdvId': pdvId,
      'pdvNome': pdvNome,
      'tipo': tipo.value,
      'valor': valor,
      'contaOrigemId': contaOrigemId,
      'contaOrigemNome': contaOrigemNome,
      'contaDestinoId': contaDestinoId,
      'contaDestinoNome': contaDestinoNome,
      'pagamentoVendaId': pagamentoVendaId,
      'formaPagamentoId': formaPagamentoId,
      'formaPagamentoNome': formaPagamentoNome,
      'observacoes': observacoes,
      'usuarioNome': usuarioNome,
      'dataHora': dataHora,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

