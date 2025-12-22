import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço para armazenamento seguro de dados sensíveis
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Salva um valor de forma segura
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Lê um valor de forma segura
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Remove um valor
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Remove todos os valores
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Verifica se uma chave existe
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }
}



