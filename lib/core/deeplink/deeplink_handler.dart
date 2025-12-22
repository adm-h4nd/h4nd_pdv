import 'dart:async';

/// Interface base para handlers de deeplink específicos por dispositivo
abstract class DeepLinkHandler {
  /// Nome do handler (ex: 'stone_p2', 'getnet', etc.)
  String get handlerName;
  
  /// Processa um deeplink de pagamento
  /// Retorna true se o deeplink foi processado com sucesso
  Future<bool> handlePaymentDeepLink(Uri uri);
  
  /// Processa um deeplink de impressão
  /// Retorna true se o deeplink foi processado com sucesso
  Future<bool> handlePrintDeepLink(Uri uri);
  
  /// Verifica se este handler pode processar o deeplink
  bool canHandle(Uri uri);
}

/// Resultado do processamento de deeplink de pagamento
class PaymentDeepLinkResult {
  final bool success;
  final String? transactionId;
  final double? amount;
  final String? paymentType;
  final String? brand;
  final int? installments;
  final String? orderId;
  final String? errorMessage;
  
  PaymentDeepLinkResult({
    required this.success,
    this.transactionId,
    this.amount,
    this.paymentType,
    this.brand,
    this.installments,
    this.orderId,
    this.errorMessage,
  });
}

/// Resultado do processamento de deeplink de impressão
class PrintDeepLinkResult {
  final bool success;
  final String? printJobId;
  final String? errorMessage;
  
  PrintDeepLinkResult({
    required this.success,
    this.printJobId,
    this.errorMessage,
  });
}

