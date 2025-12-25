# 🔧 Condicional: Servidor Local vs Nuvem

## 🎯 Problema

O middleware de log e o serviço de sincronização **só devem rodar no servidor LOCAL**, não no servidor NUVEM.

---

## ✅ Solução: Flag de Configuração

Usar uma flag de configuração para diferenciar servidor local de nuvem.

---

## 🔧 Configuração por Ambiente

### **appsettings.Local.json (Servidor Local):**

```json
{
  "IsLocal": true,
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=mx_cloud_local;..."
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx"
  }
}
```

### **appsettings.Production.json (Servidor Nuvem):**

```json
{
  "IsLocal": false,
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Database=mx_cloud;..."
  }
}
```

---

## 🔧 Program.cs - Condicional

### **Program.cs:**

```csharp
var builder = WebApplication.CreateBuilder(args);

// ... outras configurações

builder.Services.AddControllers();
builder.Services.AddDbContext<MXCloudDbContext>(...);

// Verificar se é servidor local
var isLocal = builder.Configuration.GetValue<bool>("IsLocal", false);

if (isLocal)
{
    // Apenas no servidor LOCAL:
    
    // 1. Registrar DbContext local (com log_requisicoes)
    builder.Services.AddDbContext<LocalDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
    
    // 2. Registrar serviço de sincronização
    builder.Services.AddHostedService<SyncService>();
    
    // 3. Registrar middleware de log (será usado depois)
    builder.Services.AddScoped<LogRequisicaoMiddleware>();
}

var app = builder.Build();

// ... outros middlewares

// Registrar middleware de log APENAS se for local
if (isLocal)
{
    app.UseMiddleware<LogRequisicaoMiddleware>();
}

app.UseAuthorization();
app.MapControllers();
app.Run();
```

---

## 🔧 Middleware - Verificação Interna

### **LogRequisicaoMiddleware.cs:**

```csharp
public class LogRequisicaoMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _config;
    
    public LogRequisicaoMiddleware(
        RequestDelegate next,
        IServiceProvider serviceProvider,
        IConfiguration config)
    {
        _next = next;
        _serviceProvider = serviceProvider;
        _config = config;
    }
    
    public async Task InvokeAsync(HttpContext context)
    {
        // Verificar se é servidor local
        var isLocal = _config.GetValue<bool>("IsLocal", false);
        
        if (!isLocal)
        {
            // Se não for local, apenas continuar (não loga)
            await _next(context);
            return;
        }
        
        // Apenas no servidor LOCAL: logar requisição
        
        // Ler body
        context.Request.EnableBuffering();
        var body = await new StreamReader(context.Request.Body).ReadToEndAsync();
        context.Request.Body.Position = 0;
        
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
        
        // Salvar em background (não bloqueia)
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<LocalDbContext>();
                await db.LogRequisicoes.AddAsync(log);
                await db.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                // Log erro (não quebra requisição)
                Console.WriteLine($"Erro ao salvar log: {ex.Message}");
            }
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

---

## 🔧 SyncService - Verificação Interna

### **SyncService.cs:**

```csharp
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
        // Verificar se é servidor local
        var isLocal = _config.GetValue<bool>("IsLocal", false);
        
        if (!isLocal)
        {
            _logger.LogInformation("Servidor nuvem detectado. Serviço de sincronização não será executado.");
            return;  // Não executa se não for local
        }
        
        _logger.LogInformation("Serviço de sincronização iniciado (servidor local)");
        
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
            
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }
    
    // ... resto do código
}
```

---

## 🎯 Alternativa: Variável de Ambiente

### **Usando Variável de Ambiente:**

```bash
# Servidor Local
export IS_LOCAL=true
dotnet run

# Servidor Nuvem
export IS_LOCAL=false
dotnet run
```

### **appsettings.json:**

```json
{
  "IsLocal": "${IS_LOCAL:-false}"
}
```

Ou diretamente no código:

```csharp
var isLocal = Environment.GetEnvironmentVariable("IS_LOCAL") == "true";
```

---

## 🎯 Alternativa: Projeto Separado (Opcional)

### **Se quiser separar completamente:**

```
mx_cloud/
├── MXCloud.API/              ← API Principal (serve ambos)
│   └── Controllers/
│
└── MXCloud.Local.API/        ← Projeto separado (só local)
    ├── Program.cs            ← Entry point local
    ├── Middleware/
    │   └── LogRequisicaoMiddleware.cs
    └── Services/
        └── SyncService.cs
```

**Vantagem:** Separação física completa

**Desvantagem:** Duplicação de código

**Recomendação:** Usar flag de configuração (mais simples) ✅

---

## 📋 Resumo: Implementação Recomendada

### **1. Configuração:**

```json
// appsettings.Local.json
{
  "IsLocal": true,
  ...
}

// appsettings.Production.json
{
  "IsLocal": false,
  ...
}
```

### **2. Program.cs:**

```csharp
var isLocal = builder.Configuration.GetValue<bool>("IsLocal", false);

if (isLocal)
{
    builder.Services.AddDbContext<LocalDbContext>(...);
    builder.Services.AddHostedService<SyncService>();
}

var app = builder.Build();

if (isLocal)
{
    app.UseMiddleware<LogRequisicaoMiddleware>();
}
```

### **3. Middleware e Service:**

```csharp
// Ambos verificam isLocal internamente também
var isLocal = _config.GetValue<bool>("IsLocal", false);
if (!isLocal) return;  // Não executa se não for local
```

---

## ✅ Resultado

### **Servidor Local:**
- ✅ Middleware de log ativo
- ✅ Serviço de sincronização ativo
- ✅ Tabela log_requisicoes usada

### **Servidor Nuvem:**
- ✅ Middleware de log **não** ativo
- ✅ Serviço de sincronização **não** ativo
- ✅ Funciona normalmente (sem overhead)

**Perfeito!** 🚀

