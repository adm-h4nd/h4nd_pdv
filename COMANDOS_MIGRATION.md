# 📋 Comandos para Criar e Aplicar Migration

## 🎯 Comandos Necessários

### **1. Navegar até a pasta da API:**

```bash
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API
```

### **2. Criar Migration:**

```bash
dotnet ef migrations add CriarLogRequisicoes --context LocalDbContext
```

### **3. Aplicar Migration:**

```bash
dotnet ef database update --context LocalDbContext
```

---

## 📋 Comandos Completos (Copiar e Colar)

```bash
# 1. Ir para pasta da API
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API

# 2. Criar migration
dotnet ef migrations add CriarLogRequisicoes --context LocalDbContext

# 3. Aplicar migration
dotnet ef database update --context LocalDbContext
```

---

## ⚠️ Importante

### **Antes de rodar:**

1. **Configurar connection string** no `appsettings.Local.json`:
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=postgres;Password=sua_senha"
     }
   }
   ```

2. **Criar banco PostgreSQL local** (se ainda não criou):
   ```sql
   CREATE DATABASE mx_cloud_local;
   ```

3. **Definir ambiente** (opcional, mas recomendado):
   ```bash
   export ASPNETCORE_ENVIRONMENT=Local
   ```

---

## ✅ Verificar se Funcionou

### **Após aplicar migration:**

```bash
# Conectar no PostgreSQL
psql -U postgres -d mx_cloud_local

# Verificar se tabela foi criada
\dt log_requisicoes

# Ver estrutura da tabela
\d log_requisicoes
```

**Se aparecer a tabela, está funcionando!** ✅

---

## 🔍 Troubleshooting

### **Erro: "No DbContext named 'LocalDbContext' was found"**

**Solução:** Verificar se `LocalDbContext` está registrado no `DependencyInjection.cs` quando `IsLocal = true`.

### **Erro: "Connection string not found"**

**Solução:** Verificar se `appsettings.Local.json` tem a connection string configurada.

### **Erro: "Database does not exist"**

**Solução:** Criar banco primeiro:
```sql
CREATE DATABASE mx_cloud_local;
```

---

## 🎉 Pronto!

Após aplicar a migration, a tabela `log_requisicoes` estará criada e pronta para uso!
