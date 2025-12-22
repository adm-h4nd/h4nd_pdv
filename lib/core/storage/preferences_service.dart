import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para armazenamento de preferências não sensíveis
class PreferencesService {
  static SharedPreferences? _prefs;

  /// Inicializa o serviço
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Salva um valor booleano
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  /// Lê um valor booleano
  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Salva uma string
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  /// Lê uma string
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Salva um inteiro
  static Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  /// Lê um inteiro
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Remove uma chave
  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  /// Remove todas as chaves
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  /// Verifica se uma chave existe
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }
}



