import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Detecta o flavor atual do build
class FlavorConfig {
  static String? _cachedFlavor;
  
  /// Retorna o flavor atual (mobile, stoneP2, etc.)
  static String get currentFlavor {
    if (_cachedFlavor != null) return _cachedFlavor!;
    
    // Tenta ler do ambiente de build (--dart-define=FLAVOR=stoneP2)
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
      _cachedFlavor = flavorEnv;
      return _cachedFlavor!;
    }
    
    // Fallback: tenta detectar pelo arquivo de config disponível
    _cachedFlavor = _detectFlavorFromAssets();
    
    return _cachedFlavor!;
  }
  
  /// Detecta flavor tentando carregar arquivos de config
  static String _detectFlavorFromAssets() {
    // Tenta carregar configs em ordem de prioridade
    final flavors = ['stoneP2', 'mobile'];
    
    for (final flavor in flavors) {
      try {
        // Tenta carregar um arquivo de config para verificar se existe
        // Como não podemos fazer isso síncrono, assumimos mobile como padrão
        break;
      } catch (e) {
        continue;
      }
    }
    
    // Padrão: mobile
    return 'mobile';
  }
  
  /// Carrega flavor de forma assíncrona (mais confiável)
  static Future<String> detectFlavorAsync() async {
    if (_cachedFlavor != null) return _cachedFlavor!;
    
    // Tenta ler do ambiente de build (--dart-define=FLAVOR=stoneP2)
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
      _cachedFlavor = flavorEnv;
      debugPrint('✅ Flavor detectado via --dart-define: $flavorEnv');
      return _cachedFlavor!;
    }
    
    // Tenta detectar pelo applicationId (mais confiável)
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final applicationId = packageInfo.packageName;
      debugPrint('📦 ApplicationId detectado: $applicationId');
      
      // Detecta flavor pelo applicationId
      if (applicationId.contains('.stone.p2')) {
        _cachedFlavor = 'stoneP2';
        debugPrint('✅ Flavor detectado via applicationId: stoneP2');
        return _cachedFlavor!;
      } else if (applicationId.contains('.mobile')) {
        _cachedFlavor = 'mobile';
        debugPrint('✅ Flavor detectado via applicationId: mobile');
        return _cachedFlavor!;
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao detectar flavor via applicationId: $e');
    }
    
    // Fallback: tenta detectar pelo arquivo de config disponível
    // Prioriza stoneP2 primeiro (máquinas POS são mais específicas)
    final flavors = ['stoneP2', 'mobile'];
    
    for (final flavor in flavors) {
      try {
        await rootBundle.loadString('assets/config/payment_$flavor.json');
        _cachedFlavor = flavor;
        debugPrint('✅ Flavor detectado via assets: $flavor');
        return flavor;
      } catch (e) {
        continue;
      }
    }
    
    // Fallback final: mobile
    _cachedFlavor = 'mobile';
    debugPrint('⚠️ Flavor não detectado, usando padrão: mobile');
    return _cachedFlavor!;
  }
  
  /// Verifica se é um flavor específico
  static bool isFlavor(String flavor) {
    return currentFlavor.toLowerCase() == flavor.toLowerCase();
  }
  
  /// Verifica se é mobile
  static bool get isMobile => isFlavor('mobile');
  
  /// Verifica se é Stone P2
  static bool get isStoneP2 => isFlavor('stoneP2') || isFlavor('stonep2');
}

