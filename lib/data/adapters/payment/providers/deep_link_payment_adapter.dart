import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider de pagamento via DeepLink (abre app externo)
class DeepLinkPaymentAdapter implements PaymentProvider {
  @override
  String get providerName => 'DeepLink';
  
  @override
  PaymentType get paymentType => PaymentType.cash; // DeepLink removido, usando cash como fallback
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  @override
  Future<void> initialize() async {
    // DeepLink não precisa inicializar
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
    try {
      final provider = additionalData?['provider'] as String? ?? 'pix';
      
      // Constrói DeepLink baseado no provider
      final deepLink = _buildDeepLink(provider, amount, vendaId);
      
      debugPrint('🔗 Abrindo DeepLink: $deepLink');
      
      final uri = Uri.parse(deepLink);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // DeepLink não retorna resultado imediatamente
        // O app externo processa e pode retornar via callback
        // Por enquanto, retorna sucesso (o resultado real viria via callback)
        
        return PaymentResult(
          success: true,
          transactionId: 'DEEPLINK-${DateTime.now().millisecondsSinceEpoch}',
          metadata: {
            'provider': provider,
            'deepLink': deepLink,
            'pending': true, // Indica que precisa aguardar callback
          },
        );
      } else {
        return PaymentResult(
          success: false,
          errorMessage: 'Não foi possível abrir o app de pagamento',
        );
      }
    } catch (e) {
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao processar DeepLink: ${e.toString()}',
      );
    }
  }
  
  String _buildDeepLink(String provider, double amount, String vendaId) {
    // Padrão usado na Stone P2: payment-app://pay
    // Baseado no projeto app_restaurante_kotlin
    final amountInCents = (amount * 100).toInt();
    
    final uri = Uri(
      scheme: 'payment-app',
      host: 'pay',
      queryParameters: {
        'return_scheme': 'deeplinkmxcloudpdv://pay-response',
        'amount': amountInCents.toString(),
        'editable_amount': '1', // Permite editar valor
        'order_id': vendaId,
      },
    );
    
    return uri.toString();
  }
}

