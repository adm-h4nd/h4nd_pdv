import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider de pagamento via DeepLink específico para Stone P2
/// 
/// Usa o padrão encontrado no projeto app_restaurante_kotlin:
/// payment-app://pay?return_scheme=deeplinkmxcloudpdv://pay-response&amount=...&editable_amount=1&order_id=...
class StoneP2DeepLinkPaymentAdapter implements PaymentProvider {
  // Mapeamento temporário: orderId formatado -> vendaId original
  // Necessário porque a Stone P2 retorna o orderId formatado no callback
  static final Map<String, String> _orderIdMapping = {};
  
  @override
  String get providerName => 'Stone P2 DeepLink';
  
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
      // Constrói DeepLink específico do Stone P2
      final deepLink = _buildStoneP2DeepLink(amount, vendaId);
      
      debugPrint('🔗 [Stone P2] Abrindo DeepLink de pagamento: $deepLink');
      
      final uri = Uri.parse(deepLink);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // DeepLink não retorna resultado imediatamente
        // O app externo processa e retorna via callback (deeplinkmxcloudpdv://pay-response)
        // O resultado será tratado pelo handler de deeplink do app
        
        return PaymentResult(
          success: true,
          transactionId: 'STONE-P2-DEEPLINK-${DateTime.now().millisecondsSinceEpoch}',
          metadata: {
            'provider': 'stone_p2_deeplink',
            'deepLink': deepLink,
            'pending': true, // Indica que precisa aguardar callback
            'returnScheme': 'deeplinkmxcloudpdv://pay-response',
          },
        );
      } else {
        return PaymentResult(
          success: false,
          errorMessage: 'Não foi possível abrir o app de pagamento Stone P2',
        );
      }
    } catch (e) {
      debugPrint('❌ [Stone P2] Erro ao processar DeepLink: $e');
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao processar DeepLink Stone P2: ${e.toString()}',
      );
    }
  }
  
  /// Constrói o DeepLink específico do Stone P2
  /// 
  /// Padrão: payment-app://pay?return_scheme=...&amount=...&editable_amount=1&order_id=...
  /// 
  /// NOTA: A Stone P2 pode ter limitações no formato do order_id.
  /// Se o vendaId for um GUID, pode ser necessário converter para um formato mais simples.
  String _buildStoneP2DeepLink(double amount, String vendaId) {
    // Valor em centavos (padrão Stone P2)
    final amountInCents = (amount * 100).toInt();
    
    // Converte GUID para formato mais simples (remove hífens e usa apenas primeiros caracteres)
    // A Stone P2 pode ter limitações de tamanho ou formato
    final orderId = _formatOrderIdForStoneP2(vendaId);
    
    // Armazena mapeamento para poder recuperar o vendaId original no callback
    _orderIdMapping[orderId] = vendaId;
    
    debugPrint('🔗 [Stone P2] VendaId original: $vendaId');
    debugPrint('🔗 [Stone P2] OrderId formatado: $orderId');
    debugPrint('🔗 [Stone P2] Mapeamento salvo: $orderId -> $vendaId');
    
    final uri = Uri(
      scheme: 'payment-app',
      host: 'pay',
      queryParameters: {
        'return_scheme': 'deeplinkmxcloudpdv://pay-response',
        'amount': amountInCents.toString(),
        'editable_amount': '1', // Permite editar valor na máquina
        'order_id': orderId,
      },
    );
    
    final deepLink = uri.toString();
    debugPrint('🔗 [Stone P2] DeepLink completo: $deepLink');
    
    return deepLink;
  }
  
  /// Recupera o vendaId original a partir do orderId formatado retornado no callback
  static String? getOriginalVendaId(String formattedOrderId) {
    return _orderIdMapping[formattedOrderId];
  }
  
  /// Limpa mapeamentos antigos (chamar periodicamente para evitar vazamento de memória)
  static void clearOldMappings({int maxAgeMinutes = 60}) {
    // Por enquanto, mantém todos os mapeamentos
    // Em produção, implementar limpeza baseada em timestamp
  }
  
  /// Formata o order_id para o formato aceito pela Stone P2
  /// 
  /// A Stone P2 pode não aceitar GUIDs completos com hífens.
  /// Remove hífens e mantém o GUID completo (32 caracteres) para garantir
  /// que o mapeamento funcione corretamente.
  String _formatOrderIdForStoneP2(String vendaId) {
    // Remove hífens e mantém GUID completo (32 caracteres)
    // Não truncamos para garantir que o mapeamento funcione
    final cleanId = vendaId.replaceAll('-', '').toLowerCase();
    
    debugPrint('🔗 [Stone P2] GUID formatado: ${cleanId.length} caracteres');
    
    return cleanId;
    
    // Opção 2: Se Stone P2 aceitar apenas números, usar hash numérico
    // final hash = vendaId.hashCode.abs();
    // return hash.toString();
    
    // Opção 3: Extrair apenas números do GUID
    // final numbersOnly = vendaId.replaceAll(RegExp(r'[^0-9]'), '');
    // return numbersOnly.isNotEmpty ? numbersOnly.substring(0, 10) : '0';
  }
}

