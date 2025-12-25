# 📍 Onde Fica o Serviço de Sincronização?

## ✅ Resposta: Na Mesma API do Servidor Local

O serviço de sincronização fica **dentro da mesma API** do servidor local, como um **Background Service** (Hosted Service) do ASP.NET Core.

---

## 🏗️ Estrutura do Projeto

```
MXCloud.API/                    ← MESMA API (serve local e nuvem)
├── Controllers/
│   ├── PedidosController.cs   ← Endpoints normais
│   ├── MesasController.cs
│   └── ...
├── Middleware/
│   └── LogRequisicaoMiddleware.cs  ← Intercepta requisições
├── Services/
│   ├── PedidoService.cs        ← Services normais
│   └── SyncService.cs          ← Background Service (aqui!)
├── Data/
│   ├── MXCloudDbContext.cs     ← DbContext nuvem
│   └── LocalDbContext.cs       ← DbContext local (com log_requisicoes)
└── Program.cs                  ← Registra tudo
```

**Simplicidade:** Tudo na mesma API! ✅

---

## 🔧 Implementação: Background Service

### **SyncService.cs:**

```csharp
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;

namespace MXCloud.API.Services;

public class SyncService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _config;
    private readonly ILogger<SyncService> _logger;
    
    public SyncService(
        IServiceProvider serviceProvider,
        IConfiguration config,
        ILogger<SyncService> logger)
    {
        _serviceProvider = serviceProvider;
        _config = config;
        _logger = logger;
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Serviço de sincronização iniciado");
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessarLogRequisicoes();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Erro ao processar sincronização");
            }
            
            // Aguardar 30 segundos antes de próxima execução
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }
    
    private async Task ProcessarLogRequisicoes()
    {
        // Criar scope para acessar DbContext
        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<LocalDbContext>();
        
        // Verificar se está online
        if (!await IsOnline())
        {
            _logger.LogDebug("Servidor offline, aguardando...");
            return;
        }
        
        // Buscar requisições não sincronizadas (ordem cronológica)
        var logs = await db.LogRequisicoes
            .Where(l => !l.Sincronizado && l.Tentativas < 5)
            .OrderBy(l => l.CriadoEm)
            .Take(10)  // Processar em lotes
            .ToListAsync();
        
        if (!logs.Any())
        {
            return;  // Nada para sincronizar
        }
        
        _logger.LogInformation($"Processando {logs.Count} requisições pendentes");
        
        foreach (var log in logs)
        {
            try
            {
                await RepetirRequisicaoNaNuvem(log);
                
                log.Sincronizado = true;
                log.SincronizadoEm = DateTime.UtcNow;
                log.Tentativas = 0;
                
                _logger.LogInformation($"Requisição {log.Id} sincronizada com sucesso");
            }
            catch (Exception ex)
            {
                log.Tentativas++;
                log.UltimoErro = ex.Message;
                
                _logger.LogWarning($"Erro ao sincronizar requisição {log.Id}: {ex.Message}");
            }
            
            await db.SaveChangesAsync();
            
            // Pequeno delay entre requisições
            await Task.Delay(100);
        }
    }
    
    private async Task RepetirRequisicaoNaNuvem(LogRequisicao log)
    {
        var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
        if (string.IsNullOrEmpty(apiNuvemUrl))
        {
            throw new InvalidOperationException("ApiNuvem:BaseUrl não configurada");
        }
        
        using var client = new HttpClient();
        
        // Configurar token original
        if (!string.IsNullOrEmpty(log.Token))
        {
            client.DefaultRequestHeaders.Add("Authorization", log.Token);
        }
        
        // Repetir outros headers (se houver)
        if (log.Headers != null)
        {
            var headers = JsonSerializer.Deserialize<Dictionary<string, string>>(log.Headers);
            foreach (var header in headers.Where(h => h.Key != "Authorization"))
            {
                client.DefaultRequestHeaders.TryAddWithoutValidation(header.Key, header.Value);
            }
        }
        
        // Construir URL completa
        var url = $"{apiNuvemUrl}{log.Endpoint}";
        if (log.UrlCompleta.Contains("?"))
        {
            var queryString = log.UrlCompleta.Split('?')[1];
            url += $"?{queryString}";
        }
        
        // Repetir requisição
        HttpResponseMessage response;
        switch (log.Metodo.ToUpper())
        {
            case "POST":
                var postContent = new StringContent(
                    log.Payload ?? "{}",
                    Encoding.UTF8,
                    "application/json"
                );
                response = await client.PostAsync(url, postContent);
                break;
                
            case "PUT":
                var putContent = new StringContent(
                    log.Payload ?? "{}",
                    Encoding.UTF8,
                    "application/json"
                );
                response = await client.PutAsync(url, putContent);
                break;
                
            case "DELETE":
                response = await client.DeleteAsync(url);
                break;
                
            case "GET":
                response = await client.GetAsync(url);
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
            var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
            if (string.IsNullOrEmpty(apiNuvemUrl))
            {
                return false;
            }
            
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var response = await client.GetAsync($"{apiNuvemUrl}/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
```

---

## 🔧 Registro no Program.cs

### **Program.cs:**

```csharp
var builder = WebApplication.CreateBuilder(args);

// ... outras configurações

// Registrar serviços normais
builder.Services.AddControllers();
builder.Services.AddDbContext<MXCloudDbContext>(...);
builder.Services.AddDbContext<LocalDbContext>(...);

// Registrar Background Service de sincronização
builder.Services.AddHostedService<SyncService>();

var app = builder.Build();

// Registrar middleware de log
app.UseMiddleware<LogRequisicaoMiddleware>();

app.UseAuthorization();
app.MapControllers();
app.Run();
```

**Simplicidade:** Apenas uma linha para registrar! ✅

---

## 🎯 Como Funciona

### **1. API Inicia:**

```
Program.cs → builder.Services.AddHostedService<SyncService>()
           ↓
    SyncService inicia automaticamente
           ↓
    Roda em background (thread separada)
           ↓
    Processa log a cada 30 segundos
```

### **2. Requisição Chega:**

```
PDV → Requisição
     ↓
Middleware → Salva em log_requisicoes
     ↓
Controller → Processa normalmente
     ↓
Resposta → PDV
```

### **3. Sync Service (Background):**

```
SyncService (rodando em background):
  ↓
A cada 30 segundos:
  ↓
Lê log_requisicoes (não sincronizados)
  ↓
Repete cada requisição na nuvem
  ↓
Marca como sincronizado
```

---

## ⚙️ Configuração

### **appsettings.json:**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=mx_cloud_local;..."
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx"
  },
  "Sync": {
    "IntervalSeconds": 30,
    "BatchSize": 10,
    "MaxRetries": 5
  }
}
```

### **Usar configuração no SyncService:**

```csharp
private async Task ProcessarLogRequisicoes()
{
    var intervalSeconds = _config.GetValue<int>("Sync:IntervalSeconds", 30);
    var batchSize = _config.GetValue<int>("Sync:BatchSize", 10);
    var maxRetries = _config.GetValue<int>("Sync:MaxRetries", 5);
    
    // ... usar nas queries
    var logs = await db.LogRequisicoes
        .Where(l => !l.Sincronizado && l.Tentativas < maxRetries)
        .OrderBy(l => l.CriadoEm)
        .Take(batchSize)
        .ToListAsync();
}
```

---

## 🎯 Vantagens de Ficar na Mesma API

### ✅ **Simplicidade**
- Tudo em um lugar
- Fácil de manter
- Não precisa de comunicação entre serviços

### ✅ **Acesso Direto ao Banco**
- Acessa `log_requisicoes` diretamente
- Não precisa de API adicional
- Performance melhor

### ✅ **Mesmo Processo**
- Compartilha configurações
- Compartilha DbContext
- Compartilha serviços

### ✅ **Fácil de Debugar**
- Logs no mesmo lugar
- Fácil de monitorar
- Fácil de testar

---

## 🔄 Alternativa: Serviço Separado (Não Recomendado)

### **Se fosse separado:**

```
Servidor Local:
├── API (recebe requisições)
└── Serviço Sync (processa log)
    └── Precisa acessar mesmo banco
    └── Precisa comunicação entre processos
    └── Mais complexo
```

**Desvantagens:**
- ❌ Mais complexo
- ❌ Precisa comunicação entre processos
- ❌ Duplicação de configurações
- ❌ Mais difícil de manter

**Não vale a pena!** ✅

---

## 📋 Resumo

### **Onde fica:**
- ✅ **Na mesma API** do servidor local
- ✅ Como **Background Service** (Hosted Service)
- ✅ Roda **automaticamente** quando API inicia
- ✅ Processa em **background** (não bloqueia API)

### **Como registrar:**
```csharp
builder.Services.AddHostedService<SyncService>();
```

### **Como funciona:**
- Roda em thread separada
- Processa log a cada 30 segundos
- Repete requisições na nuvem
- Marca como sincronizado

**É isso! Simples e eficiente!** 🚀

