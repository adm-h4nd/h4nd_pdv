# 📋 Instruções: Criar Migration para log_requisicoes

## 🎯 Próximo Passo: Criar Migration

Agora que criamos todos os arquivos, precisamos criar a migration para a tabela `log_requisicoes`.

---

## 🔧 Comandos para Criar Migration

### **1. Navegar até a pasta da API:**

```bash
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API
```

### **2. Criar Migration:**

```bash
dotnet ef migrations add CriarLogRequisicoes --context LocalDbContext
```

### **3. Aplicar Migration (se tiver banco local configurado):**

```bash
dotnet ef database update --context LocalDbContext
```

---

## ✅ Arquivos Criados

### **1. Modelo:**
- ✅ `MXCloud.Domain/Entities/Core/LogRequisicao.cs`

### **2. DbContext:**
- ✅ `MXCloud.Infrastructure/Data/LocalDbContext.cs`

### **3. Middleware:**
- ✅ `MXCloud.API/Middleware/LogRequisicaoMiddleware.cs`

### **4. Serviço de Sincronização:**
- ✅ `MXCloud.API/Services/SyncService.cs`

### **5. Configurações:**
- ✅ `MXCloud.API/appsettings.Local.json`
- ✅ `MXCloud.Infrastructure/DependencyInjection.cs` (atualizado)
- ✅ `MXCloud.API/Program.cs` (atualizado)

---

## 📋 Próximos Passos Após Migration

1. **Configurar appsettings.Local.json:**
   - Ajustar connection string do PostgreSQL local
   - Configurar `ApiNuvem:BaseUrl`
   - Configurar mesma chave JWT do servidor nuvem

2. **Testar localmente:**
   - Rodar API com `appsettings.Local.json`
   - Fazer requisições e verificar log
   - Verificar sincronização

3. **Configurar PDV:**
   - Mudar URL da API para servidor local
   - Testar funcionamento

---

## 🎉 Status da Implementação

- ✅ Modelo criado
- ✅ DbContext criado
- ✅ Middleware criado
- ✅ Serviço de sync criado
- ✅ Configurações atualizadas
- ⏳ Migration (próximo passo)

**Quase lá!** 🚀

