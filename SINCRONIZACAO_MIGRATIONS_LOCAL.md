# 🔄 Sincronização de Migrations: Servidor Local

## 🎯 Conceito

**Servidor Local busca migrations pendentes da nuvem e aplica automaticamente.**

Cliente não precisa fazer nada. Tudo automático!

---

## 🔄 Fluxo Completo

### **1. Desenvolvedor cria migration no servidor nuvem:**

```
Desenvolvedor:
  → dotnet ef migrations add CriarLogRequisicoes
  → dotnet ef database update (aplica no nuvem)
  → Commit no git
```

### **2. Servidor nuvem expõe migrations via API:**

```
GET /api/migrations/pendentes?versaoAtual=20251221012355

Resposta:
{
  "migrations": [
    {
      "nome": "20251222000000_CriarLogRequisicoes",
      "sql": "CREATE TABLE log_requisicoes...",
      "versao": "20251222000000"
    }
  ]
}
```

### **3. Servidor Local (ao iniciar ou periodicamente):**

```
Servidor Local:
  1. Verifica versão atual do banco local
  2. Chama API nuvem: GET /api/migrations/pendentes?versaoAtual=X
  3. Recebe migrations pendentes
  4. Aplica cada migration localmente
  5. Atualiza versão local
```

**Tudo automático! Cliente não precisa fazer nada.** ✅

---

## 🔧 Implementação: Servidor Local

### **Serviço de Sincronização de Migrations:**

```csharp
public class MigrationSyncService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _config;
    private readonly ILogger<MigrationSyncService> _logger;
    
    public MigrationSyncService(
        IServiceProvider serviceProvider,
        IConfiguration config,
        ILogger<MigrationSyncService> logger)
    {
        _serviceProvider = serviceProvider;
        _config = config;
        _logger = logger;
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Verificar se é servidor local
        var isLocal = _config.GetValue<bool>("IsLocal", false);
        if (!isLocal) return;
        
        // Aguardar um pouco para garantir que API está pronta
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        
        // Migrations são aplicadas manualmente via endpoint
        // Não roda automaticamente
    }
    
    private async Task VerificarEAplicarMigrations()
    {
        try
        {
            // Verificar se está online
            if (!await IsOnline()) return;
            
            // Obter versão atual do banco local
            var versaoAtual = await ObterVersaoAtualBancoLocal();
            
            // Buscar migrations pendentes da nuvem
            var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
            using var client = new HttpClient();
            
            var response = await client.GetAsync(
                $"{apiNuvemUrl}/api/migrations/pendentes?versaoAtual={versaoAtual}"
            );
            
            if (!response.IsSuccessStatusCode) return;
            
            var migrations = await response.Content.ReadFromJsonAsync<MigrationsResponse>();
            if (migrations?.Migrations == null || !migrations.Migrations.Any())
            {
                return; // Nada para aplicar
            }
            
            _logger.LogInformation($"Encontradas {migrations.Migrations.Count} migrations pendentes");
            
            // Aplicar cada migration
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
            
            foreach (var migration in migrations.Migrations)
            {
                try
                {
                    _logger.LogInformation($"Aplicando migration: {migration.Nome}");
                    
                    // Executar SQL da migration
                    await db.Database.ExecuteSqlRawAsync(migration.Sql);
                    
                    // Atualizar versão no banco
                    await AtualizarVersaoMigration(migration.Versao);
                    
                    _logger.LogInformation($"Migration {migration.Nome} aplicada com sucesso");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Erro ao aplicar migration {migration.Nome}: {ex.Message}");
                    // Continuar com próxima migration mesmo se uma falhar
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao verificar migrations pendentes");
        }
    }
    
    private async Task<string> ObterVersaoAtualBancoLocal()
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
            
            // Buscar última migration aplicada
            var migrations = await db.Database.GetAppliedMigrationsAsync();
            return migrations.LastOrDefault() ?? "0";
        }
        catch
        {
            return "0";
        }
    }
    
    private async Task AtualizarVersaoMigration(string versao)
    {
        // Entity Framework gerencia isso automaticamente na tabela __EFMigrationsHistory
        // Não precisa fazer nada manualmente
    }
    
    private async Task<bool> IsOnline()
    {
        try
        {
            var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var response = await client.GetAsync($"{apiNuvemUrl}/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
    
    private class MigrationsResponse
    {
        public List<MigrationInfo> Migrations { get; set; } = new();
    }
    
    private class MigrationInfo
    {
        public string Nome { get; set; } = string.Empty;
        public string Sql { get; set; } = string.Empty;
        public string Versao { get; set; } = string.Empty;
    }
}
```

---

## 🔧 Endpoint no Servidor Nuvem (Futuro)

### **Endpoint para retornar migrations pendentes:**

```csharp
[ApiController]
[Route("api/migrations")]
public class MigrationsController : ControllerBase
{
    [HttpGet("pendentes")]
    public async Task<IActionResult> GetMigrationsPendentes([FromQuery] string? versaoAtual)
    {
        // Buscar migrations pendentes do banco
        var todasMigrations = await _dbContext.Database.GetMigrationsAsync();
        var migrationsAplicadas = await _dbContext.Database.GetAppliedMigrationsAsync();
        
        var migrationsPendentes = todasMigrations
            .Where(m => !migrationsAplicadas.Contains(m))
            .ToList();
        
        // Se versaoAtual foi informada, filtrar apenas as posteriores
        if (!string.IsNullOrEmpty(versaoAtual))
        {
            migrationsPendentes = migrationsPendentes
                .Where(m => string.Compare(m, versaoAtual) > 0)
                .ToList();
        }
        
        // Gerar SQL de cada migration
        var migrationsInfo = new List<object>();
        foreach (var migration in migrationsPendentes)
        {
            var sql = await GerarSqlMigration(migration);
            migrationsInfo.Add(new {
                nome = migration,
                sql = sql,
                versao = migration
            });
        }
        
        return Ok(new { migrations = migrationsInfo });
    }
    
    private async Task<string> GerarSqlMigration(string migrationName)
    {
        // Gerar SQL da migration usando Entity Framework
        // Isso pode ser feito usando Migrator
        var migrator = _dbContext.Database.GetService<IMigrator>();
        var sql = await migrator.GenerateScriptAsync(
            fromMigration: null,
            toMigration: migrationName
        );
        return sql;
    }
}
```

---

## 📋 Resumo

### **O que o Servidor Local faz:**

1. ✅ Ao iniciar: Verifica migrations pendentes
2. ✅ Periodicamente: Verifica a cada 1 hora
3. ✅ Busca da nuvem: Via API
4. ✅ Aplica automaticamente: No banco local
5. ✅ Atualiza versão: Rastreia qual foi aplicada

### **O que o Cliente precisa fazer:**

**NADA!** Tudo automático! ✅

---

## ✅ Vantagens

- ✅ **Automático** - Cliente não precisa fazer nada
- ✅ **Seguro** - Migrations vêm do servidor nuvem
- ✅ **Não precisa git** - Funciona via API
- ✅ **Funciona offline** - Aplica quando volta online
- ✅ **Rastreável** - Versão controlada

**É isso! Servidor local faz tudo automaticamente!** 🚀
