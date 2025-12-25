# 🔐 Autenticação JWT na Sincronização

## ❓ Problema

Como garantir que as requisições sincronizadas do servidor local para a nuvem sejam autenticadas corretamente?

---

## 🎯 Solução: Mesma Chave JWT (Recomendado)

### **Conceito:**

**Usar a mesma chave secreta (secret) do JWT em ambos os servidores.**

Assim, tokens gerados em um servidor são válidos no outro.

---

## 🔧 Configuração: Mesma Chave JWT

### **appsettings.json - Servidor Nuvem:**

```json
{
  "Jwt": {
    "Secret": "sua-chave-secreta-super-segura-aqui",
    "Issuer": "mx-cloud",
    "Audience": "mx-cloud",
    "ExpirationMinutes": 60
  }
}
```

### **appsettings.Local.json - Servidor Local:**

```json
{
  "Jwt": {
    "Secret": "sua-chave-secreta-super-segura-aqui",  ← MESMA CHAVE
    "Issuer": "mx-cloud",
    "Audience": "mx-cloud",
    "ExpirationMinutes": 60
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com"
  }
}
```

**Importante:** Mesma chave secreta em ambos! ✅

---

## 🔄 Fluxo de Autenticação

### **1. PDV faz login no Servidor Local:**

```
PDV → POST /auth/login
     ↓
Servidor Local:
  - Valida credenciais
  - Gera JWT com secret compartilhado
  - Retorna token para PDV
```

### **2. PDV usa token em requisições:**

```
PDV → POST /pedidos
     Headers: Authorization: Bearer token123
     ↓
Servidor Local:
  - Valida token (usando secret compartilhado)
  - Processa requisição
  - Salva em log_requisicoes (com token original)
```

### **3. Servidor Local sincroniza:**

```
SyncService:
  - Lê log_requisicoes (com token original)
  - Repete requisição na nuvem:
    POST https://api.nuvem.com/pedidos
    Headers: Authorization: Bearer token123  ← MESMO TOKEN
     ↓
Servidor Nuvem:
  - Valida token (usando mesmo secret)
  - Token válido! ✅
  - Processa requisição
```

**Resultado:** Token válido em ambos! ✅

---

## ⚠️ Problema: Token Expirado

### **Cenário:**

```
1. PDV cria pedido às 10:00 (token válido até 11:00)
2. Requisição salva em log_requisicoes
3. Internet cai
4. Volta internet às 11:30
5. SyncService tenta sincronizar
6. Token expirado! ❌
```

### **Solução 1: Refresh Token (Recomendado)**

**Conceito:** Se token expirar, usar refresh token para obter novo token.

#### **Estrutura:**

```sql
CREATE TABLE log_requisicoes (
  id UUID PRIMARY KEY,
  token TEXT NOT NULL,                    -- Access token
  refresh_token TEXT,                     -- Refresh token (se houver)
  metodo VARCHAR(10) NOT NULL,
  endpoint TEXT NOT NULL,
  url_completa TEXT NOT NULL,
  headers JSONB,
  payload JSONB,
  criado_em TIMESTAMP NOT NULL,
  sincronizado BOOLEAN DEFAULT FALSE,
  tentativas INTEGER DEFAULT 0
);
```

#### **Middleware - Salvar Refresh Token:**

```csharp
public class LogRequisicaoMiddleware
{
    public async Task InvokeAsync(HttpContext context)
    {
        // ... código anterior ...
        
        var token = context.Request.Headers["Authorization"].ToString();
        
        // Tentar extrair refresh token (se houver)
        var refreshToken = context.Request.Headers["X-Refresh-Token"].ToString();
        
        var log = new LogRequisicao
        {
            Token = token,
            RefreshToken = refreshToken,  // Salvar também
            // ... resto
        };
        
        // ... salvar log ...
    }
}
```

#### **SyncService - Renovar Token se Expirado:**

```csharp
private async Task RepetirRequisicaoNaNuvem(LogRequisicao log)
{
    var client = new HttpClient();
    
    // Tentar usar token original
    client.DefaultRequestHeaders.Add("Authorization", log.Token);
    
    try
    {
        // Tentar requisição
        var response = await client.PostAsync(url, content);
        
        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            // Token expirado, tentar renovar
            if (!string.IsNullOrEmpty(log.RefreshToken))
            {
                var newToken = await RenovarToken(log.RefreshToken);
                
                // Tentar novamente com novo token
                client.DefaultRequestHeaders.Remove("Authorization");
                client.DefaultRequestHeaders.Add("Authorization", newToken);
                response = await client.PostAsync(url, content);
            }
        }
        
        response.EnsureSuccessStatusCode();
    }
    catch (HttpRequestException ex) when (ex.Message.Contains("401"))
    {
        // Token expirado sem refresh token
        throw new InvalidOperationException("Token expirado e sem refresh token disponível");
    }
}

private async Task<string> RenovarToken(string refreshToken)
{
    var client = new HttpClient();
    var response = await client.PostAsync(
        $"{_apiNuvemUrl}/auth/refresh",
        new StringContent(JsonSerializer.Serialize(new { refreshToken }), 
            Encoding.UTF8, "application/json")
    );
    
    response.EnsureSuccessStatusCode();
    var result = await response.Content.ReadFromJsonAsync<RefreshTokenResponse>();
    return result.AccessToken;
}
```

---

### **Solução 2: Service Account Token (Alternativa)**

**Conceito:** Usar um token de serviço específico para sincronização (não expira ou expira muito depois).

#### **Configuração:**

```json
// appsettings.Local.json
{
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "ServiceAccountToken": "token-de-servico-que-nao-expira"
  }
}
```

#### **SyncService - Usar Service Account:**

```csharp
private async Task RepetirRequisicaoNaNuvem(LogRequisicao log)
{
    var client = new HttpClient();
    
    // Usar service account token (não expira)
    var serviceToken = _config["ApiNuvem:ServiceAccountToken"];
    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {serviceToken}");
    
    // Repetir requisição
    var response = await client.PostAsync(url, content);
    response.EnsureSuccessStatusCode();
}
```

**Vantagem:** Token não expira, sempre funciona

**Desvantagem:** Precisa criar usuário/service account específico

---

### **Solução 3: Validar Token Antes de Sincronizar**

**Conceito:** Verificar se token ainda é válido antes de sincronizar.

#### **SyncService - Validar Token:**

```csharp
private async Task<bool> IsTokenValido(string token)
{
    try
    {
        // Decodificar token (sem validar assinatura ainda)
        var handler = new JwtSecurityTokenHandler();
        var jsonToken = handler.ReadJwtToken(token);
        
        // Verificar expiração
        if (jsonToken.ValidTo < DateTime.UtcNow)
        {
            return false;  // Token expirado
        }
        
        // Verificar se consegue validar na nuvem
        var client = new HttpClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");
        var response = await client.GetAsync($"{_apiNuvemUrl}/auth/validate-token");
        
        return response.IsSuccessStatusCode;
    }
    catch
    {
        return false;
    }
}

private async Task ProcessarLogRequisicoes()
{
    var logs = await db.LogRequisicoes
        .Where(l => !l.Sincronizado)
        .OrderBy(l => l.CriadoEm)
        .ToListAsync();
    
    foreach (var log in logs)
    {
        // Verificar se token ainda é válido
        if (!await IsTokenValido(log.Token))
        {
            // Token expirado, tentar renovar ou marcar erro
            if (!string.IsNullOrEmpty(log.RefreshToken))
            {
                var newToken = await RenovarToken(log.RefreshToken);
                log.Token = newToken;  // Atualizar token
            }
            else
            {
                log.UltimoErro = "Token expirado e sem refresh token";
                log.Tentativas++;
                continue;
            }
        }
        
        // Sincronizar com token válido
        await RepetirRequisicaoNaNuvem(log);
    }
}
```

---

## 🎯 Recomendação: Solução Híbrida

### **Estratégia:**

1. **Mesma chave JWT** em ambos servidores
2. **Salvar refresh token** no log
3. **Renovar token** se expirar durante sincronização
4. **Fallback:** Service account token se refresh falhar

### **Implementação:**

```csharp
private async Task<string> ObterTokenValido(LogRequisicao log)
{
    // 1. Tentar token original
    if (await IsTokenValido(log.Token))
    {
        return log.Token;
    }
    
    // 2. Tentar renovar com refresh token
    if (!string.IsNullOrEmpty(log.RefreshToken))
    {
        try
        {
            var newToken = await RenovarToken(log.RefreshToken);
            log.Token = newToken;  // Atualizar no log
            await _db.SaveChangesAsync();
            return newToken;
        }
        catch
        {
            // Refresh falhou
        }
    }
    
    // 3. Fallback: Service account token
    var serviceToken = _config["ApiNuvem:ServiceAccountToken"];
    if (!string.IsNullOrEmpty(serviceToken))
    {
        return serviceToken;
    }
    
    throw new InvalidOperationException("Não foi possível obter token válido");
}

private async Task RepetirRequisicaoNaNuvem(LogRequisicao log)
{
    var client = new HttpClient();
    
    // Obter token válido (com fallbacks)
    var token = await ObterTokenValido(log);
    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");
    
    // Repetir requisição
    var response = await client.PostAsync(url, content);
    response.EnsureSuccessStatusCode();
}
```

---

## 📋 Resumo: Estratégias

### **1. Mesma Chave JWT** ✅
- Tokens válidos em ambos servidores
- Mais simples
- Requer compartilhar secret

### **2. Refresh Token** ✅
- Renova token se expirar
- Mais robusto
- Requer salvar refresh token no log

### **3. Service Account Token** ✅
- Token que não expira
- Fallback seguro
- Requer criar service account

### **4. Híbrida (Recomendado)** ✅✅✅
- Combina todas as estratégias
- Máxima robustez
- Funciona mesmo se token expirar

---

## 🔧 Implementação Completa Recomendada

### **1. Configuração:**

```json
// appsettings.Local.json
{
  "Jwt": {
    "Secret": "mesma-chave-do-servidor-nuvem"
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "ServiceAccountToken": "token-backup"  // Opcional
  }
}
```

### **2. Log com Refresh Token:**

```csharp
// Salvar refresh token também
var log = new LogRequisicao
{
    Token = accessToken,
    RefreshToken = refreshToken,  // Salvar também
    // ...
};
```

### **3. SyncService com Fallbacks:**

```csharp
// Tentar token original → refresh token → service account
var token = await ObterTokenValido(log);
```

---

## ✅ Resultado Final

**Garantias:**
- ✅ Token válido em ambos servidores (mesma chave)
- ✅ Renovação automática se expirar (refresh token)
- ✅ Fallback seguro (service account)
- ✅ Sincronização sempre funciona

**É isso! Máxima robustez!** 🚀

