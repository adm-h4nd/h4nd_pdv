import 'dart:convert';

/// Utilitários para manipulação de JWT
class JwtUtils {
  /// Decodifica um JWT e retorna o payload
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Verifica se um JWT está expirado
  static bool isExpired(String token) {
    final payload = decode(token);
    if (payload == null) return true;

    final exp = payload['exp'] as int?;
    if (exp == null) return true;

    final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expirationDate);
  }

  /// Obtém a data de expiração do token
  static DateTime? getExpirationDate(String token) {
    final payload = decode(token);
    if (payload == null) return null;

    final exp = payload['exp'] as int?;
    if (exp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  /// Obtém um claim específico do token
  static T? getClaim<T>(String token, String claim) {
    try {
      final payload = decode(token);
      if (payload == null) return null;

      final value = payload[claim];
      if (value == null) return null;

      // Se o tipo esperado é o mesmo do valor, retorna direto
      if (value is T) return value;

      // Verifica o tipo usando Type
      final type = T.toString();
      
      // Conversões especiais de tipo para int
      if (type == 'int' || type == 'int?') {
        if (value is int) return value as T;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed as T;
        }
        if (value is double) {
          return value.toInt() as T;
        }
        return null;
      }

      // Conversões especiais de tipo para double
      if (type == 'double' || type == 'double?') {
        if (value is double) return value as T;
        if (value is int) return value.toDouble() as T;
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed as T;
        }
        return null;
      }

      // Conversões especiais de tipo para bool
      if (type == 'bool' || type == 'bool?') {
        if (value is bool) return value as T;
        if (value is String) {
          final boolValue = value.toLowerCase() == 'true';
          return boolValue as T;
        }
        if (value is int) {
          final boolValue = value != 0;
          return boolValue as T;
        }
        return null;
      }

      // Tenta fazer cast direto como último recurso
      return value as T?;
    } catch (e) {
      print('Erro ao obter claim "$claim": $e');
      return null;
    }
  }
}



