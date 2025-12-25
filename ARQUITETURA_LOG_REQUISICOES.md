# 🎯 Arquitetura Simplificada: Log de Requisições

## 💡 Ideia Genial: Log Genérico de Tudo

**Conceito:** Salvar **todas as requisições** recebidas em uma tabela de log. Serviço de sync repete essas requisições na nuvem.

**Vantagem:** Zero diferenciação de código! Mesma API, mesma lógica, apenas um log adicional.

---

## 🏗️ Arquitetura Simplificada

```
┌─────────────────────────────────────────┐
│         SERVIDOR LOCAL                  │
│                                         │
│  API .NET (MESMA do servidor)          │
│         ↓                               │
│  Middleware: Log Requisições           │ ← Intercepta TUDO
│         ↓                               │
│  Controller Normal                      │ ← Mesma lógica
│         ↓                               │
│  Salva no Banco Local                   │ ← Normal
│         ↓                               │
│  TAMBÉM salva em log_requisicoes       │ ← Log genérico
│                                         │
│  Serviço Sync (Background)              │
│  Lê log_requisicoes                     │
│  Repete requisições na nuvem            │
└─────────────────────────────────────────┘
```

**Simplicidade:** Zero mudança nos controllers! ✅

---

## 🗄️ Estrutura: Tabela de Log de Requisições

### **Tabela Única:**

```sql
CREATE TABLE log_requisicoes (
  id UUID PRIMARY KEY,
  token TEXT NOT NULL,                    -- Token usado na requisição
  metodo VARCHAR(10) NOT NULL,            -- GET, POST, PUT, DELETE
  endpoint TEXT NOT NULL,                  -- /pedidos, /mesas/123, etc
  url_completa TEXT NOT NULL,              -- URL completa com query params
  headers JSONB,                          -- Todos os headers
  payload JSONB,                          -- Body da requisição (se houver)
  resposta JSONB,                          -- Resposta retornada (opcional)
  criado_em TIMESTAMP NOT NULL,
  sincronizado BOOLEAN DEFAULT FALSE,
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  sincronizado_em TIMESTAMP
);

CREATE INDEX idx_log_sincronizado ON log_requisicoes(sincronizado, criado_em);
```

**Simplicidade:** Uma tabela só! ✅

---

## 🔄 Fluxo Completo

### **1. PDV faz requisição**

```
PDV → POST /pedidos
     Headers: { Authorization: Bearer token123 }
     Body: { tipo: 2, mesaId: "123", itens: [...] }
```

### **2. Middleware intercepta (antes do controller)**

```csharp
public class LogRequisicaoMiddleware
{
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        // Ler requisição
        var request = context.Request;
        var body = await ReadBodyAsync(request);
        
        // Salvar em log
        var log = new LogRequisicao
        {
            Id = Guid.NewGuid(),
            Token = request.Headers["Authorization"].ToString(),
            Metodo = request.Method,
            Endpoint = request.Path.Value,
            UrlCompleta = $"{request.Scheme}://{request.Host}{request.Path}{request.QueryString}",
            Headers = SerializeHeaders(request.Headers),
            Payload = body,
            CriadoEm = DateTime.UtcNow,
            Sincronizado = false
        };
        
        // Salvar no banco (async, não bloqueia)
        _ = Task.Run(async () => await _db.LogRequisicoes.AddAsync(log));
        
        // Continuar para controller normal
        await next(context);
    }
}
```

### **3. Controller executa normalmente**

```csharp
[HttpPost("pedidos")]
public async Task<IActionResult> CriarPedido(CreatePedidoDto dto)
{
    // Lógica NORMAL (mesma do servidor nuvem)
    var pedido = new Pedido { ... };
    _db.Pedidos.Add(pedido);
    await _db.SaveChangesAsync();
    
    return Ok(pedido);
}
```

**Zero mudança!** ✅

### **4. Serviço Sync processa log (background)**

```csharp
public class SyncService
{
    public async Task ProcessarLog()
    {
        if (!await IsOnline()) return;
        
        // Buscar requisições não sincronizadas
        var logs = await _db.LogRequisicoes
            .Where(l => !l.Sincronizado)
            .OrderBy(l => l.CriadoEm)  // Ordem cronológica
            .ToListAsync();
        
        foreach (var log in logs)
        {
            try
            {
                // Repetir requisição na nuvem
                await RepetirRequisicao(log);
                
                // Marcar como sincronizado
                log.Sincronizado = true;
                log.SincronizadoEm = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                log.Tentativas++;
                log.UltimoErro = ex.Message;
            }
            
            await _db.SaveChangesAsync();
        }
    }
    
    private async Task RepetirRequisicao(LogRequisicao log)
    {
        var client = new HttpClient();
        
        // Configurar headers (incluindo token original)
        client.DefaultRequestHeaders.Add("Authorization", log.Token);
        foreach (var header in DeserializeHeaders(log.Headers))
        {
            client.DefaultRequestHeaders.Add(header.Key, header.Value);
        }
        
        // Repetir requisição
        HttpResponseMessage response;
        switch (log.Metodo)
        {
            case "POST":
                response = await client.PostAsync(
                    $"https://api.nuvem.com{log.Endpoint}",
                    new StringContent(log.Payload, Encoding.UTF8, "application/json")
                );
                break;
            case "PUT":
                response = await client.PutAsync(
                    $"https://api.nuvem.com{log.Endpoint}",
                    new StringContent(log.Payload, Encoding.UTF8, "application/json")
                );
                break;
            case "DELETE":
                response = await client.DeleteAsync(
                    $"https://api.nuvem.com{log.Endpoint}"
                );
                break;
            case "GET":
                response = await client.GetAsync(
                    $"https://api.nuvem.com{log.UrlCompleta}"
                );
                break;
        }
        
        response.EnsureSuccessStatusCode();
    }
}
```

---

## 🎯 Vantagens desta Abordagem

### ✅ **Simplicidade Máxima**
- Zero mudança nos controllers
- Zero diferenciação de código
- Mesma lógica em ambos (local e nuvem)

### ✅ **Espelho Completo**
- Salva token original
- Salva URL completa
- Salva headers
- Salva payload
- Reproduz exatamente a requisição

### ✅ **Manutenção Zero**
- Não precisa manter código duplicado
- Mudanças na API refletem automaticamente
- Log é genérico, funciona para tudo

### ✅ **Rastreabilidade Total**
- Log completo de tudo que aconteceu
- Fácil debugar
- Histórico completo

---

## 🔧 Implementação: Middleware

### **Middleware de Log:**

```csharp
public class LogRequisicaoMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IServiceProvider _serviceProvider;
    
    public LogRequisicaoMiddleware(RequestDelegate next, IServiceProvider serviceProvider)
    {
        _next = next;
        _serviceProvider = serviceProvider;
    }
    
    public async Task InvokeAsync(HttpContext context)
    {
        // Ler body (precisa fazer antes de passar para controller)
        context.Request.EnableBuffering();
        var body = await new StreamReader(context.Request.Body).ReadToEndAsync();
        context.Request.Body.Position = 0;  // Resetar para controller ler
        
        // Extrair token
        var token = context.Request.Headers["Authorization"].ToString();
        
        // Criar log
        var log = new LogRequisicao
        {
            Id = Guid.NewGuid(),
            Token = token,
            Metodo = context.Request.Method,
            Endpoint = context.Request.Path.Value,
            UrlCompleta = $"{context.Request.Scheme}://{context.Request.Host}{context.Request.Path}{context.Request.QueryString}",
            Headers = SerializeHeaders(context.Request.Headers),
            Payload = body,
            CriadoEm = DateTime.UtcNow,
            Sincronizado = false
        };
        
        // Salvar em background (não bloqueia requisição)
        _ = Task.Run(async () =>
        {
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            await db.LogRequisicoes.AddAsync(log);
            await db.SaveChangesAsync();
        });
        
        // Continuar para controller
        await _next(context);
    }
    
    private string SerializeHeaders(IHeaderDictionary headers)
    {
        var dict = headers.ToDictionary(h => h.Key, h => h.Value.ToString());
        return JsonSerializer.Serialize(dict);
    }
}
```

### **Registrar no Program.cs:**

```csharp
var builder = WebApplication.CreateBuilder(args);

// ... configurações normais

var app = builder.Build();

// Registrar middleware (antes de controllers)
app.UseMiddleware<LogRequisicaoMiddleware>();

app.UseAuthorization();
app.MapControllers();
app.Run();
```

---

## 🔄 Serviço de Sincronização

### **Serviço Background:**

```csharp
public class SyncService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _config;
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessarLog();
            }
            catch (Exception ex)
            {
                // Log erro
            }
            
            // Aguardar 30 segundos
            await Task.Delay(30000, stoppingToken);
        }
    }
    
    private async Task ProcessarLog()
    {
        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        
        // Verificar se está online
        if (!await IsOnline()) return;
        
        // Buscar logs não sincronizados (ordem cronológica)
        var logs = await db.LogRequisicoes
            .Where(l => !l.Sincronizado && l.Tentativas < 5)
            .OrderBy(l => l.CriadoEm)
            .Take(10)  // Processar em lotes
            .ToListAsync();
        
        foreach (var log in logs)
        {
            try
            {
                await RepetirRequisicao(log);
                
                log.Sincronizado = true;
                log.SincronizadoEm = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                log.Tentativas++;
                log.UltimoErro = ex.Message;
            }
            
            await db.SaveChangesAsync();
        }
    }
    
    private async Task RepetirRequisicao(LogRequisicao log)
    {
        var apiUrl = _config["ApiNuvem:BaseUrl"];
        var client = new HttpClient();
        
        // Configurar token original
        client.DefaultRequestHeaders.Add("Authorization", log.Token);
        
        // Repetir headers (exceto Authorization que já foi)
        var headers = JsonSerializer.Deserialize<Dictionary<string, string>>(log.Headers);
        foreach (var header in headers.Where(h => h.Key != "Authorization"))
        {
            client.DefaultRequestHeaders.TryAddWithoutValidation(header.Key, header.Value);
        }
        
        // Repetir requisição
        HttpResponseMessage response;
        var url = $"{apiUrl}{log.Endpoint}";
        
        switch (log.Metodo)
        {
            case "POST":
                var postContent = new StringContent(log.Payload ?? "{}", Encoding.UTF8, "application/json");
                response = await client.PostAsync(url, postContent);
                break;
            case "PUT":
                var putContent = new StringContent(log.Payload ?? "{}", Encoding.UTF8, "application/json");
                response = await client.PutAsync(url, putContent);
                break;
            case "DELETE":
                response = await client.DeleteAsync(url);
                break;
            case "GET":
                response = await client.GetAsync(log.UrlCompleta.Replace("http://localhost", apiUrl));
                break;
            default:
                throw new NotSupportedException($"Método {log.Metodo} não suportado");
        }
        
        response.EnsureSuccessStatusCode();
    }
    
    private async Task<bool> IsOnline()
    {
        try
        {
            var apiUrl = _config["ApiNuvem:BaseUrl"];
            var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var response = await client.GetAsync($"{apiUrl}/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
```

### **Registrar no Program.cs:**

```csharp
// Registrar como serviço background
builder.Services.AddHostedService<SyncService>();
```

---

## 📊 Exemplo Prático

### **Cenário: PDV cria pedido**

```
1. PDV → POST /pedidos
   Headers: Authorization: Bearer token123
   Body: { tipo: 2, mesaId: "123" }

2. Middleware intercepta:
   - Salva em log_requisicoes
   - Token: "Bearer token123"
   - Método: "POST"
   - Endpoint: "/pedidos"
   - Payload: { tipo: 2, mesaId: "123" }

3. Controller executa normalmente:
   - Cria pedido no banco local
   - Retorna resposta

4. Serviço Sync (background):
   - Lê log_requisicoes
   - Repete: POST https://api.nuvem.com/pedidos
   - Headers: Authorization: Bearer token123
   - Body: { tipo: 2, mesaId: "123" }
   - Marca como sincronizado ✅
```

**Simplicidade:** Zero mudança no controller! ✅

---

## 🎯 Vantagens Finais

### ✅ **Zero Diferenciação**
- Mesma API, mesma lógica
- Mesmos controllers
- Mesmos services
- Apenas middleware adicional

### ✅ **Espelho Perfeito**
- Salva token original
- Salva URL completa
- Salva headers
- Salva payload
- Reproduz exatamente

### ✅ **Manutenção Zero**
- Não precisa manter código duplicado
- Mudanças refletem automaticamente
- Log genérico funciona para tudo

### ✅ **Rastreabilidade**
- Log completo de tudo
- Fácil debugar
- Histórico completo

---

## 🎉 Conclusão

**Solução Genial:**

1. **Middleware intercepta tudo** → Salva em log
2. **Controller executa normalmente** → Zero mudança
3. **Serviço sync repete requisições** → Na ordem cronológica

**Resultado:**
- ✅ Mesma API, mesma lógica
- ✅ Zero diferenciação de código
- ✅ Espelho completo (token, headers, payload)
- ✅ Simplicidade máxima

**É isso! Muito mais simples e elegante!** 🚀
