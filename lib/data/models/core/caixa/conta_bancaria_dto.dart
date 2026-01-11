import 'tipo_conta.dart';

/// DTO para listagem de conta bancária
class ContaBancariaListItemDto {
  final String id;
  final String nome;
  final String? codigo;
  final TipoConta tipo;
  final String? banco;
  final String? agencia;
  final String? conta;
  final double saldoAtual;
  final String empresaId;
  final String empresaNome;
  final String? pessoaId;
  final String? pessoaNome;
  final bool isActive;

  ContaBancariaListItemDto({
    required this.id,
    required this.nome,
    this.codigo,
    required this.tipo,
    this.banco,
    this.agencia,
    this.conta,
    required this.saldoAtual,
    required this.empresaId,
    required this.empresaNome,
    this.pessoaId,
    this.pessoaNome,
    required this.isActive,
  });

  factory ContaBancariaListItemDto.fromJson(Map<String, dynamic> json) {
    return ContaBancariaListItemDto(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] as String? ?? '',
      codigo: json['codigo'] as String?,
      tipo: TipoConta.fromValue(json['tipo'] as int?) ?? TipoConta.bancaria,
      banco: json['banco'] as String?,
      agencia: json['agencia'] as String?,
      conta: json['conta'] as String?,
      saldoAtual: (json['saldoAtual'] as num?)?.toDouble() ?? 0.0,
      empresaId: json['empresaId']?.toString() ?? '',
      empresaNome: json['empresaNome'] as String? ?? '',
      pessoaId: json['pessoaId']?.toString(),
      pessoaNome: json['pessoaNome'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'codigo': codigo,
      'tipo': tipo.value,
      'banco': banco,
      'agencia': agencia,
      'conta': conta,
      'saldoAtual': saldoAtual,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'pessoaId': pessoaId,
      'pessoaNome': pessoaNome,
      'isActive': isActive,
    };
  }

  /// Verifica se é conta interna (cofre)
  bool get ehInterna => tipo == TipoConta.interna;
}

