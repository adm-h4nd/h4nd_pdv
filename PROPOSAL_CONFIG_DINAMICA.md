# Proposta: Configuração Dinâmica do Backend

## 🎯 Objetivo

Fazer com que o Flutter obtenha a URL base da API e S3 diretamente do backend, garantindo que:
- Se o backend for de homologação → retorna URLs de homologação
- Se o backend for de produção → retorna URLs de produção
- O app sempre usa a configuração correta do ambiente

## 📋 Solução Proposta

### 1. Backend: Criar endpoint `/api/config` ou `/api/app-config`

**Controller**: `ConfigController.cs` ou adicionar ao `HealthController`

```csharp
[HttpGet("config")]
[AllowAnonymous] // Pode ser chamado sem autenticação
public IActionResult GetAppConfig()
{
    var config = new
    {
        apiUrl = _config["App:ApiUrl"] ?? "https://api-hml.h4nd.com.br/api",
        s3BaseUrl = _config["AWS:S3:BaseUrl"] ?? "https://h4nd-client-hml.s3.us-east-1.amazonaws.com",
        environment = _env.EnvironmentName
    };
    
    return Ok(ApiResponse<object>.SuccessResult(config, "Configuração do app"));
}
```

**appsettings.json**:
```json
{
  "App": {
    "ApiUrl": "https://api-hml.h4nd.com.br/api"
  },
  "AWS": {
    "S3": {
      "BaseUrl": "https://h4nd-client-hml.s3.us-east-1.amazonaws.com"
    }
  }
}
```

**appsettings.Production.json**:
```json
{
  "App": {
    "ApiUrl": "https://api.h4nd.com.br/api"
  },
  "AWS": {
    "S3": {
      "BaseUrl": "https://h4nd-client.s3.us-east-1.amazonaws.com"
    }
  }
}
```

### 2. Flutter: Criar `AppConfigService`

**Model**: `lib/data/models/core/app_config.dart`
```dart
class AppConfig {
  final String apiUrl;
  final String s3BaseUrl;
  final String? environment;

  AppConfig({
    required this.apiUrl,
    required this.s3BaseUrl,
    this.environment,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return AppConfig(
      apiUrl: data['apiUrl'] as String,
      s3BaseUrl: data['s3BaseUrl'] as String,
      environment: data['environment'] as String?,
    );
  }
}
```

**Service**: `lib/core/config/app_config_service.dart`
```dart
class AppConfigService {
  static const String _configKey = 'app_config';
  
  /// Obtém configuração do backend usando uma URL inicial conhecida
  static Future<AppConfig?> fetchFromBackend(String initialApiUrl) async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('$initialApiUrl/config'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AppConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('Erro ao buscar config do backend: $e');
    }
    return null;
  }
  
  /// Salva configuração no storage
  static Future<void> saveConfig(AppConfig config) async {
    await PreferencesService.setString(
      _configKey,
      jsonEncode({
        'apiUrl': config.apiUrl,
        's3BaseUrl': config.s3BaseUrl,
        'environment': config.environment,
      }),
    );
  }
  
  /// Carrega configuração do storage
  static AppConfig? loadFromStorage() {
    final saved = PreferencesService.getString(_configKey);
    if (saved == null) return null;
    
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return AppConfig(
        apiUrl: json['apiUrl'] as String,
        s3BaseUrl: json['s3BaseUrl'] as String,
        environment: json['environment'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
}
```

### 3. Flutter: Modificar `Environment.config`

**Atualizar**: `lib/core/config/env_config.dart`

```dart
class Environment {
  static AppConfig? _cachedConfig;
  
  /// Inicializa configuração (chamado no main.dart)
  static Future<void> initialize() async {
    // 1. Tenta carregar do storage
    _cachedConfig = AppConfigService.loadFromStorage();
    
    // 2. Se não tiver, busca do backend usando URL inicial
    if (_cachedConfig == null) {
      final initialUrl = _getInitialApiUrl();
      _cachedConfig = await AppConfigService.fetchFromBackend(initialUrl);
      
      if (_cachedConfig != null) {
        await AppConfigService.saveConfig(_cachedConfig!);
      }
    }
    
    // 3. Se ainda não tiver, usa padrão
    _cachedConfig ??= AppConfig(
      apiUrl: 'https://api-hml.h4nd.com.br/api',
      s3BaseUrl: 'https://h4nd-client-hml.s3.us-east-1.amazonaws.com',
    );
  }
  
  static String _getInitialApiUrl() {
    // Pode vir de flavor, variável de ambiente, ou padrão
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'mobile');
    
    if (flavor == 'production') {
      return 'https://api.h4nd.com.br/api';
    }
    
    // Por padrão, usa homologação
    return 'https://api-hml.h4nd.com.br/api';
  }
  
  static EnvConfig get config {
    if (_cachedConfig == null) {
      // Fallback se não inicializou
      return DevConfig();
    }
    
    return _CachedConfig(_cachedConfig!);
  }
}

class _CachedConfig implements EnvConfig {
  final AppConfig _config;
  
  _CachedConfig(this._config);
  
  @override
  String get apiBaseUrl => _config.apiUrl.replaceAll('/api', '');
  
  @override
  String get apiUrl => _config.apiUrl;
  
  @override
  String get s3BaseUrl => _config.s3BaseUrl;
  
  @override
  bool get isProduction => _config.environment == 'Production';
  
  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}
```

### 4. Flutter: Atualizar `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar configuração antes de tudo
  await Environment.initialize();
  
  // ... resto da inicialização
}
```

## 🔄 Fluxo

1. **App inicia** → `Environment.initialize()`
2. **Tenta carregar do storage** → Se tiver, usa
3. **Se não tiver** → Faz chamada para `/api/config` usando URL inicial
4. **Backend retorna config** → Salva no storage e usa
5. **Se falhar** → Usa valores padrão

## ✅ Vantagens

- ✅ Backend controla a configuração
- ✅ App sempre usa URLs corretas do ambiente
- ✅ Funciona offline (usa cache)
- ✅ Pode ser atualizado dinamicamente

## ⚠️ Considerações

1. **URL inicial**: Precisa de uma URL conhecida para primeira chamada
   - Pode ser configurada por flavor
   - Ou usar a mesma lógica do frontend Angular

2. **Cache**: Config fica salva no storage
   - Pode adicionar TTL se necessário
   - Pode forçar refresh em configurações

3. **Segurança**: Endpoint `/api/config` pode ser público (não expõe dados sensíveis)

## 📝 Próximos Passos

1. ✅ Criar endpoint no backend
2. ✅ Adicionar configuração no appsettings
3. ✅ Criar AppConfigService no Flutter
4. ✅ Modificar Environment.config
5. ✅ Atualizar main.dart
6. ✅ Testar em diferentes ambientes

