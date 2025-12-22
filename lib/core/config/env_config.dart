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
  @override
  String get apiBaseUrl => 'http://192.168.0.6:5100';
  
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

/// Factory para obter configuração baseada no ambiente
class Environment {
  static EnvConfig get config {
    // Por padrão, usar servidor de produção
    // Pode ser alterado via flavor ou variável de ambiente
    const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    // Também verifica variável de ambiente customizada para forçar produção
    const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
    // Por padrão, sempre usa produção (ambos DevConfig e ProdConfig apontam para o servidor)
    return (isProd || forceProd) ? ProdConfig() : DevConfig();
  }
}



