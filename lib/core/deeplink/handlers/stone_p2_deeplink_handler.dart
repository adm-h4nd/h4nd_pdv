import '../deeplink_handler.dart';
import 'package:flutter/foundation.dart';
import '../../../data/adapters/payment/providers/stone_p2_deeplink_payment_adapter.dart';

/// Handler de deeplink específico para Stone P2
/// 
/// Processa deeplinks no formato:
/// - Pagamento: deeplinkmxcloudpdv://pay-response?code=0&amount=...&type=...&brand=...&installment_count=...&order_id=...
/// - Impressão: deeplinkprinter://print?...
class StoneP2DeepLinkHandler implements DeepLinkHandler {
  @override
  String get handlerName => 'stone_p2';
  
  /// Callback para quando um pagamento é processado
  final Function(PaymentDeepLinkResult)? onPaymentResult;
  
  /// Callback para quando uma impressão é processada
  final Function(PrintDeepLinkResult)? onPrintResult;
  
  StoneP2DeepLinkHandler({
    this.onPaymentResult,
    this.onPrintResult,
  });
  
  @override
  bool canHandle(Uri uri) {
    // Stone P2 usa esses esquemas:
    // - deeplinkmxcloudpdv://pay-response (pagamento)
    // - deeplinkprinter://print (impressão)
    return uri.scheme == 'deeplinkmxcloudpdv' || uri.scheme == 'deeplinkprinter';
  }
  
  @override
  Future<bool> handlePaymentDeepLink(Uri uri) async {
    if (uri.scheme != 'deeplinkmxcloudpdv' || uri.host != 'pay-response') {
      return false;
    }
    
    try {
      debugPrint('🔗 [Stone P2] Processando deeplink de pagamento: $uri');
      
      // Extrai parâmetros da URL
      final code = uri.queryParameters['code'];
      final amountStr = uri.queryParameters['amount'];
      final type = uri.queryParameters['type'];
      final brand = uri.queryParameters['brand'];
      final installmentCountStr = uri.queryParameters['installment_count'];
      final orderId = uri.queryParameters['order_id'];
      
      debugPrint('🔗 [Stone P2] Parâmetros extraídos: code=$code, amount=$amountStr, type=$type, brand=$brand, installments=$installmentCountStr, orderId=$orderId');
      
      // Tenta recuperar o vendaId original do mapeamento (se orderId foi formatado)
      String? originalVendaId = orderId;
      if (orderId != null) {
        try {
          // Tenta recuperar do mapeamento (se orderId foi formatado)
          final mappedVendaId = StoneP2DeepLinkPaymentAdapter.getOriginalVendaId(orderId);
          if (mappedVendaId != null) {
            originalVendaId = mappedVendaId;
            debugPrint('🔗 [Stone P2] VendaId original recuperado do mapeamento: $originalVendaId');
          } else {
            debugPrint('ℹ️ [Stone P2] OrderId não encontrado no mapeamento, usando diretamente: $orderId');
          }
        } catch (e) {
          debugPrint('⚠️ [Stone P2] Erro ao recuperar vendaId original: $e');
        }
      }
      
      // Processa código de resposta
      if (code == '0') {
        // Pagamento aprovado
        final amount = amountStr != null ? (int.parse(amountStr) / 100) : null;
        final installments = installmentCountStr != null 
            ? (int.parse(installmentCountStr) == 0 ? 1 : int.parse(installmentCountStr))
            : 1;
        
        final result = PaymentDeepLinkResult(
          success: true,
          transactionId: 'STONE-P2-${DateTime.now().millisecondsSinceEpoch}',
          amount: amount,
          paymentType: type,
          brand: brand,
          installments: installments,
          orderId: originalVendaId ?? orderId, // Usa vendaId original se disponível
        );
        
        debugPrint('✅ [Stone P2] Pagamento aprovado: ${result.amount} via ${result.paymentType}');
        
        onPaymentResult?.call(result);
        return true;
      } else if (code == '-2') {
        // Pagamento não concluído
        final result = PaymentDeepLinkResult(
          success: false,
          errorMessage: 'Pagamento não concluído',
          orderId: originalVendaId ?? orderId,
        );
        
        debugPrint('⚠️ [Stone P2] Pagamento não concluído');
        onPaymentResult?.call(result);
        return true;
      } else if (code == '-6') {
        // Pagamento negado
        final result = PaymentDeepLinkResult(
          success: false,
          errorMessage: 'Pagamento negado',
          orderId: originalVendaId ?? orderId,
        );
        
        debugPrint('❌ [Stone P2] Pagamento negado');
        onPaymentResult?.call(result);
        return true;
      } else if (code != null) {
        // Outro código de erro
        final result = PaymentDeepLinkResult(
          success: false,
          errorMessage: 'Pagamento não realizado (código: $code)',
          orderId: originalVendaId ?? orderId,
        );
        
        debugPrint('❌ [Stone P2] Pagamento não realizado: código $code');
        onPaymentResult?.call(result);
        return true;
      } else {
        debugPrint('⚠️ [Stone P2] Deeplink de pagamento sem código');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [Stone P2] Erro ao processar deeplink de pagamento: $e');
      onPaymentResult?.call(PaymentDeepLinkResult(
        success: false,
        errorMessage: 'Erro ao processar deeplink: ${e.toString()}',
      ));
      return false;
    }
  }
  
  @override
  Future<bool> handlePrintDeepLink(Uri uri) async {
    if (uri.scheme != 'deeplinkprinter' || uri.host != 'print') {
      return false;
    }
    
    try {
      debugPrint('🖨️ [Stone P2] Processando deeplink de impressão: $uri');
      
      // Stone P2 retorna deeplink de impressão quando completa
      // Por padrão, consideramos sucesso se recebemos o callback
      final result = PrintDeepLinkResult(
        success: true,
        printJobId: 'STONE-P2-PRINT-${DateTime.now().millisecondsSinceEpoch}',
      );
      
      debugPrint('✅ [Stone P2] Impressão concluída');
      onPrintResult?.call(result);
      return true;
    } catch (e) {
      debugPrint('❌ [Stone P2] Erro ao processar deeplink de impressão: $e');
      onPrintResult?.call(PrintDeepLinkResult(
        success: false,
        errorMessage: 'Erro ao processar deeplink: ${e.toString()}',
      ));
      return false;
    }
  }
}

