# 🔧 API Servidor Local: Opções de Implementação

## ❓ Pergunta: API Diferente ou Mesma API?

Existem **2 abordagens** possíveis. Vamos analisar cada uma:

---

## 🎯 Opção 1: API Separada (Nova API Local)

### **Conceito:**
Criar uma **nova API** específica para o servidor local, com estrutura própria.

### **Estrutura:**

```
mx_cloud/
├── MXCloud.API/              ← API Nuvem (atual)
│   └── Controllers/
│       ├── PedidosController.cs
│       ├── MesasController.cs
│       └── ...
│
└── MXCloud.Local.API/         ← NOVA API Local
    └── Controllers/
        ├── PedidosController.cs
        ├── MesasController.cs
        └── ...
```

### **Vantagens:**
- ✅ Separação clara de responsabilidades
- ✅ Pode ter endpoints específicos para local
- ✅ Não interfere na API nuvem
- ✅ Pode evoluir independentemente

### **Desvantagens:**
- ❌ Duplicação de código
- ❌ Precisa manter duas APIs
- ❌ Mais trabalho de manutenção
- ❌ Mudanças precisam ser feitas em dois lugares

---

## 🎯 Opção 2: Mesma API, Connection String Diferente (Recomendado)

### **Conceito:**
**Reutilizar a mesma API** do servidor principal, apenas mudando a connection string.

### **Estrutura:**

```
mx_cloud/
└── MXCloud.API/              ← MESMA API (serve ambos)
    ├── Controllers/
    │   ├── PedidosController.cs
    │   ├── MesasController.cs
    │   └── ...
    ├── Data/
    │   ├── MXCloudDbContext.cs
    │   └── ...
    └── appsettings.json      ← Connection string muda por ambiente
```

### **Como Funciona:**

**Servidor Nuvem:**
```json
// appsettings.Production.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Database=mx_cloud;..."
  }
}
```

**Servidor Local:**
```json
// appsettings.Local.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=mx_cloud_local;..."
  }
}
```

**Mesma API, banco diferente!** ✅

### **Vantagens:**
- ✅ **Zero duplicação de código**
- ✅ **Mudança mínima** (apenas connection string)
- ✅ **Mesma lógica** em ambos
- ✅ **Manutenção única**
- ✅ **Reutiliza tudo** (DTOs, Services, Controllers)

### **Desvantagens:**
- ⚠️ Precisa adaptar algumas coisas (fila de comandos, cache)
- ⚠️ Pode precisar de flags/configurações específicas

---

## 🔄 Opção 2.1: Mesma API com Adaptações (Híbrida)

### **Conceito:**
Mesma API base, mas com **adaptações específicas** para servidor local.

### **Estrutura:**

```
mx_cloud/
└── MXCloud.API/              ← MESMA API
    ├── Controllers/
    │   ├── PedidosController.cs      ← Reutiliza
    │   ├── MesasController.cs       ← Reutiliza
    │   └── SyncController.cs        ← NOVO (só local)
    ├── Services/
    │   ├── PedidoService.cs         ← Reutiliza
    │   ├── SyncService.cs           ← NOVO (só local)
    │   └── FilaComandoService.cs    ← NOVO (só local)
    ├── Data/
    │   ├── MXCloudDbContext.cs      ← Adaptado (suporta ambos)
    │   └── LocalDbContext.cs        ← NOVO (só local)
    └── appsettings.json
```

### **Como Funciona:**

**DbContext Principal (Nuvem):**
```csharp
public class MXCloudDbContext : DbContext
{
    public DbSet<Pedido> Pedidos { get; set; }
    public DbSet<Mesa> Mesas { get; set; }
    // ... tabelas do servidor principal
}
```

**DbContext Local (Local):**
```csharp
public class LocalDbContext : DbContext
{
    // Cache
    public DbSet<ProdutoCache> ProdutosCache { get; set; }
    public DbSet<MesaCache> MesasCache { get; set; }
    
    // Dados Locais
    public DbSet<PedidoLocal> PedidosLocal { get; set; }
    
    // Fila
    public DbSet<FilaComando> FilaComandos { get; set; }
}
```

**Controllers Reutilizam Lógica:**
```csharp
[ApiController]
[Route("pedidos")]
public class PedidosController : ControllerBase
{
    private readonly LocalDbContext _dbLocal;  // Se local
    private readonly MXCloudDbContext _db;      // Se nuvem
    private readonly FilaComandoService _filaService;  // Se local
    
    [HttpPost]
    public async Task<IActionResult> CriarPedido(CreatePedidoDto dto)
    {
        if (IsLocal())  // Verifica se é servidor local
        {
            // Salvar local
            var pedido = new PedidoLocal { ... };
            _dbLocal.PedidosLocal.Add(pedido);
            
            // Gravar na fila
            await _filaService.AdicionarComando("criar_pedido", dto);
            
            await _dbLocal.SaveChangesAsync();
        }
        else
        {
            // Lógica normal (nuvem)
            var pedido = new Pedido { ... };
            _db.Pedidos.Add(pedido);
            await _db.SaveChangesAsync();
        }
        
        return Ok(pedido);
    }
}
```

### **Vantagens:**
- ✅ Reutiliza maioria do código
- ✅ Adaptações específicas para local
- ✅ Mantém compatibilidade com nuvem
- ✅ Mudança mínima

---

## 📊 Comparação das Opções

| Aspecto | Opção 1: API Separada | Opção 2: Mesma API | Opção 2.1: Híbrida |
|---------|----------------------|-------------------|-------------------|
| **Duplicação** | ❌ Muita | ✅ Zero | ⚠️ Pouca |
| **Manutenção** | ❌ Dupla | ✅ Única | ✅ Quase única |
| **Mudança Código** | ❌ Muita | ✅ Mínima | ✅ Mínima |
| **Complexidade** | ⚠️ Média | ✅ Baixa | ⚠️ Média |
| **Reutilização** | ❌ Nenhuma | ✅ Total | ✅ Maioria |

---

## 🎯 Recomendação: Opção 2.1 (Híbrida)

### **Por quê?**

1. **Reutiliza máximo de código**
   - Controllers, Services, DTOs
   - Lógica de negócio
   - Validações

2. **Mudança mínima**
   - Apenas adaptações específicas
   - Flags/configurações para diferenciar

3. **Manutenção facilitada**
   - Mudanças na API principal refletem em ambos
   - Apenas lógica específica de local precisa manter separada

4. **Evolução natural**
   - Pode começar igual e adaptar conforme necessário
   - Não precisa reescrever tudo

---

## 🔧 Implementação Prática: Opção 2.1

### **1. Estrutura do Projeto:**

```
mx_cloud/
├── MXCloud.API/                    ← API Principal (serve ambos)
│   ├── Controllers/
│   │   ├── PedidosController.cs    ← Reutiliza
│   │   ├── MesasController.cs      ← Reutiliza
│   │   └── SyncController.cs       ← NOVO (só local)
│   ├── Services/
│   │   ├── PedidoService.cs        ← Reutiliza
│   │   └── SyncService.cs          ← NOVO (só local)
│   ├── Data/
│   │   ├── MXCloudDbContext.cs     ← Nuvem
│   │   └── LocalDbContext.cs       ← Local
│   └── appsettings.json
│
└── MXCloud.Local.API/              ← Projeto separado (opcional)
    └── Program.cs                  ← Entry point local
```

### **2. Configuração por Ambiente:**

**appsettings.Production.json (Nuvem):**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Database=mx_cloud;..."
  },
  "IsLocal": false
}
```

**appsettings.Local.json (Local):**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=mx_cloud_local;..."
  },
  "IsLocal": true,
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx"
  }
}
```

### **3. Injeção de Dependência:**

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
var isLocal = builder.Configuration.GetValue<bool>("IsLocal");

if (isLocal)
{
    // Servidor Local
    builder.Services.AddDbContext<LocalDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
    
    builder.Services.AddScoped<SyncService>();
    builder.Services.AddScoped<FilaComandoService>();
    builder.Services.AddScoped<ApiNuvemService>();
}
else
{
    // Servidor Nuvem
    builder.Services.AddDbContext<MXCloudDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
}

// Services comuns (ambos)
builder.Services.AddScoped<PedidoService>();
builder.Services.AddScoped<MesaService>();

builder.Services.AddControllers();
var app = builder.Build();
app.Run();
```

### **4. Controller Adaptado:**

```csharp
[ApiController]
[Route("pedidos")]
public class PedidosController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly PedidoService _pedidoService;
    private readonly LocalDbContext? _dbLocal;
    private readonly FilaComandoService? _filaService;
    
    public PedidosController(
        IConfiguration config,
        PedidoService pedidoService,
        LocalDbContext? dbLocal = null,
        FilaComandoService? filaService = null)
    {
        _config = config;
        _pedidoService = pedidoService;
        _dbLocal = dbLocal;
        _filaService = filaService;
    }
    
    [HttpPost]
    public async Task<IActionResult> CriarPedido(CreatePedidoDto dto)
    {
        var isLocal = _config.GetValue<bool>("IsLocal");
        
        if (isLocal && _dbLocal != null && _filaService != null)
        {
            // Lógica Local
            var pedidoLocal = new PedidoLocal
            {
                IdLocal = Guid.NewGuid(),
                DadosJson = JsonSerializer.Serialize(dto),
                CriadoEm = DateTime.UtcNow
            };
            
            _dbLocal.PedidosLocal.Add(pedidoLocal);
            
            // Gravar na fila
            await _filaService.AdicionarComando("criar_pedido", dto);
            
            await _dbLocal.SaveChangesAsync();
            
            return Ok(new { id = pedidoLocal.IdLocal, ... });
        }
        else
        {
            // Lógica Nuvem (normal)
            var pedido = await _pedidoService.CriarPedido(dto);
            return Ok(pedido);
        }
    }
}
```

---

## 🎯 Conclusão

### **Recomendação: Opção 2.1 (Híbrida)**

**Vantagens:**
- ✅ Reutiliza máximo de código
- ✅ Mudança mínima
- ✅ Manutenção facilitada
- ✅ Evolução natural

**Estrutura:**
- Mesma API base
- DbContext separado para local (cache + fila)
- Services específicos para local (sync, fila)
- Controllers adaptados com flags

**Resultado:**
- Mesma API, adaptações mínimas para local
- Máxima reutilização de código
- Fácil de manter e evoluir

**É isso! Mesma API com adaptações específicas!** 🚀
