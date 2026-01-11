import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../storage/preferences_service.dart';

/// Chave para armazenar o ID do dispositivo gerado
const String _deviceIdKey = 'device_unique_id';

/// Serviço para obter um identificador único do dispositivo
/// 
/// COMPORTAMENTO DE PERSISTÊNCIA:
/// 
/// ✅ MANTÉM O ID:
/// - Fechar e abrir o app novamente
/// - Atualizar a versão do app
/// - Limpar cache do app (não limpa SharedPreferences)
/// 
/// ❌ PERDE O ID (gera novo):
/// - Desinstalar o app (SharedPreferences é deletado)
/// - Reset de fábrica do dispositivo
/// - Limpar dados do app manualmente (Settings > Apps > Clear Data)
/// 
/// ESTRATÉGIA DE IMPLEMENTAÇÃO:
/// 
/// 1. PRIMEIRA PRIORIDADE: ID armazenado em SharedPreferences
///    - Se existe, retorna esse ID (sobrevive a atualizações)
///    - Persiste mesmo após limpar cache
/// 
/// 2. SEGUNDA PRIORIDADE: ID nativo da plataforma (se disponível)
///    - Android: Android ID (pode mudar após reset de fábrica)
///    - iOS: IDFV (pode mudar se todos apps do vendor forem desinstalados)
///    - Windows/macOS/Linux: Não há ID nativo confiável
/// 
/// 3. FALLBACK: UUID gerado e armazenado
///    - Gera um UUID único e salva em SharedPreferences
///    - Usado quando não há ID nativo disponível
/// 
/// IMPORTANTE: O ID é único por INSTALAÇÃO do app, não por dispositivo físico.
/// Se o usuário desinstalar e reinstalar, um novo ID será gerado.
class DeviceIdService {
  static String? _cachedDeviceId;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const Uuid _uuid = Uuid();

  /// Obtém o ID único do dispositivo
  /// 
  /// Retorna sempre o mesmo ID para o mesmo dispositivo/instalação.
  /// O ID é cacheado após a primeira obtenção.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      // Inicializa o serviço de preferências se necessário
      await PreferencesService.init();

      // PRIORIDADE 1: Tenta obter ID já armazenado em SharedPreferences
      // Isso garante que o ID persista mesmo após atualizações e limpeza de cache
      final storedId = PreferencesService.getString(_deviceIdKey);
      if (storedId != null && storedId.isNotEmpty) {
        _cachedDeviceId = storedId;
        debugPrint('✅ Device ID recuperado do armazenamento: ${_cachedDeviceId!.substring(0, 8)}...');
        return _cachedDeviceId!;
      }

      // PRIORIDADE 2: Tenta obter ID nativo da plataforma (se disponível)
      // Nota: Esses IDs podem mudar em alguns cenários, então são usados apenas
      // como "seed" inicial. O ID será sempre armazenado em SharedPreferences.
      String? nativeId;

      if (Platform.isAndroid) {
        nativeId = await _getAndroidId();
      } else if (Platform.isIOS) {
        nativeId = await _getIosId();
      }
      // Windows/macOS/Linux não têm ID nativo confiável via device_info_plus

      // Se conseguiu um ID nativo, usa ele como base
      // MAS sempre armazena em SharedPreferences para garantir persistência
      if (nativeId != null && nativeId.isNotEmpty) {
        _cachedDeviceId = nativeId;
        await PreferencesService.setString(_deviceIdKey, nativeId);
        debugPrint('✅ Device ID nativo obtido e armazenado: ${nativeId.substring(0, 8)}...');
        return nativeId;
      }

      // PRIORIDADE 3: Fallback - gera um UUID e armazena permanentemente
      // Este é o comportamento padrão para Windows/macOS/Linux
      // e também para Android/iOS quando o ID nativo não está disponível
      final generatedId = _uuid.v4();
      _cachedDeviceId = generatedId;
      await PreferencesService.setString(_deviceIdKey, generatedId);
      debugPrint('✅ Device ID gerado (UUID) e armazenado: ${generatedId.substring(0, 8)}...');
      return generatedId;
    } catch (e) {
      debugPrint('❌ Erro ao obter Device ID: $e');
      
      // Em caso de erro, tenta recuperar do armazenamento
      final storedId = PreferencesService.getString(_deviceIdKey);
      if (storedId != null && storedId.isNotEmpty) {
        _cachedDeviceId = storedId;
        return storedId;
      }

      // Último recurso: gera um novo UUID
      final fallbackId = _uuid.v4();
      _cachedDeviceId = fallbackId;
      try {
        await PreferencesService.setString(_deviceIdKey, fallbackId);
      } catch (_) {
        // Se não conseguir salvar, pelo menos retorna o ID gerado
      }
      debugPrint('⚠️ Device ID gerado como fallback: ${fallbackId.substring(0, 8)}...');
      return fallbackId;
    }
  }

  /// Obtém Android ID
  static Future<String?> _getAndroidId() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final androidId = androidInfo.id;
      
      // Android ID pode ser null ou "9774d56d682e549c" (valor padrão em alguns emuladores)
      // Se for o valor padrão ou vazio, não usa
      if (androidId != null && 
          androidId.isNotEmpty && 
          androidId != '9774d56d682e549c') {
        return androidId;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao obter Android ID: $e');
      return null;
    }
  }

  /// Obtém iOS Identifier for Vendor (IDFV)
  static Future<String?> _getIosId() async {
    try {
      final iosInfo = await _deviceInfo.iosInfo;
      final identifierForVendor = iosInfo.identifierForVendor;
      
      if (identifierForVendor != null && identifierForVendor.isNotEmpty) {
        return identifierForVendor;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao obter iOS IDFV: $e');
      return null;
    }
  }

  /// Obtém Windows Machine GUID ou gera um UUID persistente
  static Future<String?> _getWindowsId() async {
    try {
      // Windows não fornece um ID único nativo diretamente via device_info_plus
      // Gera um UUID e armazena permanentemente
      // O UUID será persistido e reutilizado em todas as execuções
      return null; // Retorna null para forçar geração de UUID
    } catch (e) {
      debugPrint('❌ Erro ao obter Windows ID: $e');
      return null;
    }
  }

  /// Obtém macOS ID
  static Future<String?> _getMacOSId() async {
    try {
      // macOS não fornece um ID único nativo diretamente via device_info_plus
      // Gera um UUID e armazena permanentemente
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao obter macOS ID: $e');
      return null;
    }
  }

  /// Obtém Linux ID
  static Future<String?> _getLinuxId() async {
    try {
      // Linux não fornece um ID único nativo diretamente via device_info_plus
      // Gera um UUID e armazena permanentemente
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao obter Linux ID: $e');
      return null;
    }
  }

  /// Limpa o cache do Device ID (útil para testes)
  static void clearCache() {
    _cachedDeviceId = null;
  }

  /// Força a regeneração do Device ID (útil para testes ou reset)
  /// ATENÇÃO: Isso vai gerar um novo ID e perder a associação com o dispositivo anterior
  static Future<String> regenerateDeviceId() async {
    await PreferencesService.remove(_deviceIdKey);
    _cachedDeviceId = null;
    return await getDeviceId();
  }
}

