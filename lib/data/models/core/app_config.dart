/// Modelo para configuração do app retornada pelo backend
/// A URL da API não é incluída pois é configurada pelo próprio app (ServerConfigService)
class AppConfig {
  final String s3BaseUrl;
  final String? environment;

  AppConfig({
    required this.s3BaseUrl,
    this.environment,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    // Pode vir como { success: true, data: {...} } ou diretamente {...}
    final data = json['data'] as Map<String, dynamic>? ?? json;
    
    return AppConfig(
      s3BaseUrl: data['s3BaseUrl'] as String,
      environment: data['environment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      's3BaseUrl': s3BaseUrl,
      'environment': environment,
    };
  }
}

