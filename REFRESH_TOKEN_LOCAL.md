# 🔐 Refresh Token no Servidor Local

## ✅ Você Está Certo!

### **Pontos Importantes:**

1. **Refresh token fica no banco LOCAL** ✅
   - Não precisa estar no servidor nuvem
   - Refresh é feito localmente
   - Token renovado funciona na nuvem (mesma chave JWT)

2. **Não precisa replicar login** ✅
   - Login não deve ser sincronizado
   - Refresh token pode ser feito localmente
   - Apenas operações de negócio são sincronizadas

3. **Mesma chave JWT = Refresh funciona** ✅
   - Servidor local e nuvem têm mesma chave
   - Token renovado localmente é válido na nuvem
   - Não precisa fazer refresh na nuvem

---

## 🔧 Ajustes Necessários

### **1. Descartar Requisições de Autenticação**

Endpoints que **NÃO devem ser sincronizados:**
- `POST /auth/login` - Login não precisa replicar
- `POST /auth/refresh` - Refresh é feito localmente
- `GET /auth/validate-user` - Validação local
- `GET /auth/me` - Dados do usuário local
- `POST /auth/revoke` - Revogação local

### **2. Refresh Token no Banco Local**

Quando PDV faz login no servidor local:
- Servidor local gera access token e refresh token
- Refresh token é salvo no banco **local** (não nuvem)
- Quando token expira, renovação é feita **localmente**
- Token renovado funciona na nuvem (mesma chave JWT)

---

## 🔄 Fluxo Correto

### **1. PDV faz login no Servidor Local:**

```
PDV → POST /auth/login
     ↓
Servidor Local:
  - Valida credenciais
  - Gera access token (chave local)
  - Gera refresh token
  - Salva refresh token no banco LOCAL
  - Retorna tokens para PDV
```

**Refresh token fica no banco LOCAL!** ✅

### **2. PDV usa token em requisições:**

```
PDV → POST /pedidos
     Headers: Authorization: Bearer token123
     ↓
Servidor Local:
  - Valida token (chave local)
  - Processa requisição
  - Salva em log_requisicoes (com token)
  - NÃO salva refresh token (não vem no header)
```

### **3. Token expira, PDV renova localmente:**

```
PDV → POST /auth/refresh
     Body: { refreshToken: "xxx" }
     ↓
Servidor Local:
  - Valida refresh token (banco LOCAL)
  - Gera novo access token (chave local)
  - Retorna novo token
  - NÃO sincroniza (login/refresh não sincroniza)
```

**Renovação feita localmente!** ✅

### **4. Servidor Local sincroniza pedidos:**

```
SyncService:
  - Lê log_requisicoes
  - Repete POST /pedidos na nuvem
  - Usa access token (válido porque mesma chave)
  - Se token expirar: usa refresh token do log (se houver)
```

---

## 🔧 Implementação: Descartar Requisições de Auth

### **Middleware - Filtrar Endpoints de Auth:**

```csharp
public async Task InvokeAsync(HttpContext context)
{
    // ... código anterior ...
    
    // Ignorar requisições de autenticação (não sincronizar)
    var path = context.Request.Path.Value?.ToLower() ?? "";
    var endpointsAuth = new[]
    {
        "/auth/login",
        "/auth/refresh",
        "/auth/validate-user",
        "/auth/me",
        "/auth/revoke",
        "/auth/health"
    };
    
    if (endpointsAuth.Any(e => path.Contains(e)))
    {
        // Não loga requisições de autenticação
        await _next(context);
        return;
    }
    
    // ... resto do código (loga outras requisições) ...
}
```

---

## 🔄 Refresh Token: Como Funciona

### **Cenário: Token Expira Durante Sincronização**

```
1. PDV cria pedido (token válido)
   → Salvo em log_requisicoes (sem refresh token)

2. Internet cai

3. Token expira

4. Volta internet

5. SyncService tenta sincronizar:
   - Token expirado ❌
   - Não tem refresh token no log ❌
   - O que fazer?
```

### **Solução: Buscar Refresh Token do Banco Local**

Quando precisar renovar token durante sincronização:

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
            // Renovar usando refresh token do banco local
            var newToken = await RenovarTokenLocal(refreshToken);
            return newToken;
        }
    }
    
    // 3. Fallback: Service account token
    var serviceToken = _config["ApiNuvem:ServiceAccountToken"];
    if (!string.IsNullOrEmpty(serviceToken))
    {
        return $"Bearer {serviceToken}";
    }
    
    throw new InvalidOperationException("Não foi possível obter token válido");
}

private async Task<string?> BuscarRefreshTokenLocal(Guid userId)
{
    using var scope = _serviceProvider.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
    
    // Buscar refresh token mais recente do usuário no banco local
    var refreshToken = await db.RefreshTokens
        .Where(rt => rt.UserId == userId && rt.IsActive)
        .OrderByDescending(rt => rt.CreatedAt)
        .FirstOrDefaultAsync();
    
    return refreshToken?.Token;
}

private async Task<string> RenovarTokenLocal(string refreshToken)
{
    // Renovar localmente (mesma chave JWT)
    // Token renovado funciona na nuvem também!
    var apiLocalUrl = _config["ApiLocal:BaseUrl"] ?? "http://localhost:5100";
    
    using var client = new HttpClient();
    var response = await client.PostAsync(
        $"{apiLocalUrl}/auth/refresh",
        new StringContent(
            JsonSerializer.Serialize(new { refreshToken }),
            Encoding.UTF8,
            "application/json"
        )
    );
    
    response.EnsureSuccessStatusCode();
    var result = await response.Content.ReadFromJsonAsync<RefreshTokenResponse>();
    return $"Bearer {result.AccessToken}";
}
```

---

## 📋 Resumo: Refresh Token

### **Onde Fica:**
- ✅ Refresh token no banco **LOCAL**
- ✅ Não precisa estar na nuvem
- ✅ Renovação feita localmente

### **Como Funciona:**
1. PDV faz login → Refresh token salvo no banco local
2. Token expira → Renovação feita localmente
3. Token renovado funciona na nuvem (mesma chave JWT)
4. Sincronização usa token renovado

### **Endpoints Descartados:**
- ✅ `/auth/login` - Não sincroniza
- ✅ `/auth/refresh` - Não sincroniza
- ✅ `/auth/validate-user` - Não sincroniza
- ✅ `/auth/me` - Não sincroniza

### **Endpoints Sincronizados:**
- ✅ `/pedidos` - Sincroniza
- ✅ `/mesas` - Sincroniza
- ✅ `/comandas` - Sincroniza
- ✅ Outras operações de negócio

---

## ✅ Conclusão

**Você está certo!**

1. ✅ Refresh token fica no banco local
2. ✅ Não precisa replicar login
3. ✅ Mesma chave JWT = refresh funciona
4. ✅ Descartar requisições de auth

**Vou ajustar o código para descartar requisições de autenticação!** 🚀
