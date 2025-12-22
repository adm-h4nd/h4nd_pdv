import '../../../../core/payment/payment_provider.dart';

/// Provider de pagamento em dinheiro (não precisa de SDK)
class CashPaymentAdapter implements PaymentProvider {
  @override
  String get providerName => 'Cash';
  
  @override
  PaymentType get paymentType => PaymentType.cash;
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  @override
  Future<void> initialize() async {
    // Dinheiro não precisa inicializar nada
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
  }) async {
    // Para dinheiro, valida apenas se valor recebido é suficiente
    final valorRecebido = additionalData?['valorRecebido'] as double?;
    
    // Valida se o valor recebido foi informado
    if (valorRecebido == null) {
      return PaymentResult(
        success: false,
        errorMessage: 'Valor recebido não informado',
      );
    }
    
    // Usa uma pequena tolerância para comparação de ponto flutuante (0.01 centavos)
    const tolerancia = 0.01;
    
    if (valorRecebido < (amount - tolerancia)) {
      return PaymentResult(
        success: false,
        errorMessage: 'Valor recebido insuficiente. Recebido: R\$ ${valorRecebido.toStringAsFixed(2)}, Necessário: R\$ ${amount.toStringAsFixed(2)}',
      );
    }
    
    final troco = valorRecebido - amount;
    
    return PaymentResult(
      success: true,
      transactionId: 'CASH-${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'valorRecebido': valorRecebido,
        'troco': troco,
        'metodo': 'Dinheiro',
      },
    );
  }
}

