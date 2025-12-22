# Atualização - Gerenciamento de Empresas

## ✅ Implementado

### 1. Modelo de Empresa
- ✅ Criado `Empresa` model em `lib/data/models/auth/empresa.dart`
- ✅ Métodos `fromJson` e `toJson` para serialização

### 2. AuthService - Gerenciamento de Empresas
- ✅ `_getEmpresasFromToken()` - Extrai empresas do JWT
- ✅ `_saveEmpresas()` - Salva empresas no storage
- ✅ `getEmpresas()` - Obtém lista de empresas disponíveis
- ✅ `getSelectedEmpresa()` - Obtém empresa selecionada
- ✅ `setSelectedEmpresa()` - Define empresa selecionada
- ✅ `hasMultipleEmpresas()` - Verifica se tem múltiplas empresas
- ✅ `ensureEmpresasFromTokenCache()` - Garante cache de empresas

### 3. Interceptor - Header X-Company-Id
- ✅ `AuthInterceptor` atualizado para adicionar `X-Company-Id` automaticamente
- ✅ Header adicionado em todas as requisições quando há empresa selecionada
- ✅ Header também adicionado após refresh token

### 4. Storage
- ✅ Empresas salvas em `PreferencesService` (não sensível)
- ✅ Empresa selecionada salva em `PreferencesService`
- ✅ Empresas extraídas do JWT no login
- ✅ Primeira empresa selecionada automaticamente no login

## 🔄 Fluxo de Funcionamento

1. **Login**:
   - Usuário faz login
   - Empresas são extraídas do JWT (campo `empresas`)
   - Empresas são salvas no storage
   - Primeira empresa é selecionada automaticamente

2. **Requisições HTTP**:
   - Interceptor adiciona `Authorization: Bearer {token}`
   - Interceptor adiciona `X-Company-Id: {empresaId}` se houver empresa selecionada
   - Todas as requisições incluem ambos os headers

3. **Refresh Token**:
   - Quando o token é renovado, o header `X-Company-Id` é mantido
   - Empresas são recarregadas do novo token se necessário

## 📝 Notas

- Empresas vêm do JWT como uma string JSON no campo `empresas`
- A empresa selecionada é persistida entre sessões
- Se não houver empresa selecionada, o header `X-Company-Id` não é enviado
- O backend usa o header `X-Company-Id` para filtrar dados por empresa

## 🔍 Compatibilidade com Frontend Angular

A implementação está 100% compatível com o frontend Angular:
- Mesmo header `X-Company-Id`
- Mesma lógica de extração de empresas do JWT
- Mesma seleção automática da primeira empresa
- Mesmo armazenamento de empresas e empresa selecionada



