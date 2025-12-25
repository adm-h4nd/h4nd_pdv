# 🛠️ Tecnologias para Servidor Local

## 🎯 Requisitos

- ✅ Simples de instalar/configurar
- ✅ Leve (rodar em PC comum)
- ✅ Banco local (sem servidor separado)
- ✅ Fácil de fazer backup
- ✅ Funciona offline

---

## 💾 Banco de Dados: **SQLite** (Recomendado)

### **Por quê SQLite?**

✅ **Simples:**
- Arquivo único (`.db`)
- Não precisa instalar servidor
- Não precisa configurar nada

✅ **Leve:**
- Poucos MB de tamanho
- Consome pouca memória
- Rápido para operações locais

✅ **Confiável:**
- Usado por milhões de aplicações
- Suporta transações ACID
- Backup = copiar arquivo

✅ **Suficiente:**
- Suporta múltiplas conexões simultâneas
- Performance excelente para servidor local
- Suporta até alguns GB de dados

### **Estrutura:**

```
servidor-local/
├── data/
│   └── local.db          ← Arquivo único do SQLite
├── backups/
│   └── local_2024-01-15.db
└── ...
```

**Backup:** Simplesmente copiar o arquivo `.db`!

---

## 🖥️ Linguagem/Framework: 2 Opções

### **Opção 1: Node.js + Express + SQLite** ⭐ (Recomendado)

**Stack:**
- Node.js (runtime)
- Express (API)
- better-sqlite3 (driver SQLite)
- axios (cliente HTTP para nuvem)

**Vantagens:**
- ✅ Muito simples de desenvolver
- ✅ JavaScript/TypeScript (familiar)
- ✅ Grande ecossistema
- ✅ Fácil de instalar (só Node.js)
- ✅ Rápido de prototipar

**Desvantagens:**
- ⚠️ Linguagem diferente do backend (.NET)

**Instalação:**
```bash
# Instalar Node.js (uma vez)
# Baixar de: https://nodejs.org

# Criar projeto
npm init -y
npm install express better-sqlite3 axios
```

**Exemplo:**
```javascript
const express = require('express');
const Database = require('better-sqlite3');
const axios = require('axios');

const app = express();
const db = new Database('local.db');

app.post('/pedidos', async (req, res) => {
  // Salvar local
  const stmt = db.prepare('INSERT INTO pedidos_local ...');
  stmt.run(req.body);
  
  // Gravar na fila
  const filaStmt = db.prepare('INSERT INTO fila_comandos ...');
  filaStmt.run({ tipo: 'criar_pedido', ... });
  
  res.json({ success: true });
});

app.listen(3000);
```

---

### **Opção 2: .NET + ASP.NET Core + SQLite**

**Stack:**
- .NET 8 (runtime)
- ASP.NET Core (API)
- Entity Framework Core + SQLite
- HttpClient (cliente HTTP para nuvem)

**Vantagens:**
- ✅ Mesma linguagem do backend atual
- ✅ Pode reutilizar código/DTOs
- ✅ Fácil integração com backend existente
- ✅ Performance excelente

**Desvantagens:**
- ⚠️ Precisa instalar .NET SDK
- ⚠️ Mais verboso que Node.js

**Instalação:**
```bash
# Instalar .NET SDK (uma vez)
# Baixar de: https://dotnet.microsoft.com

# Criar projeto
dotnet new webapi -n ServidorLocal
cd ServidorLocal
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package Microsoft.EntityFrameworkCore.Design
```

**Exemplo:**
```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddDbContext<LocalDbContext>(options =>
    options.UseSqlite("Data Source=local.db"));

var app = builder.Build();
app.MapControllers();
app.Run();

// PedidosController.cs
[ApiController]
[Route("pedidos")]
public class PedidosController : ControllerBase
{
    private readonly LocalDbContext _db;
    
    [HttpPost]
    public async Task<IActionResult> CriarPedido(PedidoDto dto)
    {
        // Salvar local
        var pedido = new PedidoLocal { ... };
        _db.Pedidos.Add(pedido);
        
        // Gravar na fila
        var comando = new FilaComando { Tipo = "criar_pedido", ... };
        _db.FilaComandos.Add(comando);
        
        await _db.SaveChangesAsync();
        return Ok(new { success = true });
    }
}
```

---

## 📊 Comparação

| Aspecto | Node.js + SQLite | .NET + SQLite |
|---------|------------------|---------------|
| **Simplicidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Velocidade Dev** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Integração Backend** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Instalação** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Ecossistema** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎯 Recomendação

### **Para começar rápido:** Node.js + SQLite

**Por quê:**
- Mais simples de desenvolver
- Mais rápido de prototipar
- Fácil de instalar e rodar
- Suficiente para servidor local

### **Para integração melhor:** .NET + SQLite

**Por quê:**
- Mesma stack do backend
- Pode reutilizar código
- Melhor integração futura

---

## 📦 Estrutura do Projeto

### **Node.js:**

```
servidor-local/
├── package.json
├── server.js                 # Entry point
├── config/
│   └── database.js          # Config SQLite
├── routes/
│   ├── pedidos.js           # Endpoints pedidos
│   ├── mesas.js             # Endpoints mesas
│   └── comandas.js          # Endpoints comandas
├── services/
│   ├── sync-service.js      # Serviço de sincronização
│   └── api-nuvem.js         # Cliente API nuvem
├── models/
│   ├── pedido.js            # Modelo pedido
│   └── fila-comando.js      # Modelo fila
├── database/
│   ├── schema.sql           # Schema inicial
│   └── migrations/          # Migrations (se necessário)
├── data/
│   └── local.db             # Arquivo SQLite
└── .env                     # Configurações
```

### **.NET:**

```
ServidorLocal/
├── ServidorLocal.csproj
├── Program.cs               # Entry point
├── Controllers/
│   ├── PedidosController.cs
│   ├── MesasController.cs
│   └── ComandasController.cs
├── Services/
│   ├── SyncService.cs       # Serviço de sincronização
│   └── ApiNuvemService.cs  # Cliente API nuvem
├── Models/
│   ├── PedidoLocal.cs
│   └── FilaComando.cs
├── Data/
│   ├── LocalDbContext.cs    # DbContext
│   └── Migrations/          # Migrations EF Core
├── data/
│   └── local.db             # Arquivo SQLite
└── appsettings.json         # Configurações
```

---

## 🔧 Configuração SQLite

### **Schema Inicial:**

```sql
-- Criar tabelas
CREATE TABLE IF NOT EXISTS produtos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  preco REAL,
  sincronizado_em DATETIME
);

CREATE TABLE IF NOT EXISTS mesas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  sincronizado_em DATETIME
);

CREATE TABLE IF NOT EXISTS pedidos_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  total REAL,
  dados_json TEXT NOT NULL,
  criado_em DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS fila_comandos (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,
  ordem INTEGER NOT NULL,
  dados TEXT NOT NULL,
  sincronizado INTEGER DEFAULT 0,
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  criado_em DATETIME NOT NULL,
  sincronizado_em DATETIME
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_fila_ordem ON fila_comandos(ordem);
CREATE INDEX IF NOT EXISTS idx_fila_sincronizado ON fila_comandos(sincronizado, ordem);
CREATE INDEX IF NOT EXISTS idx_pedidos_mesa ON pedidos_local(mesa_id);
```

---

## 🚀 Como Rodar

### **Node.js:**

```bash
# Instalar dependências (uma vez)
npm install

# Rodar servidor
node server.js

# Ou com nodemon (auto-reload)
npx nodemon server.js
```

### **.NET:**

```bash
# Restaurar dependências (uma vez)
dotnet restore

# Rodar servidor
dotnet run

# Ou compilar e rodar
dotnet build
dotnet run
```

---

## 📋 Checklist de Decisão

### **Escolha Node.js se:**
- ✅ Quer começar rápido
- ✅ Quer simplicidade
- ✅ Equipe conhece JavaScript
- ✅ Não precisa reutilizar código do backend

### **Escolha .NET se:**
- ✅ Quer mesma stack do backend
- ✅ Quer reutilizar código/DTOs
- ✅ Equipe conhece C#
- ✅ Quer melhor integração futura

---

## 🎯 Recomendação Final

**Para servidor local:** **Node.js + Express + SQLite**

**Por quê:**
- ✅ Mais simples e rápido de desenvolver
- ✅ SQLite é perfeito (arquivo único, sem servidor)
- ✅ Suficiente para servidor local
- ✅ Fácil de instalar e rodar
- ✅ Pode migrar para .NET depois se necessário

**SQLite é a escolha certa** porque:
- Não precisa instalar servidor de banco
- Backup = copiar arquivo
- Performance excelente para servidor local
- Suporta tudo que precisa

---

## ❓ Perguntas Frequentes

### 1. **SQLite aguenta múltiplos PDVs?**

**Sim!** SQLite suporta múltiplas conexões simultâneas. Para servidor local com alguns PDVs, é mais que suficiente.

### 2. **E se precisar de mais performance depois?**

Pode migrar para PostgreSQL local depois, mas SQLite deve ser suficiente para servidor local.

### 3. **Como fazer backup?**

Simplesmente copiar o arquivo `local.db`. Pode automatizar com script.

### 4. **E se o arquivo corromper?**

SQLite tem journaling automático. Raramente corrompe, mas pode fazer backup periódico.

---

## 🎉 Conclusão

**Recomendação:**
- **Banco:** SQLite (arquivo único, simples)
- **Linguagem:** Node.js (simples) ou .NET (integração)

**SQLite é perfeito para servidor local!** 🚀
