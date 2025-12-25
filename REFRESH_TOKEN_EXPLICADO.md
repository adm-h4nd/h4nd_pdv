# 🔐 Refresh Token: Como Funciona no Servidor Local

## ✅ Você Estava Certo!

### **Pontos Corretos:**

1. ✅ **Refresh token fica no banco LOCAL**
   - Não precisa estar no servidor nuvem
   - Refresh é feito localmente
   - Token renovado funciona na nuvem (mesma chave JWT)

2. ✅ **Não precisa replicar login**
   - Login não é sincronizado
   - Refresh não é sincronizado
   - Apenas operações de negócio são sincronizadas

3. ✅ **Mesma chave JWT = Refresh funciona**
   - Servidor local e nuvem têm mesma chave
   - Token renovado localmente é válido na nuvem
   - Não precisa fazer refresh na nuvem

---

## 🔄 Fluxo Completo

### **1. PDV faz login no Servidor Local:**

```
PDV → POST /auth/login
     ↓
Servidor Local:
  - Valida credenciais
  - Gera access token (chave local)
  - Gera refresh token
  - Salva refresh token no banco LOCAL (RefreshTokens)
  - Retorna tokens para PDV
```

**Refresh token salvo no banco LOCAL!** ✅

### **2. PDV cria pedido:**

```
PDV → POST /pedidos
     Headers: Authorization: Bearer token123
     ↓
Servidor Local:
  - Valida token (chave local)
  - Processa requisição
  - Salva em log_requisicoes (apenas access token)
  - NÃO salva refresh token (não vem no header)
```

**Apenas access token é salvo no log!** ✅

### **3. Token expira, PDV renova localmente:**

```
PDV → POST /auth/refresh
     Body: { refreshToken: "xxx" }
     ↓
Servidor Local:
  - Valida refresh token (banco LOCAL)
  - Gera novo access token (chave local)
  - Retorna novo token
  - NÃO sincroniza (refresh não é sincronizado)
```

**Renovação feita localmente!** ✅

### **4. Servidor Local sincroniza pedidos:**

```
SyncService:
  - Lê log_requisicoes
  - Tenta repetir POST /pedidos na nuvem
  - Token expirado? ❌
     ↓
  - Extrai userId do token expirado
  - Busca refresh token do banco LOCAL
  - Renova token localmente
  - Token renovado funciona na nuvem (mesma chave!)
  - Repete requisição com token renovado ✅
```

---

## 🔧 Implementação

### **1. Middleware - Descartar Requisições de Auth:**

```csharp
// Endpoints que NÃO são sincronizados
var endpointsAuth = new[]
{
    "/auth/login",
    "/auth/refresh",
    "/auth/validate-user",
    "/auth/me",
    "/auth/revoke"
};

if (endpointsAuth.Any(e => path.Contains(e)))
{
    // Não loga essas requisições
    await _next(context);
    return;
}
```

### **2. SyncService - Buscar Refresh Token do Banco Local:**

```csharp
private async Task<string> ObterTokenValido(LogRequisicao log)
{
    // 1. Tentar token original
    if (await IsTokenValido(log.Token))
    {
        return log.Token;
    }
    
    // 2. Token expirado, buscar refresh token do banco LOCAL
    var userId = ExtrairUserIdDoToken(log.Token);
    if (userId != null)
    {
        var refreshToken = await BuscarRefreshTokenLocal(userId);
        if (refreshToken != null)
        {
            // Renovar localmente (mesma chave JWT)
            var newToken = await RenovarTokenLocal(refreshToken);
            return newToken;  // Funciona na nuvem também!
        }
    }
    
    // 3. Fallback: Service account token
    ...
}
```

### **3. Buscar Refresh Token do Banco Local:**

```csharp
private async Task<string?> BuscarRefreshTokenLocal(Guid userId)
{
    using var scope = _serviceProvider.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
    
    // Buscar refresh token mais recente do usuário no banco LOCAL
    var refreshToken = await db.RefreshTokens
        .Where(rt => rt.UsuarioId == userId && rt.IsActive)
        .OrderByDescending(rt => rt.CreatedAt)
        .FirstOrDefaultAsync();
    
    return refreshToken?.Token;
}
```

### **4. Renovar Token Localmente:**

```csharp
private async Task<string> RenovarTokenLocal(string refreshToken)
{
    // Renovar localmente (mesma chave JWT)
    // Token renovado funciona na nuvem também!
    var apiLocalUrl = "http://localhost:5100";
    
    var response = await client.PostAsync(
        $"{apiLocalUrl}/api/auth/refresh",
        new StringContent(JsonSerializer.Serialize(new { refreshToken }), ...)
    );
    
    var result = await response.Content.ReadFromJsonAsync<RefreshTokenResponse>();
    return $"Bearer {result.AccessToken}";
}
```

---

## 📋 Resumo: O que Foi Ajustado

### **1. Middleware:**
- ✅ Descartar requisições de `/auth/*`
- ✅ Não salvar refresh token no log
- ✅ Apenas salvar access token

### **2. SyncService:**
- ✅ Buscar refresh token do banco LOCAL quando necessário
- ✅ Renovar token localmente
- ✅ Token renovado funciona na nuvem (mesma chave)

### **3. Modelo LogRequisicao:**
- ✅ Removido campo `RefreshToken` (não precisa)
- ✅ Apenas `Token` (access token)

---

## ✅ Resultado Final

### **Refresh Token:**
- ✅ Fica no banco LOCAL (tabela `RefreshTokens`)
- ✅ Renovação feita localmente
- ✅ Token renovado funciona na nuvem (mesma chave JWT)

### **Sincronização:**
- ✅ Busca refresh token do banco local quando necessário
- ✅ Renova localmente
- ✅ Usa token renovado para sincronizar

### **Endpoints Descartados:**
- ✅ `/auth/login` - Não sincroniza
- ✅ `/auth/refresh` - Não sincroniza
- ✅ `/auth/validate-user` - Não sincroniza
- ✅ `/auth/me` - Não sincroniza

**Perfeito! Agora está correto!** 🚀
