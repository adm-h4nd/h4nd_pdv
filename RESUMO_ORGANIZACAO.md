# Resumo da Organização de Serviços

## ✅ Estrutura Implementada

### 1. **Core/Network** (Infraestrutura HTTP)
```
lib/core/network/
├── api_client.dart          # Cliente HTTP base com Dio
├── endpoints.dart           # Endpoints centralizados da API
└── interceptors/
    ├── auth_interceptor.dart    # Adiciona token + X-Company-Id
    ├── error_interceptor.dart   # Tratamento de erros HTTP
    └── logging_interceptor.dart # Logs (dev only)
```

### 2. **Data/Services** (Serviços de API)
```
lib/data/services/
├── base/
│   └── crud_service.dart    # Serviço base CRUD (similar ao Angular)
└── core/
    └── auth_service.dart    # Serviço de autenticação
```

### 3. **Data/Models** (DTOs)
```
lib/data/models/
├── core/
│   ├── api_response.dart        # Resposta padrão da API
│   └── paginated_response.dart  # Resposta paginada
└── auth/
    ├── login_request.dart
    ├── login_response.dart
    ├── refresh_token_request.dart
    ├── refresh_token_response.dart
    ├── user.dart
    └── empresa.dart
```

## 🔄 Como Funciona

### 1. **ApiClient**
- Cliente HTTP único usando Dio
- Configurado com base URL, timeouts
- Interceptors adicionados automaticamente

### 2. **Interceptors**
- **AuthInterceptor**: Adiciona `Authorization: Bearer {token}` e `X-Company-Id: {empresaId}` em todas as requisições
- **ErrorInterceptor**: Converte erros HTTP em mensagens amigáveis
- **LoggingInterceptor**: Logs detalhados em desenvolvimento

### 3. **AuthService**
- Localizado em `data/services/core/` (seguindo padrão Angular)
- Gerencia autenticação completa:
  - Login
  - Logout
  - Refresh token automático
  - Gerenciamento de empresas
  - Armazenamento seguro de tokens

### 4. **CrudService Base**
- Classe abstrata para serviços CRUD
- Métodos padrão: `list`, `search`, `getById`, `create`, `update`, `delete`
- Classes filhas implementam `fromJson` e `fromListJson`

## 📝 Exemplo de Uso Futuro

```dart
// Criar um serviço de pedidos
class PedidoService extends CrudService<PedidoDto, PedidoListItemDto> {
  PedidoService(ApiClient apiClient) : super(
    apiClient: apiClient,
    resourcePath: 'pedidos',
  );

  @override
  PedidoDto fromJson(Map<String, dynamic> json) => PedidoDto.fromJson(json);

  @override
  PedidoListItemDto fromListJson(Map<String, dynamic> json) => 
    PedidoListItemDto.fromJson(json);

  // Métodos específicos além do CRUD
  Future<ApiResponse<List<PedidoDto>>> getByMesa(String mesaId) async {
    // Implementação específica
  }
}
```

## ✅ Vantagens desta Organização

1. **Separação de Responsabilidades**: 
   - Core = Infraestrutura
   - Data = Comunicação com API
   - Presentation = UI

2. **Reutilização**: 
   - CrudService base elimina código duplicado
   - Interceptors aplicados automaticamente

3. **Manutenibilidade**: 
   - Estrutura similar ao Angular facilita manutenção
   - Endpoints centralizados

4. **Testabilidade**: 
   - Serviços isolados e testáveis
   - Fácil mockar ApiClient

## 🔄 Próximos Passos

1. Criar serviços específicos (PedidoService, MesaService, etc.)
2. Todos estendendo CrudService quando aplicável
3. Organizar em `data/services/core/` e `data/services/modules/`


