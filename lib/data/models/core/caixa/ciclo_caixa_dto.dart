import 'status_caixa.dart';
import 'movimentacao_caixa_dto.dart';

/// DTO para listagem de ciclo de caixa
class CicloCaixaListItemDto {
  final String id;
  final String caixaId;
  final String caixaNome;
  final String empresaId;
  final String empresaNome;
  final StatusCaixa status;
  final String dataHoraAbertura;
  final String? dataHoraFechamento;
  final double valorInicial;
  final String usuarioAberturaNome;

  CicloCaixaListItemDto({
    required this.id,
    required this.caixaId,
    required this.caixaNome,
    required this.empresaId,
    required this.empresaNome,
    required this.status,
    required this.dataHoraAbertura,
    this.dataHoraFechamento,
    required this.valorInicial,
    required this.usuarioAberturaNome,
  });

  factory CicloCaixaListItemDto.fromJson(Map<String, dynamic> json) {
    return CicloCaixaListItemDto(
      id: json['id']?.toString() ?? '',
      caixaId: json['caixaId']?.toString() ?? '',
      caixaNome: json['caixaNome'] as String? ?? '',
      empresaId: json['empresaId']?.toString() ?? '',
      empresaNome: json['empresaNome'] as String? ?? '',
      status: StatusCaixa.fromValue(json['status'] as int?) ?? StatusCaixa.aberto,
      dataHoraAbertura: json['dataHoraAbertura'] as String,
      dataHoraFechamento: json['dataHoraFechamento'] as String?,
      valorInicial: (json['valorInicial'] as num?)?.toDouble() ?? 0.0,
      usuarioAberturaNome: json['usuarioAberturaNome'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caixaId': caixaId,
      'caixaNome': caixaNome,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'status': status.value,
      'dataHoraAbertura': dataHoraAbertura,
      'dataHoraFechamento': dataHoraFechamento,
      'valorInicial': valorInicial,
      'usuarioAberturaNome': usuarioAberturaNome,
    };
  }
}

/// DTO completo de ciclo de caixa
class CicloCaixaDto extends CicloCaixaListItemDto {
  final String usuarioAberturaId;
  final String? usuarioFechamentoId;
  final String? usuarioFechamentoNome;
  final String contaOrigemId;
  final String contaOrigemNome;
  
  // Valores contados no fechamento
  final double? valorDinheiroContado;
  final double? valorCartaoCreditoContado;
  final double? valorCartaoDebitoContado;
  final double? valorPIXContado;
  final double? valorOutrosContado;
  
  // Valores esperados (calculados)
  final double? valorDinheiroEsperado;
  final double? valorCartaoCreditoEsperado;
  final double? valorCartaoDebitoEsperado;
  final double? valorPIXEsperado;
  final double? valorOutrosEsperado;
  
  final String? observacoesFechamento;
  final String createdAt;
  final String? updatedAt;
  final List<MovimentacaoCaixaDto> movimentacoes;

  CicloCaixaDto({
    required super.id,
    required super.caixaId,
    required super.caixaNome,
    required super.empresaId,
    required super.empresaNome,
    required super.status,
    required super.dataHoraAbertura,
    super.dataHoraFechamento,
    required super.valorInicial,
    required super.usuarioAberturaNome,
    required this.usuarioAberturaId,
    this.usuarioFechamentoId,
    this.usuarioFechamentoNome,
    required this.contaOrigemId,
    required this.contaOrigemNome,
    this.valorDinheiroContado,
    this.valorCartaoCreditoContado,
    this.valorCartaoDebitoContado,
    this.valorPIXContado,
    this.valorOutrosContado,
    this.valorDinheiroEsperado,
    this.valorCartaoCreditoEsperado,
    this.valorCartaoDebitoEsperado,
    this.valorPIXEsperado,
    this.valorOutrosEsperado,
    this.observacoesFechamento,
    required this.createdAt,
    this.updatedAt,
    this.movimentacoes = const [],
  });

  factory CicloCaixaDto.fromJson(Map<String, dynamic> json) {
    return CicloCaixaDto(
      id: json['id']?.toString() ?? '',
      caixaId: json['caixaId']?.toString() ?? '',
      caixaNome: json['caixaNome'] as String? ?? '',
      empresaId: json['empresaId']?.toString() ?? '',
      empresaNome: json['empresaNome'] as String? ?? '',
      status: StatusCaixa.fromValue(json['status'] as int?) ?? StatusCaixa.aberto,
      dataHoraAbertura: json['dataHoraAbertura'] as String,
      dataHoraFechamento: json['dataHoraFechamento'] as String?,
      valorInicial: (json['valorInicial'] as num?)?.toDouble() ?? 0.0,
      usuarioAberturaNome: json['usuarioAberturaNome'] as String? ?? '',
      usuarioAberturaId: json['usuarioAberturaId']?.toString() ?? '',
      usuarioFechamentoId: json['usuarioFechamentoId']?.toString(),
      usuarioFechamentoNome: json['usuarioFechamentoNome'] as String?,
      contaOrigemId: json['contaOrigemId']?.toString() ?? '',
      contaOrigemNome: json['contaOrigemNome'] as String? ?? '',
      valorDinheiroContado: (json['valorDinheiroContado'] as num?)?.toDouble(),
      valorCartaoCreditoContado: (json['valorCartaoCreditoContado'] as num?)?.toDouble(),
      valorCartaoDebitoContado: (json['valorCartaoDebitoContado'] as num?)?.toDouble(),
      valorPIXContado: (json['valorPIXContado'] as num?)?.toDouble(),
      valorOutrosContado: (json['valorOutrosContado'] as num?)?.toDouble(),
      valorDinheiroEsperado: (json['valorDinheiroEsperado'] as num?)?.toDouble(),
      valorCartaoCreditoEsperado: (json['valorCartaoCreditoEsperado'] as num?)?.toDouble(),
      valorCartaoDebitoEsperado: (json['valorCartaoDebitoEsperado'] as num?)?.toDouble(),
      valorPIXEsperado: (json['valorPIXEsperado'] as num?)?.toDouble(),
      valorOutrosEsperado: (json['valorOutrosEsperado'] as num?)?.toDouble(),
      observacoesFechamento: json['observacoesFechamento'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
      movimentacoes: (json['movimentacoes'] as List<dynamic>?)
          ?.map((m) => MovimentacaoCaixaDto.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'usuarioAberturaId': usuarioAberturaId,
      'usuarioFechamentoId': usuarioFechamentoId,
      'usuarioFechamentoNome': usuarioFechamentoNome,
      'contaOrigemId': contaOrigemId,
      'contaOrigemNome': contaOrigemNome,
      'valorDinheiroContado': valorDinheiroContado,
      'valorCartaoCreditoContado': valorCartaoCreditoContado,
      'valorCartaoDebitoContado': valorCartaoDebitoContado,
      'valorPIXContado': valorPIXContado,
      'valorOutrosContado': valorOutrosContado,
      'valorDinheiroEsperado': valorDinheiroEsperado,
      'valorCartaoCreditoEsperado': valorCartaoCreditoEsperado,
      'valorCartaoDebitoEsperado': valorCartaoDebitoEsperado,
      'valorPIXEsperado': valorPIXEsperado,
      'valorOutrosEsperado': valorOutrosEsperado,
      'observacoesFechamento': observacoesFechamento,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'movimentacoes': movimentacoes.map((m) => m.toJson()).toList(),
    };
  }

  /// Verifica se o ciclo está aberto
  bool get estaAberto => status == StatusCaixa.aberto;
}

/// DTO para abertura de ciclo de caixa
class AbrirCicloCaixaDto {
  final String caixaId;
  final double valorInicial;

  AbrirCicloCaixaDto({
    required this.caixaId,
    required this.valorInicial,
  });

  Map<String, dynamic> toJson() {
    return {
      'caixaId': caixaId,
      'valorInicial': valorInicial,
    };
  }
}

/// DTO para fechamento de ciclo de caixa
class FecharCicloCaixaDto {
  final double? valorDinheiroContado;
  final double? valorCartaoCreditoContado;
  final double? valorCartaoDebitoContado;
  final double? valorPIXContado;
  final double? valorOutrosContado;
  final String? observacoesFechamento;

  FecharCicloCaixaDto({
    this.valorDinheiroContado,
    this.valorCartaoCreditoContado,
    this.valorCartaoDebitoContado,
    this.valorPIXContado,
    this.valorOutrosContado,
    this.observacoesFechamento,
  });

  Map<String, dynamic> toJson() {
    return {
      'valorDinheiroContado': valorDinheiroContado,
      'valorCartaoCreditoContado': valorCartaoCreditoContado,
      'valorCartaoDebitoContado': valorCartaoDebitoContado,
      'valorPIXContado': valorPIXContado,
      'valorOutrosContado': valorOutrosContado,
      'observacoesFechamento': observacoesFechamento,
    };
  }
}

/// DTO para reforço de ciclo de caixa (crédito)
class ReforcoCicloCaixaDto {
  final String cicloCaixaId;
  final double valor;
  final String? observacoes;

  ReforcoCicloCaixaDto({
    required this.cicloCaixaId,
    required this.valor,
    this.observacoes,
  });

  Map<String, dynamic> toJson() {
    return {
      'cicloCaixaId': cicloCaixaId,
      'valor': valor,
      if (observacoes != null && observacoes!.isNotEmpty) 'observacoes': observacoes,
    };
  }
}

/// DTO para sangria de ciclo de caixa (débito)
class SangriaCicloCaixaDto {
  final String cicloCaixaId;
  final double valor;
  final String? observacoes;

  SangriaCicloCaixaDto({
    required this.cicloCaixaId,
    required this.valor,
    this.observacoes,
  });

  Map<String, dynamic> toJson() {
    return {
      'cicloCaixaId': cicloCaixaId,
      'valor': valor,
      if (observacoes != null && observacoes!.isNotEmpty) 'observacoes': observacoes,
    };
  }
}

