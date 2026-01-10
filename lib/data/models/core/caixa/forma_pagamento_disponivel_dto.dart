import 'tipo_forma_pagamento.dart';

/// DTO para forma de pagamento disponível por empresa (usado no PDV)
/// 
/// Retornado pelo endpoint: GET /api/FormaPagamento/empresa/{empresaId}/disponiveis
/// 
/// Este DTO contém tanto os dados da FormaPagamento quanto as configurações
/// específicas da empresa (FormaPagamentoEmpresa).
class FormaPagamentoDisponivelDto {
  /// ID da forma de pagamento
  final String formaPagamentoId;
  
  /// Nome da forma de pagamento
  final String nome;
  
  /// Código interno (opcional)
  final String? codigo;
  
  /// Tipo base da forma de pagamento (enum)
  final TipoFormaPagamento tipoBase;
  
  /// Se requer troco
  final bool requerTroco;
  
  /// Se permite parcelas
  final bool permiteParcelas;
  
  /// Número máximo de parcelas (se permite parcelas)
  final int? parcelasMaximas;
  
  /// Se é dinheiro físico (controla caixa físico)
  final bool isDinheiroFisico;
  
  /// Se é integrada (usa SDK/TEF) - configuração da empresa
  final bool isIntegrada;
  
  /// Ordem de exibição - configuração da empresa
  final int ordemExibicao;
  
  /// Se deve exibir no PDV - configuração da empresa
  final bool exibirNoPDV;
  
  /// Se deve emitir nota fiscal automática - configuração da empresa
  final bool emitirNotaFiscal;

  FormaPagamentoDisponivelDto({
    required this.formaPagamentoId,
    required this.nome,
    this.codigo,
    required this.tipoBase,
    required this.requerTroco,
    required this.permiteParcelas,
    this.parcelasMaximas,
    required this.isDinheiroFisico,
    required this.isIntegrada,
    required this.ordemExibicao,
    required this.exibirNoPDV,
    required this.emitirNotaFiscal,
  });

  factory FormaPagamentoDisponivelDto.fromJson(Map<String, dynamic> json) {
    // Converter formaPagamentoId (pode vir como Guid ou String)
    final formaPagamentoIdValue = json['formaPagamentoId'];
    final formaPagamentoId = formaPagamentoIdValue is String
        ? formaPagamentoIdValue
        : formaPagamentoIdValue?.toString() ?? '';

    // Converter tipoBase (enum int)
    final tipoBaseValue = json['tipoBase'];
    final tipoBase = tipoBaseValue is int
        ? TipoFormaPagamento.fromValue(tipoBaseValue) ?? TipoFormaPagamento.outro
        : (tipoBaseValue != null
            ? TipoFormaPagamento.fromValue(int.tryParse(tipoBaseValue.toString()))
            : TipoFormaPagamento.outro) ?? TipoFormaPagamento.outro;

    return FormaPagamentoDisponivelDto(
      formaPagamentoId: formaPagamentoId,
      nome: json['nome'] as String? ?? '',
      codigo: json['codigo'] as String?,
      tipoBase: tipoBase,
      requerTroco: json['requerTroco'] as bool? ?? false,
      permiteParcelas: json['permiteParcelas'] as bool? ?? false,
      parcelasMaximas: json['parcelasMaximas'] as int?,
      isDinheiroFisico: json['isDinheiroFisico'] as bool? ?? false,
      isIntegrada: json['isIntegrada'] as bool? ?? false,
      ordemExibicao: json['ordemExibicao'] as int? ?? 0,
      exibirNoPDV: json['exibirNoPDV'] as bool? ?? false,
      emitirNotaFiscal: json['emitirNotaFiscal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formaPagamentoId': formaPagamentoId,
      'nome': nome,
      'codigo': codigo,
      'tipoBase': tipoBase.toValue(),
      'requerTroco': requerTroco,
      'permiteParcelas': permiteParcelas,
      'parcelasMaximas': parcelasMaximas,
      'isDinheiroFisico': isDinheiroFisico,
      'isIntegrada': isIntegrada,
      'ordemExibicao': ordemExibicao,
      'exibirNoPDV': exibirNoPDV,
      'emitirNotaFiscal': emitirNotaFiscal,
    };
  }
}

