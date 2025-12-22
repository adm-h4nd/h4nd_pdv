import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'deeplink_handler.dart';
import 'handlers/stone_p2_deeplink_handler.dart';
import '../config/flavor_config.dart';

/// Gerenciador central de deeplinks
/// 
/// Registra handlers específicos por flavor e processa deeplinks recebidos
class DeepLinkManager {
  static DeepLinkManager? _instance;
  static DeepLinkManager get instance => _instance ??= DeepLinkManager._();
  
  DeepLinkManager._();
  
  final List<DeepLinkHandler> _handlers = [];
  StreamSubscription<Uri>? _linkSubscription;
  AppLinks? _appLinks;
  
  /// Inicializa o gerenciador de deeplinks baseado no flavor atual
  Future<void> initialize({
    Function(PaymentDeepLinkResult)? onPaymentResult,
    Function(PrintDeepLinkResult)? onPrintResult,
  }) async {
    final flavor = await FlavorConfig.detectFlavorAsync();
    debugPrint('🔗 Inicializando DeepLinkManager para flavor: $flavor');
    
    // Registra handlers baseado no flavor
    switch (flavor) {
      case 'stoneP2':
        _handlers.add(StoneP2DeepLinkHandler(
          onPaymentResult: onPaymentResult,
          onPrintResult: onPrintResult,
        ));
        debugPrint('✅ Handler Stone P2 registrado');
        break;
      
      case 'mobile':
        // Mobile pode não ter handlers específicos ou usar genéricos
        debugPrint('ℹ️ Flavor mobile - sem handlers específicos de deeplink');
        break;
      
      default:
        debugPrint('⚠️ Flavor desconhecido: $flavor');
    }
    
    // Inicia listener de deeplinks usando app_links
    _appLinks = AppLinks();
    
    // Escuta deeplinks quando app está em foreground
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 Deeplink recebido: $uri');
        processDeepLink(uri);
      },
      onError: (err) {
        debugPrint('❌ Erro ao escutar deeplinks: $err');
      },
    );
    
    // Processa deeplink inicial (se app foi aberto via deeplink)
    _appLinks!.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('🔗 Deeplink inicial recebido: $uri');
        processDeepLink(uri);
      }
    });
    
    debugPrint('📦 Total de handlers registrados: ${_handlers.length}');
  }
  
  /// Processa um deeplink recebido
  /// 
  /// Tenta processar com cada handler registrado até encontrar um que consiga processar
  Future<bool> processDeepLink(Uri uri) async {
    debugPrint('🔗 Processando deeplink: $uri');
    
    for (final handler in _handlers) {
      if (handler.canHandle(uri)) {
        debugPrint('✅ Handler ${handler.handlerName} pode processar este deeplink');
        
        // Tenta processar como pagamento primeiro
        if (await handler.handlePaymentDeepLink(uri)) {
          return true;
        }
        
        // Se não for pagamento, tenta como impressão
        if (await handler.handlePrintDeepLink(uri)) {
          return true;
        }
      }
    }
    
    debugPrint('⚠️ Nenhum handler conseguiu processar o deeplink: $uri');
    return false;
  }
  
  /// Adiciona um handler manualmente (útil para testes ou casos especiais)
  void addHandler(DeepLinkHandler handler) {
    _handlers.add(handler);
    debugPrint('✅ Handler ${handler.handlerName} adicionado manualmente');
  }
  
  /// Limpa todos os handlers
  void clear() {
    _handlers.clear();
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _appLinks = null;
  }
  
  /// Dispose resources
  void dispose() {
    clear();
  }
}

