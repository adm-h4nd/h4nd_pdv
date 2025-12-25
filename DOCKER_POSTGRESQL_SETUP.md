# 🐳 Setup PostgreSQL no Docker (Mac)

## 🎯 Objetivo

Instalar PostgreSQL local usando Docker para desenvolvimento do servidor local.

---

## 🚀 Comandos para Instalar

### **1. Baixar e Rodar PostgreSQL:**

```bash
docker run --name mx-cloud-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -p 5432:5432 \
  -d postgres:16
```

**O que faz:**
- `--name mx-cloud-postgres` → Nome do container
- `-e POSTGRES_PASSWORD=postgres` → Senha do usuário postgres
- `-e POSTGRES_USER=postgres` → Usuário padrão
- `-p 5432:5432` → Porta 5432 (padrão PostgreSQL)
- `-d` → Rodar em background
- `postgres:16` → Imagem PostgreSQL versão 16

### **2. Verificar se está rodando:**

```bash
docker ps
```

**Deve aparecer:**
```
CONTAINER ID   IMAGE         COMMAND                  STATUS         PORTS                    NAMES
xxx            postgres:16   "docker-entrypoint.s…"   Up X seconds   0.0.0.0:5432->5432/tcp   mx-cloud-postgres
```

### **3. Criar banco de dados:**

```bash
docker exec -it mx-cloud-postgres psql -U postgres -c "CREATE DATABASE mx_cloud_local;"
```

### **4. Verificar se banco foi criado:**

```bash
docker exec -it mx-cloud-postgres psql -U postgres -c "\l"
```

**Deve aparecer `mx_cloud_local` na lista.**

---

## 📋 Comandos Úteis

### **Parar container:**

```bash
docker stop mx-cloud-postgres
```

### **Iniciar container:**

```bash
docker start mx-cloud-postgres
```

### **Remover container (se necessário):**

```bash
docker stop mx-cloud-postgres
docker rm mx-cloud-postgres
```

### **Acessar PostgreSQL:**

```bash
docker exec -it mx-cloud-postgres psql -U postgres -d mx_cloud_local
```

### **Ver logs:**

```bash
docker logs mx-cloud-postgres
```

---

## 🔧 Configuração no appsettings.Local.json

Após instalar, configure:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=postgres;Password=postgres"
  }
}
```

---

## ✅ Verificação Final

### **Testar conexão:**

```bash
docker exec -it mx-cloud-postgres psql -U postgres -d mx_cloud_local -c "SELECT version();"
```

**Se aparecer a versão do PostgreSQL, está funcionando!** ✅

---

## 🎯 Próximos Passos

1. ✅ PostgreSQL rodando no Docker
2. ⏳ Configurar `appsettings.Local.json`
3. ⏳ Criar migration
4. ⏳ Aplicar migration

**Pronto para começar!** 🚀
