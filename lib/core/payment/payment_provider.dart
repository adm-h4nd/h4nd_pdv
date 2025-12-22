import 'payment_transaction_data.dart';

/// Interface base para providers de pagamento
abstract class PaymentProvider {
  /// Nome do provider (ex: "Stone", "GetNet", "Cash")
  String get providerName;
  
  /// Tipo de pagamento (POS, TEF, Cash)
  PaymentType get paymentType;
  
  /// Se o provider está disponível
  bool get isAvailable;
  
  /// Processa um pagamento
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
  });
  
  /// Inicializa o provider
  Future<void> initialize();
  
  /// Desconecta/limpa recursos
  Future<void> disconnect();
}

/// Tipo de pagamento
enum PaymentType {
  cash,      // Dinheiro
  pos,       // Point of Sale (SDK direto)
  tef,       // Transferência Eletrônica de Fundos
}

/// Resultado de um pagamento
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  
  /// Dados padronizados da transação de pagamento
  /// Cada provider deve mapear seus dados específicos para PaymentTransactionData
  final PaymentTransactionData? transactionData;
  
  PaymentResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
    this.metadata,
    this.transactionData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

