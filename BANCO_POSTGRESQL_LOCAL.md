# 🗄️ PostgreSQL Local para Servidor Local

## 🎯 Solução: PostgreSQL Local

**Usar o mesmo PostgreSQL localmente!**

- ✅ Mesma sintaxe SQL
- ✅ Mesma estrutura de dados
- ✅ Mesma API (Entity Framework)
- ✅ Mudança mínima no código

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────┐
│         SERVIDOR LOCAL                  │
│                                         │
│  API .NET (mesma do servidor)          │
│         ↓                               │
│  Entity Framework Core                  │
│         ↓                               │
│  PostgreSQL Local                       │
│  (localhost:5432)                        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         SERVIDOR NUVEM                  │
│                                         │
│  API .NET (mesma do servidor)          │
│         ↓                               │
│  Entity Framework Core                  │
│         ↓                               │
│  PostgreSQL Nuvem                      │
│  (servidor remoto)                      │
└─────────────────────────────────────────┘
```

**Diferença:** Apenas a connection string!

---

## 📦 Instalação PostgreSQL Local

### **Windows:**

1. **Baixar PostgreSQL:**
   - https://www.postgresql.org/download/windows/
   - Instalar normalmente (porta padrão: 5432)

2. **Criar banco local:**
```sql
CREATE DATABASE mx_cloud_local;
```

3. **Configurar usuário:**
```sql
CREATE USER mx_local WITH PASSWORD 'senha_local';
GRANT ALL PRIVILEGES ON DATABASE mx_cloud_local TO mx_local;
```

### **Linux (Ubuntu/Debian):**

```bash
# Instalar PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Criar banco
sudo -u postgres createdb mx_cloud_local
sudo -u postgres createuser mx_local
sudo -u postgres psql -c "ALTER USER mx_local WITH PASSWORD 'senha_local';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mx_cloud_local TO mx_local;"
```

---

## 🔧 Configuração na API

### **appsettings.json - Servidor Local:**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=mx_local;Password=senha_local"
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx"
  }
}
```

### **appsettings.json - Servidor Nuvem (atual):**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Port=5432;Database=mx_cloud;Username=user;Password=senha"
  }
}
```

**Mudança:** Apenas a connection string! ✅

---

## 🗄️ Estrutura do Banco Local

### **Tabelas Necessárias:**

```sql
-- ============================================
-- CACHE (Dados de Leitura - do início do dia)
-- ============================================

CREATE TABLE produtos_cache (
  id UUID PRIMARY KEY,
  nome VARCHAR(255) NOT NULL,
  preco DECIMAL(10,2),
  -- ... mesmos campos da tabela Produto
  sincronizado_em TIMESTAMP
);

CREATE TABLE mesas_cache (
  id UUID PRIMARY KEY,
  numero VARCHAR(50) NOT NULL,
  status VARCHAR(50),
  -- ... mesmos campos da tabela Mesa
  sincronizado_em TIMESTAMP
);

CREATE TABLE comandas_cache (
  id UUID PRIMARY KEY,
  numero VARCHAR(50) NOT NULL,
  status VARCHAR(50),
  -- ... mesmos campos da tabela Comanda
  sincronizado_em TIMESTAMP
);

-- ============================================
-- DADOS LOCAIS (Dados de Escrita - do dia)
-- ============================================

CREATE TABLE pedidos_local (
  id_local UUID PRIMARY KEY,
  id_remoto UUID,
  numero VARCHAR(50),
  tipo INTEGER,
  status VARCHAR(50),
  mesa_id UUID,
  comanda_id UUID,
  total DECIMAL(10,2),
  dados_json JSONB NOT NULL,  -- PostgreSQL suporta JSONB!
  criado_em TIMESTAMP NOT NULL,
  sincronizado BOOLEAN DEFAULT FALSE
);

CREATE TABLE pedido_itens_local (
  id UUID PRIMARY KEY,
  pedido_id_local UUID NOT NULL,
  produto_id UUID NOT NULL,
  quantidade DECIMAL(10,2),
  preco_unitario DECIMAL(10,2),
  FOREIGN KEY (pedido_id_local) REFERENCES pedidos_local(id_local)
);

-- ============================================
-- FILA DE COMANDOS (Log de Operações)
-- ============================================

CREATE TABLE fila_comandos (
  id UUID PRIMARY KEY,
  tipo VARCHAR(100) NOT NULL,
  ordem INTEGER NOT NULL,
  dados JSONB NOT NULL,  -- { endpoint, metodo, body }
  sincronizado BOOLEAN DEFAULT FALSE,
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  criado_em TIMESTAMP NOT NULL,
  sincronizado_em TIMESTAMP
);

CREATE INDEX idx_fila_ordem ON fila_comandos(ordem);
CREATE INDEX idx_fila_sincronizado ON fila_comandos(sincronizado, ordem);
CREATE INDEX idx_pedidos_mesa ON pedidos_local(mesa_id);
```

**Vantagem:** PostgreSQL suporta `JSONB` nativamente! Perfeito para armazenar dados JSON.

---

## 🔄 Entity Framework - Mesma Configuração

### **DbContext - Servidor Local:**

```csharp
public class LocalDbContext : DbContext
{
    public LocalDbContext(DbContextOptions<LocalDbContext> options) 
        : base(options) { }
    
    // Cache
    public DbSet<ProdutoCache> ProdutosCache { get; set; }
    public DbSet<MesaCache> MesasCache { get; set; }
    public DbSet<ComandaCache> ComandasCache { get; set; }
    
    // Dados Locais
    public DbSet<PedidoLocal> PedidosLocal { get; set; }
    public DbSet<PedidoItemLocal> PedidoItensLocal { get; set; }
    
    // Fila
    public DbSet<FilaComando> FilaComandos { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Mesmas configurações do DbContext principal
        // Pode até reutilizar as configurações!
        
        modelBuilder.Entity<PedidoLocal>()
            .Property(p => p.DadosJson)
            .HasColumnType("jsonb");  // PostgreSQL JSONB
        
        modelBuilder.Entity<FilaComando>()
            .Property(f => f.Dados)
            .HasColumnType("jsonb");
        
        // Índices
        modelBuilder.Entity<FilaComando>()
            .HasIndex(f => f.Ordem);
        
        modelBuilder.Entity<FilaComando>()
            .HasIndex(f => new { f.Sincronizado, f.Ordem });
    }
}
```

### **Program.cs:**

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configurar DbContext (mesma configuração do servidor principal)
builder.Services.AddDbContext<LocalDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection")
    ));

// Mesmos serviços do servidor principal
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Migrations (criar banco local)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<LocalDbContext>();
    db.Database.Migrate();  // Cria tabelas automaticamente
}

app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

**Mudança:** Apenas a connection string! ✅

---

## 📊 Migrations - Reutilizar Estrutura

### **Opção 1: Criar Migrations Específicas**

```bash
# Criar migration para banco local
dotnet ef migrations add InicialLocal --context LocalDbContext

# Aplicar migration
dotnet ef database update --context LocalDbContext
```

### **Opção 2: Reutilizar Estrutura do Servidor Principal**

Se as tabelas locais têm estrutura similar, pode criar migrations baseadas nas do servidor principal:

```csharp
// Migration: CriarTabelasCache
public partial class CriarTabelasCache : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Criar tabelas baseadas nas do servidor principal
        migrationBuilder.CreateTable(
            name: "produtos_cache",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false),
                nome = table.Column<string>(type: "varchar(255)", nullable: false),
                preco = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                sincronizado_em = table.Column<DateTime>(type: "timestamp", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_produtos_cache", x => x.id);
            });
        
        // ... outras tabelas
    }
}
```

---

## 🔄 Queries - Mesma Sintaxe

### **Exemplo: Buscar Pedidos**

```csharp
// Servidor Local - Mesma sintaxe do servidor principal
var pedidos = await _db.PedidosLocal
    .Where(p => p.MesaId == mesaId && !p.Sincronizado)
    .OrderBy(p => p.CriadoEm)
    .ToListAsync();

// Servidor Principal - Mesma sintaxe
var pedidos = await _db.Pedidos
    .Where(p => p.MesaId == mesaId)
    .OrderBy(p => p.CriadoEm)
    .ToListAsync();
```

**Mudança:** Apenas o DbSet (`PedidosLocal` vs `Pedidos`)! ✅

---

## 🎯 Vantagens PostgreSQL Local

### ✅ **Compatibilidade Total**
- Mesma sintaxe SQL
- Mesmas funções PostgreSQL
- Mesmo Entity Framework Core
- Mesmas queries

### ✅ **Mudança Mínima**
- Apenas connection string diferente
- Mesma estrutura de código
- Pode reutilizar lógica

### ✅ **JSONB Nativo**
- PostgreSQL suporta JSONB nativamente
- Perfeito para `dados_json` e `fila_comandos`
- Queries JSON eficientes

### ✅ **Performance**
- PostgreSQL é rápido
- Suporta índices complexos
- Transações ACID

### ✅ **Familiaridade**
- Mesmo banco do servidor principal
- Equipe já conhece
- Mesmas ferramentas (pgAdmin, etc)

---

## 📋 Estrutura do Projeto

```
ServidorLocal/
├── ServidorLocal.csproj
├── Program.cs
├── appsettings.json          # Connection string local
├── Controllers/
│   ├── PedidosController.cs  # Mesmos endpoints
│   ├── MesasController.cs
│   └── ComandasController.cs
├── Services/
│   ├── SyncService.cs
│   └── ApiNuvemService.cs
├── Models/
│   ├── PedidoLocal.cs        # Similar ao Pedido
│   ├── MesaCache.cs          # Similar ao Mesa
│   └── FilaComando.cs
├── Data/
│   ├── LocalDbContext.cs     # Similar ao DbContext principal
│   └── Migrations/
└── ...
```

---

## 🔧 Configuração de Ambiente

### **appsettings.Development.json (Local):**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=mx_local;Password=senha_local"
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx"
  },
  "Sync": {
    "IntervalMinutes": 5,
    "MaxRetries": 5
  }
}
```

### **appsettings.Production.json (Nuvem):**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Port=5432;Database=mx_cloud;Username=user;Password=senha"
  }
}
```

---

## 🚀 Como Rodar

### **1. Instalar PostgreSQL Local**

```bash
# Windows: Baixar e instalar do site oficial
# Linux: sudo apt install postgresql
```

### **2. Criar Banco**

```sql
CREATE DATABASE mx_cloud_local;
```

### **3. Configurar Connection String**

```json
"ConnectionStrings": {
  "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=mx_local;Password=senha_local"
}
```

### **4. Rodar Migrations**

```bash
dotnet ef database update --context LocalDbContext
```

### **5. Rodar Servidor**

```bash
dotnet run
```

---

## 📊 Comparação: SQLite vs PostgreSQL

| Aspecto | SQLite | PostgreSQL |
|---------|--------|------------|
| **Compatibilidade** | ❌ Sintaxe diferente | ✅ Mesma sintaxe |
| **Mudança Código** | ⚠️ Precisa adaptar | ✅ Mínima |
| **JSON** | ⚠️ TEXT (string) | ✅ JSONB nativo |
| **Instalação** | ✅ Arquivo único | ⚠️ Precisa instalar |
| **Performance** | ✅ Boa | ✅ Excelente |
| **Reutilização** | ❌ Não | ✅ Sim |

**Para seu caso:** PostgreSQL é melhor! ✅

---

## 🎯 Conclusão

**PostgreSQL Local é a escolha certa!**

**Vantagens:**
- ✅ Mesma sintaxe do servidor principal
- ✅ Mudança mínima no código
- ✅ Pode reutilizar lógica/queries
- ✅ JSONB nativo (perfeito para fila)
- ✅ Equipe já conhece

**Mudança necessária:**
- Apenas a connection string! ✅

**É isso! PostgreSQL local resolve perfeitamente!** 🚀
