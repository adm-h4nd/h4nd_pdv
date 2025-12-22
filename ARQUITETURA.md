# Arquitetura MX Cloud PDV - Flutter

## 📋 Visão Geral

Sistema PDV multi-segmento desenvolvido em Flutter para uso em:
- **POS (Point of Sale)**: Stone, GetNet, PagSeguro
- **Dispositivos móveis**: Celulares e tablets Android/iOS
- **Dispositivos integrados**: Máquinas de pagamento Android conectadas

## 🏗️ Arquitetura

### Princípios Fundamentais

1. **SOLID**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
2. **Clean Architecture**: Separação clara de camadas (Domain, Data, Presentation)
3. **Repository Pattern**: Abstração de acesso a dados
4. **Dependency Injection**: Inversão de dependências usando `provider` ou `get_it`
5. **State Management**: Provider para gerenciamento de estado reativo
6. **Adaptive Design**: Interface adaptável para diferentes tamanhos de tela e dispositivos

### Estrutura de Pastas

```
lib/
├── core/                          # Funcionalidades core do sistema
│   ├── config/                    # Configurações (API URLs, etc)
│   ├── constants/                 # Constantes do sistema
│   ├── errors/                    # Tratamento de erros
│   ├── network/                   # Cliente HTTP, interceptors
│   ├── storage/                   # Armazenamento local (SharedPreferences, Hive)
│   ├── theme/                     # Temas e estilos
│   └── utils/                     # Utilitários gerais
│
├── data/                          # Camada de dados
│   ├── datasources/               # Fontes de dados (API, Local)
│   │   ├── remote/                # API remota
│   │   └── local/                  # Armazenamento local
│   ├── models/                    # Modelos de dados (DTOs)
│   ├── repositories/              # Implementação dos repositórios
│   └── services/                  # Serviços de dados
│
├── domain/                        # Camada de domínio (lógica de negócio)
│   ├── entities/                  # Entidades de domínio
│   ├── repositories/              # Interfaces dos repositórios
│   ├── usecases/                  # Casos de uso
│   └── value_objects/             # Objetos de valor
│
├── presentation/                  # Camada de apresentação
│   ├── providers/                 # Providers (State Management)
│   ├── screens/                   # Telas da aplicação
│   ├── widgets/                   # Widgets reutilizáveis
│   └── routes/                    # Rotas e navegação
│
└── main.dart                      # Entry point
```

## 🔐 Autenticação e Segurança

### Fluxo de Autenticação

1. **Login**: Usuário faz login → recebe `token` (JWT) e `refreshToken`
2. **Armazenamento**: Tokens salvos em `SecureStorage` (criptografado)
3. **Validação**: Verifica expiração do JWT antes de cada requisição
4. **Refresh Automático**: Se JWT expirado, usa `refreshToken` para renovar
5. **Logout**: Revoga `refreshToken` no servidor e limpa dados locais

### Estrutura de Autenticação

```
core/
└── auth/
    ├── auth_service.dart          # Serviço de autenticação
    ├── auth_provider.dart         # Provider para estado de auth
    ├── token_manager.dart         # Gerenciamento de tokens
    └── auth_interceptor.dart      # Interceptor HTTP para adicionar token
```

### Funcionalidades

- ✅ Login com email/senha
- ✅ Refresh token automático
- ✅ Validação de expiração de tokens
- ✅ Logout com revogação de token
- ✅ Armazenamento seguro de credenciais
- ✅ Interceptor HTTP para adicionar token automaticamente
- ✅ Tratamento de erros de autenticação

## 🌐 Network Layer

### Cliente HTTP

- **Base URL**: Configurável via environment
- **Interceptors**: 
  - Auth Interceptor (adiciona token)
  - Error Interceptor (tratamento de erros)
  - Logging Interceptor (debug)
- **Timeout**: Configurável
- **Retry Logic**: Para requisições falhadas

### Estrutura

```
core/network/
├── api_client.dart                # Cliente HTTP base
├── interceptors/
│   ├── auth_interceptor.dart      # Adiciona token nas requisições
│   ├── error_interceptor.dart     # Trata erros HTTP
│   └── logging_interceptor.dart   # Logs de requisições
└── endpoints.dart                 # Endpoints da API
```

## 💾 Storage Layer

### Armazenamento Local

- **SecureStorage**: Para tokens e dados sensíveis (criptografado)
- **SharedPreferences**: Para configurações e preferências
- **Hive** (opcional): Para cache de dados complexos

### Estrutura

```
core/storage/
├── secure_storage_service.dart    # Armazenamento seguro
├── preferences_service.dart       # SharedPreferences wrapper
└── storage_keys.dart              # Chaves de armazenamento
```

## 📱 Presentation Layer

### State Management

- **Provider**: Para gerenciamento de estado reativo
- **ChangeNotifier**: Para providers que precisam notificar mudanças
- **FutureProvider**: Para dados assíncronos

### Navegação

- **GoRouter** ou **Navigator 2.0**: Para navegação declarativa
- **Route Guards**: Para proteger rotas que requerem autenticação

### Estrutura de Telas

```
presentation/screens/
├── auth/
│   ├── login_screen.dart
│   └── splash_screen.dart
├── home/
│   └── home_screen.dart
└── ...
```

## 🎨 UI/UX

### Design System

- **Material Design 3**: Design system base
- **Adaptive Layout**: Responsivo para diferentes tamanhos
- **Dark Mode**: Suporte a tema escuro
- **Acessibilidade**: Suporte a leitores de tela

### Componentes Reutilizáveis

```
presentation/widgets/
├── common/                        # Widgets comuns
│   ├── buttons/
│   ├── inputs/
│   ├── cards/
│   └── dialogs/
├── adaptive/                      # Widgets adaptativos
└── ...
```

## 🔧 Configuração e Environment

### Environments

- **Development**: `lib/core/config/env_dev.dart`
- **Production**: `lib/core/config/env_prod.dart`
- **Staging**: `lib/core/config/env_staging.dart`

### Configurações

- API Base URL
- Timeout de requisições
- Configurações de storage
- Feature flags

## 🧪 Testes

### Estrutura de Testes

```
test/
├── unit/                          # Testes unitários
├── widget/                        # Testes de widgets
└── integration/                  # Testes de integração
```

## 📦 Dependências Principais

```yaml
dependencies:
  # State Management
  provider: ^6.1.1
  
  # Network
  http: ^1.1.0
  dio: ^5.4.0                    # Cliente HTTP avançado
  
  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # Navigation
  go_router: ^13.0.0
  
  # Utils
  intl: ^0.19.0
  json_annotation: ^4.8.1
  
  # UI
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  
dev_dependencies:
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

## 🚀 Próximos Passos

1. ✅ Estrutura base de pastas
2. ✅ Configuração de environment
3. ✅ Cliente HTTP com interceptors
4. ✅ Serviço de autenticação
5. ✅ Tela de login
6. ✅ Tela de splash com verificação de auth
7. ✅ Navegação protegida
8. ✅ Refresh token automático

## 📝 Convenções de Código

- **Naming**: camelCase para variáveis, PascalCase para classes
- **Imports**: Organizados por tipo (dart, flutter, packages, local)
- **Comentários**: Documentação em português
- **Error Handling**: Sempre tratar erros explicitamente
- **Null Safety**: Usar null safety do Dart



