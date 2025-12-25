# 🔄 Estratégia: Replicar Schema SEM Git

## ❓ Problema

Cliente não tem acesso ao git. Como garantir que o banco local tenha o mesmo schema do banco nuvem?

---

## 🎯 Solução 1: Migrations via API (Recomendado) ⭐

### **Conceito:**

**Servidor nuvem expõe endpoint que retorna migrations pendentes. Servidor local aplica automaticamente.**

### **Como Funciona:**

```
Servidor Local (ao iniciar):
  1. Chama API: GET /api/migrations/pendentes?versaoAtual=X
  2. Recebe lista de migrations pendentes (SQL)
  3. Aplica cada migration localmente
  4. Atualiza versão local
```

### **Implementação:**

#### **1. Endpoint no Servidor Nuvem:**

```csharp
[ApiController]
[Route("api/migrations")]
public class MigrationsController : ControllerBase
{
    [HttpGet("pendentes")]
    public async Task<IActionResult> GetMigrationsPendentes([FromQuery] string? versaoAtual)
    {
        // Buscar migrations pendentes
        var migrations = await _migrationService.GetMigrationsPendentes(versaoAtual);
        
        return Ok(new {
            migrations = migrations.Select(m => new {
                nome = m.Nome,
                sql = m.Sql,
                versao = m.Versao
            })
        });
    }
}
```

#### **2. Serviço no Servidor Local:**

```csharp
public class MigrationSyncService
{
    public async Task SincronizarMigrations()
    {
        // Obter versão atual do banco local
        var versaoAtual = await ObterVersaoAtual();
        
        // Buscar migrations pendentes da nuvem
        var response = await _apiNuvem.GetAsync($"/api/migrations/pendentes?versaoAtual={versaoAtual}");
        var migrations = await response.Content.ReadFromJsonAsync<MigrationsResponse>();
        
        // Aplicar cada migration
        foreach (var migration in migrations.Migrations)
        {
            await AplicarMigration(migration.Sql);
            await AtualizarVersao(migration.Versao);
        }
    }
}
```

### **Vantagens:**
- ✅ Automático
- ✅ Não precisa git
- ✅ Cliente não precisa fazer nada
- ✅ Seguro (migrations vêm do servidor nuvem)

### **Desvantagens:**
- ⚠️ Precisa criar endpoint específico
- ⚠️ Precisa gerenciar versões

---

## 🎯 Solução 2: Comparar Schema e Aplicar Diferenças

### **Conceito:**

**Servidor local compara schema com nuvem e aplica diferenças automaticamente.**

### **Como Funciona:**

```
Servidor Local (ao iniciar):
  1. Obtém schema do banco nuvem (via API)
  2. Compara com schema local
  3. Gera SQL de diferenças
  4. Aplica diferenças localmente
```

### **Implementação:**

```csharp
public class SchemaSyncService
{
    public async Task SincronizarSchema()
    {
        // 1. Obter schema do servidor nuvem
        var schemaNuvem = await ObterSchemaNuvem();
        
        // 2. Obter schema local
        var schemaLocal = await ObterSchemaLocal();
        
        // 3. Comparar e gerar SQL de diferenças
        var sqlDiferenças = CompararSchemas(schemaNuvem, schemaLocal);
        
        // 4. Aplicar diferenças
        foreach (var sql in sqlDiferenças)
        {
            await ExecutarSql(sql);
        }
    }
    
    private async Task<SchemaInfo> ObterSchemaNuvem()
    {
        // Chamar API que retorna schema atual
        var response = await _apiNuvem.GetAsync("/api/schema/atual");
        return await response.Content.ReadFromJsonAsync<SchemaInfo>();
    }
}
```

### **Vantagens:**
- ✅ Automático
- ✅ Não precisa migrations
- ✅ Funciona com qualquer mudança

### **Desvantagens:**
- ❌ Complexo de implementar
- ❌ Pode ter problemas com dados existentes
- ❌ Difícil de debugar

---

## 🎯 Solução 3: Dump/Restore Automático

### **Conceito:**

**Servidor nuvem gera dump do schema periodicamente. Servidor local baixa e restaura.**

### **Como Funciona:**

```
Servidor Nuvem (diariamente):
  1. Gera dump do schema: pg_dump --schema-only
  2. Salva em local acessível (S3, FTP, etc)
  3. Atualiza versão do schema

Servidor Local (ao iniciar):
  1. Verifica versão do schema na nuvem
  2. Compara com versão local
  3. Se diferente: baixa dump e restaura
```

### **Vantagens:**
- ✅ Simples (dump/restore)
- ✅ Não precisa código complexo

### **Desvantagens:**
- ❌ Pode perder dados locais
- ❌ Precisa storage externo (S3, FTP)
- ❌ Menos granular (restaura tudo)

---

## 🎯 Solução 4: Package/Instalador com Migrations

### **Conceito:**

**Incluir migrations no instalador/package do servidor local.**

### **Como Funciona:**

```
Desenvolvedor:
  1. Cria migration
  2. Gera package/instalador com migrations incluídas
  3. Cliente baixa e instala nova versão
  4. Instalador aplica migrations automaticamente
```

### **Vantagens:**
- ✅ Controle de versão
- ✅ Migrations testadas

### **Desvantagens:**
- ❌ Cliente precisa instalar nova versão
- ❌ Não é automático (precisa ação do cliente)

---

## 🎯 Solução 5: Auto-Apply via Health Check

### **Conceito:**

**Servidor local verifica migrations pendentes periodicamente e aplica.**

### **Como Funciona:**

```
Servidor Local (a cada X minutos):
  1. Chama health check da nuvem
  2. Recebe versão do schema atual
  3. Compara com versão local
  4. Se diferente: busca e aplica migrations
```

### **Implementação:**

```csharp
public class MigrationSyncService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await VerificarEAplicarMigrations();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Erro ao sincronizar migrations");
            }
            
            // Verificar a cada 1 hora
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
```

---

## 📊 Comparação (Sem Git)

| Solução | Automático | Simples | Seguro | Recomendado |
|---------|------------|---------|--------|-------------|
| **1. Migrations via API** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅✅✅ |
| **2. Comparar Schema** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⚠️ |
| **3. Dump/Restore** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⚠️ |
| **4. Package/Instalador** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⚠️ |
| **5. Auto-Apply Health** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅✅ |

---

## 🎯 Recomendação: Solução 1 (Migrations via API)

### **Por quê?**

1. **Automático** - Cliente não precisa fazer nada
2. **Seguro** - Migrations vêm do servidor nuvem
3. **Granular** - Aplica apenas o que falta
4. **Rastreável** - Versão controlada

### **Fluxo Recomendado:**

```
Servidor Nuvem:
  1. Desenvolvedor cria migration
  2. Aplica no banco nuvem
  3. Migration fica disponível via API

Servidor Local (ao iniciar):
  1. Verifica migrations pendentes (API)
  2. Aplica automaticamente
  3. Banco local atualizado! ✅
```

---

## 🔧 Implementação: Migrations via API

### **1. Endpoint no Servidor Nuvem:**

```csharp
[HttpGet("migrations/pendentes")]
public async Task<IActionResult> GetMigrationsPendentes([FromQuery] string? versaoAtual)
{
    // Buscar migrations pendentes do banco
    var migrations = await _dbContext.Database
        .GetPendingMigrationsAsync();
    
    // Retornar SQL de cada migration
    var migrationsInfo = migrations.Select(m => new {
        nome = m,
        sql = await ObterSqlMigration(m)
    });
    
    return Ok(migrationsInfo);
}
```

### **2. Serviço no Servidor Local:**

```csharp
public class MigrationSyncService : BackgroundService
{
    protected override async Task ExecuteAsync(...)
    {
        // Ao iniciar, verificar migrations pendentes
        await VerificarEAplicarMigrations();
        
        // Depois, verificar periodicamente (a cada 1 hora)
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
            await VerificarEAplicarMigrations();
        }
    }
    
    private async Task VerificarEAplicarMigrations()
    {
        // Obter versão atual do banco local
        var versaoAtual = await ObterVersaoAtualBancoLocal();
        
        // Buscar migrations pendentes da nuvem
        var response = await _apiNuvem.GetAsync(
            $"/api/migrations/pendentes?versaoAtual={versaoAtual}"
        );
        
        var migrations = await response.Content.ReadFromJsonAsync<List<MigrationInfo>>();
        
        // Aplicar cada migration
        foreach (var migration in migrations)
        {
            await ExecutarSql(migration.Sql);
            await AtualizarVersao(migration.Nome);
        }
    }
}
```

---

## ✅ Conclusão

**Recomendação:** **Migrations via API** com verificação automática.

**Vantagens:**
- ✅ Automático (cliente não precisa fazer nada)
- ✅ Seguro (migrations vêm do servidor nuvem)
- ✅ Não precisa git
- ✅ Funciona offline (aplica quando volta online)

**É isso! A melhor solução sem git!** 🚀
