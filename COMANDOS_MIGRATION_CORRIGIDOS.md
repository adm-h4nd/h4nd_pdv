# 📋 Comandos para Criar Migration (Corrigido)

## 🎯 Migration no MXCloudDbContext (Servidor Normal)

A migration deve ser criada no **MXCloudDbContext** (servidor normal), não no LocalDbContext.

---

## 🔧 Comandos Corretos

### **1. Navegar até a pasta da API:**

```bash
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API
```

### **2. Criar Migration (no MXCloudDbContext):**

```bash
dotnet ef migrations add CriarLogRequisicoes
```

**Nota:** Não precisa especificar `--context` porque o padrão é `MXCloudDbContext`.

### **3. Aplicar Migration:**

```bash
dotnet ef database update
```

---

## 📋 Comandos Completos (Copiar e Colar)

```bash
# 1. Ir para pasta da API
cd /Users/claudiocamargos/Documents/GitHub/NSN/mx_cloud/MXCloud.API

# 2. Criar migration (no MXCloudDbContext)
dotnet ef migrations add CriarLogRequisicoes

# 3. Aplicar migration
dotnet ef database update
```

---

## ✅ O que Foi Ajustado

1. ✅ Adicionado `LogRequisicao` ao `MXCloudDbContext`
2. ✅ Criada configuração `LogRequisicaoConfiguration`
3. ✅ `LocalDbContext` reutiliza a mesma configuração
4. ✅ Migration será criada no contexto principal

---

## 🎯 Resultado

A tabela `log_requisicoes` será criada no banco principal (tanto nuvem quanto local).

Quando rodar como servidor local (`IsLocal = true`), o `LocalDbContext` também terá acesso à mesma tabela.

**Agora pode rodar os comandos!** 🚀
