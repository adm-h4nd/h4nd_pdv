# 🔄 Sincronização de Migrations: Manual

## 🎯 Conceito

**Servidor Local tem endpoint/comando para sincronizar migrations manualmente.**

Cliente chama quando quiser atualizar o banco.

---

## 🔧 Implementação: Endpoint Manual

### **Controller no Servidor Local:**

```csharp
[ApiController]
[Route("api/admin")]
public class AdminController : ControllerBase
{
    private readonly MigrationSyncService _migrationSyncService;
    
    [HttpPost("migrations/sincronizar")]
    public async Task<IActionResult> SincronizarMigrations()
    {
        try
        {
            var resultado = await _migrationSyncService.SincronizarMigrations();
            
            return Ok(new {
                sucesso = true,
                mensagem = $"${resultado.MigrationsAplicadas} migration(s) aplicada(s)",
                migrationsAplicadas = resultado.MigrationsAplicadas,
                migrations = resultado.MigrationsAplicadasLista
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new {
                sucesso = false,
                mensagem = $"Erro ao sincronizar migrations: {ex.Message}"
            });
        }
    }
    
    [HttpGet("migrations/status")]
    public async Task<IActionResult> StatusMigrations()
    {
        try
        {
            var status = await _migrationSyncService.ObterStatus();
            
            return Ok(new {
                versaoAtual = status.VersaoAtual,
                migrationsPendentes = status.MigrationsPendentes,
                online = status.Online
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new {
                erro = ex.Message
            });
        }
    }
}
```

### **Serviço de Sincronização:**

```csharp
public class MigrationSyncService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _config;
    private readonly ILogger<MigrationSyncService> _logger;
    
    public async Task<SincronizacaoResultado> SincronizarMigrations()
    {
        // Verificar se está online
        if (!await IsOnline())
        {
            throw new InvalidOperationException("Servidor nuvem não está acessível");
        }
        
        // Obter versão atual do banco local
        var versaoAtual = await ObterVersaoAtualBancoLocal();
        
        // Buscar migrations pendentes da nuvem
        var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
        using var client = new HttpClient();
        
        var response = await client.GetAsync(
            $"{apiNuvemUrl}/api/migrations/pendentes?versaoAtual={versaoAtual}"
        );
        
        response.EnsureSuccessStatusCode();
        
        var migrations = await response.Content.ReadFromJsonAsync<MigrationsResponse>();
        if (migrations?.Migrations == null || !migrations.Migrations.Any())
        {
            return new SincronizacaoResultado
            {
                MigrationsAplicadas = 0,
                MigrationsAplicadasLista = new List<string>()
            };
        }
        
        _logger.LogInformation($"Encontradas {migrations.Migrations.Count} migrations pendentes");
        
        // Aplicar cada migration
        using var scope = _serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
        
        var migrationsAplicadas = new List<string>();
        
        foreach (var migration in migrations.Migrations)
        {
            try
            {
                _logger.LogInformation($"Aplicando migration: {migration.Nome}");
                
                // Executar SQL da migration
                await db.Database.ExecuteSqlRawAsync(migration.Sql);
                
                migrationsAplicadas.Add(migration.Nome);
                
                _logger.LogInformation($"Migration {migration.Nome} aplicada com sucesso");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Erro ao aplicar migration {migration.Nome}: {ex.Message}");
                throw new InvalidOperationException($"Erro ao aplicar migration {migration.Nome}: {ex.Message}");
            }
        }
        
        return new SincronizacaoResultado
        {
            MigrationsAplicadas = migrationsAplicadas.Count,
            MigrationsAplicadasLista = migrationsAplicadas
        };
    }
    
    public async Task<StatusMigrations> ObterStatus()
    {
        var versaoAtual = await ObterVersaoAtualBancoLocal();
        var online = await IsOnline();
        
        int migrationsPendentes = 0;
        if (online)
        {
            try
            {
                var apiNuvemUrl = _config["ApiNuvem:BaseUrl"];
                using var client = new HttpClient();
                
                var response = await client.GetAsync(
                    $"{apiNuvemUrl}/api/migrations/pendentes?versaoAtual={versaoAtual}"
                );
                
                if (response.IsSuccessStatusCode)
                {
                    var migrations = await response.Content.ReadFromJsonAsync<MigrationsResponse>();
                    migrationsPendentes = migrations?.Migrations?.Count ?? 0;
                }
            }
            catch
            {
                // Ignorar erro
            }
        }
        
        return new StatusMigrations
        {
            VersaoAtual = versaoAtual,
            MigrationsPendentes = migrationsPendentes,
            Online = online
        };
    }
    
    private async Task<string> ObterVersaoAtualBancoLocal()
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<MXCloudDbContext>();
            
            var migrations = await db.Database.GetAppliedMigrationsAsync();
            return migrations.LastOrDefault() ?? "0";
        }
        catch
        {
            return "0";
        }
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

public class SincronizacaoResultado
{
    public int MigrationsAplicadas { get; set; }
    public List<string> MigrationsAplicadasLista { get; set; } = new();
}

public class StatusMigrations
{
    public string VersaoAtual { get; set; } = string.Empty;
    public int MigrationsPendentes { get; set; }
    public bool Online { get; set; }
}
```

---

## 📋 Uso

### **1. Verificar Status:**

```bash
GET http://servidor-local:5100/api/admin/migrations/status

Resposta:
{
  "versaoAtual": "20251221012355",
  "migrationsPendentes": 2,
  "online": true
}
```

### **2. Sincronizar Migrations:**

```bash
POST http://servidor-local:5100/api/admin/migrations/sincronizar

Resposta:
{
  "sucesso": true,
  "mensagem": "2 migration(s) aplicada(s)",
  "migrationsAplicadas": 2,
  "migrations": [
    "20251222000000_CriarLogRequisicoes",
    "20251222000001_OutraMigration"
  ]
}
```

---

## ✅ Vantagens

- ✅ **Manual** - Cliente decide quando atualizar
- ✅ **Controlado** - Não roda automaticamente
- ✅ **Simples** - Apenas chamar endpoint
- ✅ **Seguro** - Migrations vêm do servidor nuvem

**Perfeito! Controle total!** 🚀
