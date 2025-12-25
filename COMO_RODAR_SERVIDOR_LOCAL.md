# 🚀 Como Rodar o Servidor Local

## 🎯 Como Funciona a Configuração no ASP.NET Core

### **Sistema de Configuração:**

O ASP.NET Core carrega configurações nesta ordem (última sobrescreve):

1. `appsettings.json` (base)
2. `appsettings.{Environment}.json` (ambiente específico)
3. Variáveis de ambiente
4. Argumentos de linha de comando

### **Exemplo:**

```
appsettings.json              ← Base (sempre carregado)
appsettings.Development.json  ← Se Environment = Development
appsettings.Production.json    ← Se Environment = Production
appsettings.Local.json        ← Se Environment = Local
```

---

## 🔧 Como Usar appsettings.Local.json

### **Opção 1: Variável de Ambiente (Recomendado)**

```bash
# Definir ambiente como "Local"
export ASPNETCORE_ENVIRONMENT=Local

# Rodar servidor
dotnet run
```

**Windows (PowerShell):**
```powershell
$env:ASPNETCORE_ENVIRONMENT="Local"
dotnet run
```

**Windows (CMD):**
```cmd
set ASPNETCORE_ENVIRONMENT=Local
dotnet run
```

### **Opção 2: Argumento de Linha de Comando**

```bash
dotnet run --environment Local
```

### **Opção 3: launchSettings.json (Visual Studio/Rider)**

```json
{
  "profiles": {
    "Local": {
      "commandName": "Project",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Local"
      }
    }
  }
}
```

---

## 📋 O que Acontece Quando Usa Local

### **1. Carrega Configurações:**

```
appsettings.json          ← Carrega primeiro (base)
appsettings.Local.json    ← Carrega depois (sobrescreve)
```

**Resultado:** Configurações do `appsettings.Local.json` sobrescrevem as do `appsettings.json`.

### **2. Ativa Flag IsLocal:**

```json
// appsettings.Local.json
{
  "IsLocal": true  ← Esta flag é lida
}
```

### **3. Registra Serviços Condicionalmente:**

```csharp
// Program.cs
var isLocal = builder.Configuration.GetValue<bool>("IsLocal", false);

if (isLocal)
{
    // Registra LocalDbContext
    builder.Services.AddDbContext<LocalDbContext>(...);
    
    // Registra SyncService
    builder.Services.AddHostedService<SyncService>();
}
```

### **4. Usa Middleware Condicionalmente:**

```csharp
// Program.cs
if (isLocal)
{
    app.UseMiddleware<LogRequisicaoMiddleware>();
}
```

---

## 🗄️ Como Funciona o Banco

### **Servidor Nuvem (Production):**

```json
// appsettings.Production.json
{
  "IsLocal": false,
  "ConnectionStrings": {
    "DefaultConnection": "Host=servidor-nuvem;Database=mx_cloud;..."
  }
}
```

**Resultado:**
- Usa `MXCloudDbContext` (banco nuvem)
- **NÃO** registra `LocalDbContext`
- **NÃO** registra `SyncService`
- **NÃO** usa middleware de log

### **Servidor Local (Local):**

```json
// appsettings.Local.json
{
  "IsLocal": true,
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=mx_cloud_local;..."
  }
}
```

**Resultado:**
- Usa `MXCloudDbContext` (banco local - mesma connection string)
- **TAMBÉM** registra `LocalDbContext` (banco local - mesma connection string)
- **TAMBÉM** registra `SyncService`
- **TAMBÉM** usa middleware de log

**Importante:** Ambos os DbContexts podem usar a mesma connection string, mas são contextos diferentes:
- `MXCloudDbContext` → Tabelas do sistema principal
- `LocalDbContext` → Tabela `log_requisicoes` (sincronização)

---

## 🚀 Passo a Passo: Rodar Servidor Local

### **1. Configurar appsettings.Local.json:**

```json
{
  "IsLocal": true,
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=postgres;Password=sua_senha"
  },
  "Jwt": {
    "Secret": "MESMA_CHAVE_DO_SERVIDOR_NUVEM"
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com"
  }
}
```

### **2. Criar Banco PostgreSQL Local:**

```sql
CREATE DATABASE mx_cloud_local;
```

### **3. Criar Migration:**

```bash
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API
dotnet ef migrations add CriarLogRequisicoes --context LocalDbContext
dotnet ef database update --context LocalDbContext
```

### **4. Rodar Servidor Local:**

```bash
# Opção 1: Variável de ambiente
export ASPNETCORE_ENVIRONMENT=Local
dotnet run

# Opção 2: Argumento
dotnet run --environment Local
```

### **5. Verificar se Está Funcionando:**

```
✅ Servidor LOCAL detectado - Log de requisições e sincronização habilitados
```

Se aparecer essa mensagem, está funcionando! ✅

---

## 🔍 Como Verificar Qual Ambiente Está Rodando

### **No Console:**

O `Program.cs` já mostra:
```csharp
Console.WriteLine($"🔍 AMBIENTE: {builder.Environment.EnvironmentName}");
```

**Saída esperada:**
```
🔍 AMBIENTE: Local
```

### **No Código:**

```csharp
var environment = builder.Environment.EnvironmentName;
var isLocal = builder.Configuration.GetValue<bool>("IsLocal", false);

Console.WriteLine($"Environment: {environment}");
Console.WriteLine($"IsLocal: {isLocal}");
```

---

## 📊 Resumo: Fluxo Completo

### **1. Definir Ambiente:**

```bash
export ASPNETCORE_ENVIRONMENT=Local
```

### **2. ASP.NET Core Carrega:**

```
appsettings.json          ← Base
appsettings.Local.json    ← Sobrescreve (IsLocal = true)
```

### **3. Program.cs Lê:**

```csharp
var isLocal = builder.Configuration.GetValue<bool>("IsLocal", false);
// isLocal = true ✅
```

### **4. Registra Serviços:**

```csharp
if (isLocal)  // true
{
    // Registra LocalDbContext
    // Registra SyncService
}
```

### **5. Usa Middleware:**

```csharp
if (isLocal)  // true
{
    app.UseMiddleware<LogRequisicaoMiddleware>();
}
```

### **6. Servidor Roda:**

- ✅ Intercepta requisições (middleware)
- ✅ Salva em log_requisicoes
- ✅ Sincroniza com nuvem (background)

---

## ❓ Perguntas Frequentes

### 1. **Preciso criar appsettings.Local.json manualmente?**

**Sim!** O arquivo já foi criado, mas você precisa ajustar:
- Connection string do PostgreSQL local
- URL da API nuvem
- Chave JWT (mesma do servidor nuvem)

### 2. **E se não definir ASPNETCORE_ENVIRONMENT=Local?**

**Resultado:**
- Usa `appsettings.json` (base)
- `IsLocal` será `false` (padrão)
- Servidor roda como nuvem (sem log/sync)

### 3. **Posso ter ambos os bancos no mesmo PostgreSQL?**

**Sim!** Pode criar dois bancos:
- `mx_cloud` (nuvem)
- `mx_cloud_local` (local)

Ou usar o mesmo banco com schemas diferentes.

### 4. **Como saber qual ambiente está rodando?**

**Console mostra:**
```
🔍 AMBIENTE: Local
```

**Ou verificar:**
```csharp
Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
```

---

## 🎯 Resumo Final

### **Para Rodar Servidor Local:**

1. **Configurar** `appsettings.Local.json` (connection string, etc)
2. **Definir ambiente:** `export ASPNETCORE_ENVIRONMENT=Local`
3. **Rodar:** `dotnet run`
4. **Verificar:** Mensagem "Servidor LOCAL detectado"

### **Como Funciona:**

- `appsettings.Local.json` só é carregado se `ASPNETCORE_ENVIRONMENT=Local`
- Flag `IsLocal` ativa serviços específicos
- Mesma API, comportamento diferente baseado na configuração

**É isso! Simples e flexível!** 🚀
