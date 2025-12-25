import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Repositório para gerenciar preferências do usuário
class UserPreferencesRepository {
  static const String _keyPreferences = 'user_preferences';
  static const String _keyMesaViewSize = 'mesa_view_size';

  /// Salva as preferências do usuário
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMesaViewSize, preferences.mesaViewSize.name);
  }

  /// Carrega as preferências do usuário
  Future<UserPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final mesaViewSizeStr = prefs.getString(_keyMesaViewSize);
    if (mesaViewSizeStr == null) {
      return UserPreferences.defaults();
    }

    final mesaViewSize = MesaViewSize.values.firstWhere(
      (e) => e.name == mesaViewSizeStr,
      orElse: () => MesaViewSize.medio,
    );

    return UserPreferences(
      mesaViewSize: mesaViewSize,
    );
  }

  /// Salva apenas o tamanho de visualização das mesas
  Future<void> saveMesaViewSize(MesaViewSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMesaViewSize, size.name);
  }

  /// Carrega apenas o tamanho de visualização das mesas
  Future<MesaViewSize> loadMesaViewSize() async {
    final prefs = await SharedPreferences.getInstance();
    final sizeStr = prefs.getString(_keyMesaViewSize);
    
    if (sizeStr == null) {
      return MesaViewSize.medio;
    }

    return MesaViewSize.values.firstWhere(
      (e) => e.name == sizeStr,
      orElse: () => MesaViewSize.medio,
    );
  }

  /// Limpa todas as preferências
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMesaViewSize);
  }
}

