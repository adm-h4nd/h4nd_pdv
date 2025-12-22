/// DTO para pagamento de venda
class PagamentoVendaDto {
  final String id;
  final String vendaId;
  final int tipoFormaPagamento; // TipoFormaPagamento enum
  final String formaPagamento;
  final double valor;
  final int numeroParcelas;
  final String? bandeiraCartao;
  final String? ultimosDigitosCartao;
  final String? chavePIX;
  final String? identificadorTransacaoPIX;
  final int status; // StatusPagamento enum
  final DateTime dataPagamento;
  final DateTime? dataConfirmacao;
  final DateTime? dataVencimento;
  final String? observacoes;
  final bool isCancelado;
  final DateTime? dataCancelamento;
  final String? motivoCancelamento;

  PagamentoVendaDto({
    required this.id,
    required this.vendaId,
    required this.tipoFormaPagamento,
    required this.formaPagamento,
    required this.valor,
    this.numeroParcelas = 1,
    this.bandeiraCartao,
    this.ultimosDigitosCartao,
    this.chavePIX,
    this.identificadorTransacaoPIX,
    required this.status,
    required this.dataPagamento,
    this.dataConfirmacao,
    this.dataVencimento,
    this.observacoes,
    this.isCancelado = false,
    this.dataCancelamento,
    this.motivoCancelamento,
  });

  factory PagamentoVendaDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final vendaIdValue = json['vendaId'];
    final vendaId = vendaIdValue is String ? vendaIdValue : vendaIdValue?.toString() ?? '';

    final tipoFormaPagamentoValue = json['tipoFormaPagamento'];
    final tipoFormaPagamento = tipoFormaPagamentoValue is int 
        ? tipoFormaPagamentoValue 
        : (tipoFormaPagamentoValue != null ? int.tryParse(tipoFormaPagamentoValue.toString()) ?? 0 : 0);

    final statusValue = json['status'];
    final status = statusValue is int 
        ? statusValue 
        : (statusValue != null ? int.tryParse(statusValue.toString()) ?? 0 : 0);

    final dataPagamentoValue = json['dataPagamento'];
    final dataPagamento = dataPagamentoValue is String 
        ? DateTime.tryParse(dataPagamentoValue) ?? DateTime.now()
        : (dataPagamentoValue is DateTime ? dataPagamentoValue : DateTime.now());

    final dataConfirmacaoValue = json['dataConfirmacao'];
    final DateTime? dataConfirmacao = dataConfirmacaoValue != null
        ? (dataConfirmacaoValue is String 
            ? DateTime.tryParse(dataConfirmacaoValue)
            : (dataConfirmacaoValue is DateTime ? dataConfirmacaoValue : null))
        : null;

    final dataVencimentoValue = json['dataVencimento'];
    final DateTime? dataVencimento = dataVencimentoValue != null
        ? (dataVencimentoValue is String 
            ? DateTime.tryParse(dataVencimentoValue)
            : (dataVencimentoValue is DateTime ? dataVencimentoValue : null))
        : null;

    final dataCancelamentoValue = json['dataCancelamento'];
    final DateTime? dataCancelamento = dataCancelamentoValue != null
        ? (dataCancelamentoValue is String 
            ? DateTime.tryParse(dataCancelamentoValue)
            : (dataCancelamentoValue is DateTime ? dataCancelamentoValue : null))
        : null;

    final valor = (json['valor'] as num?)?.toDouble() ?? 0.0;
    final numeroParcelas = json['numeroParcelas'] as int? ?? 1;
    final isCancelado = json['isCancelado'] as bool? ?? false;

    return PagamentoVendaDto(
      id: id,
      vendaId: vendaId,
      tipoFormaPagamento: tipoFormaPagamento,
      formaPagamento: json['formaPagamento'] as String? ?? '',
      valor: valor,
      numeroParcelas: numeroParcelas,
      bandeiraCartao: json['bandeiraCartao'] as String?,
      ultimosDigitosCartao: json['ultimosDigitosCartao'] as String?,
      chavePIX: json['chavePIX'] as String?,
      identificadorTransacaoPIX: json['identificadorTransacaoPIX'] as String?,
      status: status,
      dataPagamento: dataPagamento,
      dataConfirmacao: dataConfirmacao,
      dataVencimento: dataVencimento,
      observacoes: json['observacoes'] as String?,
      isCancelado: isCancelado,
      dataCancelamento: dataCancelamento,
      motivoCancelamento: json['motivoCancelamento'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendaId': vendaId,
      'tipoFormaPagamento': tipoFormaPagamento,
      'formaPagamento': formaPagamento,
      'valor': valor,
      'numeroParcelas': numeroParcelas,
      'bandeiraCartao': bandeiraCartao,
      'ultimosDigitosCartao': ultimosDigitosCartao,
      'chavePIX': chavePIX,
      'identificadorTransacaoPIX': identificadorTransacaoPIX,
      'status': status,
      'dataPagamento': dataPagamento.toIso8601String(),
      'dataConfirmacao': dataConfirmacao?.toIso8601String(),
      'dataVencimento': dataVencimento?.toIso8601String(),
      'observacoes': observacoes,
      'isCancelado': isCancelado,
      'dataCancelamento': dataCancelamento?.toIso8601String(),
      'motivoCancelamento': motivoCancelamento,
    };
  }
}
