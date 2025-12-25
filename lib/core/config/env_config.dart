import '../storage/preferences_service.dart';
import '../constants/storage_keys.dart';

/// Configuração de ambiente da aplicação
abstract class EnvConfig {
  String get apiBaseUrl;
  String get apiUrl;
  String get s3BaseUrl;
  bool get isProduction;
  Duration get requestTimeout;
}

/// Configuração de desenvolvimento
class DevConfig implements EnvConfig {
  // Para desenvolvimento local, aponta para o servidor rodando no Mac
  // IP do Mac na rede local: 192.168.0.6
  // Porta 5101 para servidor local (5100 é para cloud)
  @override
  String get apiBaseUrl => 'http://192.168.0.6:5101';
  
  @override
  String get apiUrl => '$apiBaseUrl/api';
  
  @override
  String get s3BaseUrl => 'https://mx-cloud.s3.us-east-1.amazonaws.com';
  
  @override
  bool get isProduction => false;
  
  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Configuração de produção
class ProdConfig implements EnvConfig {
  @override
  String get apiBaseUrl => 'http://ec2-54-198-150-183.compute-1.amazonaws.com:5100';
  
  @override
  String get apiUrl => '$apiBaseUrl/api';
  
  @override
  String get s3BaseUrl => 'https://mx-cloud.s3.us-east-1.amazonaws.com';
  
  @override
  bool get isProduction => true;
  
  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Configuração dinâmica que lê do storage
class DynamicConfig implements EnvConfig {
  final String _baseUrl;

  DynamicConfig(this._baseUrl);

  @override
  String get apiBaseUrl => _baseUrl;

  @override
  String get apiUrl => '$apiBaseUrl/api';

  @override
  String get s3BaseUrl => 'https://mx-cloud.s3.us-east-1.amazonaws.com';

  @override
  bool get isProduction => false; // Sempre false para servidor local configurado

  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Factory para obter configuração baseada no ambiente
class Environment {
  /// Obtém configuração, verificando primeiro o storage
  /// Se não tiver config salva, retorna null (para forçar configuração)
  static EnvConfig? getConfigOrNull() {
    // Usa PreferencesService diretamente para evitar circular dependency
    final savedUrl = PreferencesService.getString('mx-cloud-server-url');
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return DynamicConfig(savedUrl);
    }
    
    return null;
  }
  
  /// Obtém configuração com fallback para padrão
  static EnvConfig get config {
    final savedConfig = getConfigOrNull();
    if (savedConfig != null) {
      return savedConfig;
    }
    
    // Se não tiver config salva, usa configuração padrão baseada no ambiente
    // Por padrão, usar servidor de produção
    // Pode ser alterado via flavor ou variável de ambiente
    const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    // Também verifica variável de ambiente customizada para forçar produção
    const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
    // Por padrão, sempre usa produção (ambos DevConfig e ProdConfig apontam para o servidor)
    return (isProd || forceProd) ? ProdConfig() : DevConfig();
  }
}



