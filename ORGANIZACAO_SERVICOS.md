# Organização de Serviços - Comunicação com API

## 📋 Estrutura Atual

### ✅ O que já temos:

1. **Core/Network**:
   - `ApiClient` - Cliente HTTP base com Dio
   - `AuthInterceptor` - Adiciona token e X-Company-Id automaticamente
   - `ErrorInterceptor` - Tratamento de erros HTTP
   - `LoggingInterceptor` - Logs em desenvolvimento
   - `ApiEndpoints` - Endpoints centralizados

2. **Core/Auth**:
   - `AuthService` - Serviço de autenticação completo

3. **Data/Models**:
   - Modelos de dados (DTOs) para autenticação

### ⚠️ O que precisa ser melhorado:

1. **Serviços devem estar em `data/services/`** (não em `core/auth/`)
2. **Criar serviço base CRUD** (similar ao Angular)
3. **Organizar serviços por módulo** (Core e Modules)

## 🏗️ Estrutura Proposta

```
lib/
├── core/
│   └── network/
│       ├── api_client.dart          # Cliente HTTP base
│       ├── endpoints.dart           # Endpoints da API
│       └── interceptors/            # Interceptors HTTP
│
├── data/
│   ├── models/                      # DTOs
│   └── services/                    # Serviços de comunicação com API
│       ├── base/
│       │   └── crud_service.dart    # Serviço base CRUD
│       ├── core/
│       │   ├── auth_service.dart    # Autenticação
│       │   ├── pedido_service.dart  # Pedidos
│       │   └── ...
│       └── modules/
│           ├── restaurante/
│           │   ├── mesa_service.dart
│           │   └── ficha_service.dart
│           └── ...
```

## 📝 Padrão Angular (Referência)

No Angular, todos os serviços CRUD estendem `CrudService`:

```typescript
export class CrudService<TDto, TListDto> {
  protected readonly API_URL = environment.apiUrl;
  
  constructor(
    protected http: HttpClient,
    protected resourcePath: string
  ) {}
  
  list(pagination, extraParams): Observable<...> { }
  search(pagination, filter): Observable<...> { }
  getById(id): Observable<...> { }
  create(payload): Observable<...> { }
  update(id, payload): Observable<...> { }
  delete(id): Observable<...> { }
}

// Uso:
export class PedidoService extends CrudService<PedidoDto, PedidoListItemDto> {
  constructor(http: HttpClient) {
    super(http, 'pedidos');
  }
}
```

## 🔄 Próximos Passos

1. Criar `CrudService` base em Flutter
2. Mover `AuthService` para `data/services/core/`
3. Criar outros serviços seguindo o padrão
4. Manter organização por módulos (Core/Modules)


