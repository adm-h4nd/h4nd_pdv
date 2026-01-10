import '../../../../core/payment/payment_provider.dart';
import '../../../../core/payment/payment_ui_notifier.dart';
import '../../../../data/models/core/caixa/tipo_forma_pagamento.dart';
import 'package:flutter/foundation.dart';

/// Provider genérico para pagamentos não integrados (manuais)
/// 
/// Este adapter processa pagamentos que não usam SDK/TEF:
/// - Cartão de crédito/débito sem integração
/// - PIX sem integração
/// - Boleto
/// - Cheque
/// - Vale refeição/alimentação
/// - Outros tipos
/// 
/// **Fluxo:**
/// 1. Valida dados básicos (valor, tipo)
/// 2. Não interage com SDK (processamento manual)
/// 3. Retorna sucesso imediatamente
/// 4. O registro no backend é feito pelo VendaService após o PaymentResult
class ManualPaymentAdapter implements PaymentProvider {
  final TipoFormaPagamento _tipoPagamento;
  
  ManualPaymentAdapter({required TipoFormaPagamento tipoPagamento})
      : _tipoPagamento = tipoPagamento;
  
  @override
  String get providerName => 'Manual (${_getTipoNome()})';
  
  @override
  PaymentType get paymentType {
    // Para pagamentos manuais, PaymentType é apenas uma classificação técnica
    // O importante é o TipoFormaPagamento do backend
    // Usamos TEF como padrão para manuais (não integrados)
    return PaymentType.tef;
  }
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  /// Pagamentos manuais não requerem interação do usuário durante processamento
  /// (a interação já foi feita na tela - usuário informou dados manualmente)
  @override
  bool get requiresUserInteraction => false;
  
  /// Suporta o tipo de pagamento específico que foi passado no construtor
  @override
  List<TipoFormaPagamento> get supportedPaymentTypes => [_tipoPagamento];
  
  @override
  Future<void> initialize() async {
    // Pagamentos manuais não precisam inicializar nada
  }
  
  @override
  Future<void> disconnect() async {
    // Nada a fazer
  }
  
  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier,
  }) async {
    debugPrint('💳 [ManualPaymentAdapter] Processando pagamento manual: ${_getTipoNome()}, Valor: R\$ ${amount.toStringAsFixed(2)}');
    
    // Validações básicas
    if (amount <= 0) {
      return PaymentResult(
        success: false,
        errorMessage: 'Valor deve ser maior que zero',
      );
    }
    
    // Para alguns tipos, pode precisar de validações específicas
    switch (_tipoPagamento) {
      case TipoFormaPagamento.dinheiro:
        // Dinheiro já tem CashPaymentAdapter, mas se vier aqui, valida valor recebido
        final valorRecebido = additionalData?['valorRecebido'] as double?;
        if (valorRecebido == null || valorRecebido < amount) {
          return PaymentResult(
            success: false,
            errorMessage: 'Valor recebido insuficiente',
          );
        }
        break;
        
      case TipoFormaPagamento.cartaoCredito:
      case TipoFormaPagamento.cartaoDebito:
        // Pode validar se tem número de parcelas, bandeira, etc.
        // Mas não é obrigatório para pagamento manual
        break;
        
      case TipoFormaPagamento.pix:
        // Pode validar se tem chave PIX, QR code, etc.
        // Mas não é obrigatório para pagamento manual
        break;
        
      default:
        // Outros tipos não precisam validação especial
        break;
    }
    
    // Gera ID de transação manual
    final transactionId = 'MANUAL-${_tipoPagamento.toValue()}-${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('✅ [ManualPaymentAdapter] Pagamento manual processado com sucesso');
    
    return PaymentResult(
      success: true,
      transactionId: transactionId,
      metadata: {
        'tipoPagamento': _tipoPagamento.toValue(),
        'tipoPagamentoNome': _getTipoNome(),
        'metodo': 'Manual',
        'isIntegrada': false,
        ...?additionalData,
      },
    );
  }
  
  /// Retorna nome legível do tipo de pagamento
  String _getTipoNome() {
    switch (_tipoPagamento) {
      case TipoFormaPagamento.dinheiro:
        return 'Dinheiro';
      case TipoFormaPagamento.cartaoCredito:
        return 'Cartão Crédito';
      case TipoFormaPagamento.cartaoDebito:
        return 'Cartão Débito';
      case TipoFormaPagamento.pix:
        return 'PIX';
      case TipoFormaPagamento.boleto:
        return 'Boleto';
      case TipoFormaPagamento.cheque:
        return 'Cheque';
      case TipoFormaPagamento.valeRefeicao:
        return 'Vale Refeição';
      case TipoFormaPagamento.valeAlimentacao:
        return 'Vale Alimentação';
      case TipoFormaPagamento.outro:
        return 'Outro';
    }
  }
}

