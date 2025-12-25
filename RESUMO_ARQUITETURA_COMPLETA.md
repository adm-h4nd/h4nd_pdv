# 📋 Resumo Detalhado: Arquitetura Servidor Local

## 🎯 Objetivo

Permitir que o sistema funcione normalmente mesmo sem internet, com múltiplas máquinas (PDVs) na mesma rede local, sincronizando automaticamente com a nuvem quando houver conexão.

---

## 🏗️ Arquitetura Geral

```
┌─────────────────────────────────────────────────────────────┐
│                    REDE LOCAL                               │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │   PDV 1  │    │   PDV 2  │    │   PDV 3  │            │
│  │ (Flutter)│    │ (Flutter)│    │ (Flutter)│            │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘            │
│       │               │               │                    │
│       └───────────────┼───────────────┘                    │
│                       │                                      │
│              ┌────────▼────────┐                            │
│              │  SERVIDOR LOCAL  │                            │
│              │   (.NET API)     │                            │
│              │                  │                            │
│              │  ┌────────────┐  │                            │
│              │  │ PostgreSQL │  │                            │
│              │  │   Local    │  │                            │
│              │  └────────────┘  │                            │
│              │                  │                            │
│              │  ┌────────────┐  │                            │
│              │  │ Serviço    │  │                            │
│              │  │ Sync       │  │                            │
│              │  │ (Background)│ │                            │
│              │  └────────────┘  │                            │
│              └────────┬────────┘                            │
│                       │                                      │
└───────────────────────┼───────────────────────────────────────┘
                        │
                        │ (Internet - quando disponível)
                        │
              ┌─────────▼─────────┐
              │   SERVIDOR NUVEM  │
              │   (Backend atual) │
              │   PostgreSQL      │
              └───────────────────┘
```

---

## 🔑 Princípios Fundamentais

### 1. **PDV conhece APENAS servidor local**
- ✅ Uma única URL: `http://servidor-local:3000`
- ✅ Não sabe se está online ou offline
- ✅ Não conhece a nuvem
- ✅ Faz requisições HTTP normais

### 2. **Servidor local gerencia tudo**
- ✅ Recebe todas as requisições do PDV
- ✅ Salva no banco local primeiro
- ✅ Responde imediatamente para PDV
- ✅ Sincroniza com nuvem em background

### 3. **Fila de comandos garante ordem**
- ✅ Todas as operações são gravadas em fila
- ✅ Processadas na mesma ordem que foram criadas
- ✅ Garante consistência dos dados

---

## 🗄️ Banco de Dados Local (PostgreSQL)

### **Estrutura:**

```sql
-- ============================================
-- CACHE (Dados de Leitura - Sincronização Inicial)
-- ============================================

-- Produtos (cache do início do dia)
CREATE TABLE produtos_cache (
  id UUID PRIMARY KEY,
  nome VARCHAR(255) NOT NULL,
  preco DECIMAL(10,2),
  -- ... mesmos campos da tabela Produto do servidor principal
  sincronizado_em TIMESTAMP
);

-- Mesas (cache)
CREATE TABLE mesas_cache (
  id UUID PRIMARY KEY,
  numero VARCHAR(50) NOT NULL,
  status VARCHAR(50),
  -- ... mesmos campos da tabela Mesa
  sincronizado_em TIMESTAMP
);

-- Comandas (cache)
CREATE TABLE comandas_cache (
  id UUID PRIMARY KEY,
  numero VARCHAR(50) NOT NULL,
  status VARCHAR(50),
  -- ... mesmos campos da tabela Comanda
  sincronizado_em TIMESTAMP
);

-- ============================================
-- DADOS LOCAIS (Estado Atual - Dados de Escrita)
-- ============================================

-- Pedidos criados localmente
CREATE TABLE pedidos_local (
  id_local UUID PRIMARY KEY,      -- UUID gerado localmente
  id_remoto UUID,                 -- Preenchido após sync com nuvem
  numero VARCHAR(50),
  tipo INTEGER,
  status VARCHAR(50),
  mesa_id UUID,
  comanda_id UUID,
  total DECIMAL(10,2),
  dados_json JSONB NOT NULL,      -- JSON completo do pedido
  criado_em TIMESTAMP NOT NULL,
  sincronizado BOOLEAN DEFAULT FALSE
);

-- Itens de pedidos
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
  tipo VARCHAR(100) NOT NULL,     -- 'criar_pedido', 'ocupar_mesa', etc
  ordem INTEGER NOT NULL,          -- Ordem sequencial (1, 2, 3...)
  dados JSONB NOT NULL,            -- { endpoint, metodo, body }
  sincronizado BOOLEAN DEFAULT FALSE,
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  criado_em TIMESTAMP NOT NULL,
  sincronizado_em TIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_fila_ordem ON fila_comandos(ordem);
CREATE INDEX idx_fila_sincronizado ON fila_comandos(sincronizado, ordem);
CREATE INDEX idx_pedidos_mesa ON pedidos_local(mesa_id);
```

---

## 🔄 Fluxos Principais

### **1. Sincronização Inicial do Dia**

**Quando:** Servidor local inicia ou botão "Carregar Dados do Dia"

**O que faz:**
```csharp
1. Limpar dados do dia anterior (opcional)
2. Buscar produtos ativos da nuvem
   - Apenas produtos isAtivo = true e isVendavel = true
   - Incluir variações, atributos, composições
3. Salvar em produtos_cache
4. Buscar mesas da nuvem
5. Salvar em mesas_cache
6. Buscar comandas da nuvem
7. Salvar em comandas_cache
8. Resetar status das mesas (zeradas)
9. Limpar fila do dia anterior (opcional)
```

**Resultado:**
- ✅ Base limpa (sem pedidos do dia anterior)
- ✅ Produtos atualizados
- ✅ Mesas/comandas zeradas
- ✅ Pronto para começar o dia

---

### **2. PDV cria pedido**

**Fluxo:**
```
PDV → POST /pedidos
     ↓
API Local:
  1. Gerar ID local (UUID)
  2. Salvar pedido em pedidos_local
  3. Gravar comando na fila_comandos (ordem #1)
     {
       tipo: 'criar_pedido',
       ordem: 1,
       dados: { endpoint: '/pedidos', metodo: 'POST', body: {...} }
     }
  4. Atualizar mesa local (status = 'ocupada')
  5. Gravar comando na fila_comandos (ordem #2)
     {
       tipo: 'ocupar_mesa',
       ordem: 2,
       dados: { endpoint: '/mesas/123/ocupar', metodo: 'POST', body: {...} }
     }
  6. Retornar resposta imediata para PDV ✅
  7. Disparar sincronização (background, não bloqueia)
```

**Resultado:**
- ✅ Pedido salvo localmente
- ✅ Comandos gravados na fila (na ordem)
- ✅ Mesa atualizada localmente
- ✅ PDV recebe resposta imediata

---

### **3. Serviço de Sincronização (Background)**

**Quando executa:**
- Imediatamente após criar operação (não bloqueia)
- Periodicamente (a cada 30 segundos)
- Quando detecta que voltou online

**O que faz:**
```csharp
1. Verificar se está online
2. Buscar comandos pendentes da fila_comandos
   - WHERE sincronizado = FALSE
   - ORDER BY ordem ASC  ← IMPORTANTE: Ordem crescente
3. Para cada comando:
   a. Executar comando na API nuvem
      - POST /pedidos
      - POST /mesas/123/ocupar
      - etc
   b. Se sucesso:
      - Marcar comando como sincronizado = TRUE
      - Atualizar id_remoto se for criar_pedido
   c. Se erro:
      - Incrementar tentativas
      - Salvar erro
      - Continuar com próximo comando
4. Repetir até não ter mais comandos pendentes
```

**Garantia:** Comandos executados na mesma ordem que foram criados ✅

---

### **4. PDV busca pedidos da mesa**

**Fluxo:**
```
PDV → GET /pedidos/por-mesa/123
     ↓
API Local:
  1. Buscar pedidos locais (pedidos_local)
     WHERE mesa_id = '123'
  2. Se online:
     - Buscar também da nuvem
     - Combinar resultados
  3. Retornar todos os pedidos para PDV
```

**Resultado:**
- ✅ PDV sempre recebe dados (local + nuvem se online)
- ✅ Funciona mesmo offline (só dados locais)

---

## 🛠️ Tecnologias

### **Servidor Local:**
- **Linguagem:** .NET 8 (mesma do backend)
- **Framework:** ASP.NET Core
- **Banco:** PostgreSQL Local
- **ORM:** Entity Framework Core
- **HTTP Client:** HttpClient (para API nuvem)

### **PDV:**
- **Linguagem:** Flutter/Dart
- **Mudança:** Apenas URL da API
  ```dart
  // Antes
  final apiUrl = 'https://api.nuvem.com';
  
  // Depois
  final apiUrl = 'http://192.168.1.100:3000';  // Servidor local
  ```

---

## 📋 Estrutura do Projeto

```
ServidorLocal/
├── ServidorLocal.csproj
├── Program.cs                    # Entry point
├── appsettings.json             # Configurações
├── Controllers/
│   ├── PedidosController.cs     # Endpoints pedidos
│   ├── MesasController.cs        # Endpoints mesas
│   ├── ComandasController.cs    # Endpoints comandas
│   └── SyncController.cs         # Endpoints sincronização
├── Services/
│   ├── SyncService.cs           # Serviço de sincronização
│   ├── ApiNuvemService.cs       # Cliente API nuvem
│   └── FilaComandoService.cs    # Gerenciar fila
├── Models/
│   ├── PedidoLocal.cs           # Modelo pedido local
│   ├── MesaCache.cs             # Modelo mesa cache
│   ├── ComandaCache.cs          # Modelo comanda cache
│   └── FilaComando.cs           # Modelo fila comando
├── Data/
│   ├── LocalDbContext.cs        # DbContext
│   └── Migrations/              # Migrations EF Core
└── ...
```

---

## 🔧 Configuração

### **appsettings.json:**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mx_cloud_local;Username=postgres;Password=senha"
  },
  "ApiNuvem": {
    "BaseUrl": "https://api.nuvem.com",
    "Token": "xxx",
    "Timeout": 30000
  },
  "Sync": {
    "IntervalSeconds": 30,
    "MaxRetries": 5,
    "BatchSize": 10
  }
}
```

---

## 📊 Tipos de Comandos na Fila

### **Exemplos:**

```json
// Criar pedido
{
  "tipo": "criar_pedido",
  "ordem": 1,
  "dados": {
    "endpoint": "/pedidos",
    "metodo": "POST",
    "body": {
      "tipo": 2,
      "mesaId": "123",
      "itens": [...]
    }
  }
}

// Ocupar mesa
{
  "tipo": "ocupar_mesa",
  "ordem": 2,
  "dados": {
    "endpoint": "/mesas/123/ocupar",
    "metodo": "POST",
    "body": {
      "pedidoId": "456"
    }
  }
}

// Adicionar item ao pedido
{
  "tipo": "adicionar_item_pedido",
  "ordem": 3,
  "dados": {
    "endpoint": "/pedidos/456/itens",
    "metodo": "POST",
    "body": {
      "produtoId": "789",
      "quantidade": 2
    }
  }
}

// Finalizar pedido
{
  "tipo": "finalizar_pedido",
  "ordem": 4,
  "dados": {
    "endpoint": "/pedidos/456/finalizar",
    "metodo": "POST",
    "body": {}
  }
}

// Registrar pagamento
{
  "tipo": "registrar_pagamento",
  "ordem": 5,
  "dados": {
    "endpoint": "/pedidos/456/pagamentos",
    "metodo": "POST",
    "body": {
      "formaPagamento": "dinheiro",
      "valor": 50.00
    }
  }
}
```

---

## 🔄 Exemplo Completo: Sequência de Operações

### **Cenário: Criar pedido, adicionar item, finalizar**

```
1. PDV → POST /pedidos
   ↓
   API Local:
   - Salva pedido local (id_local: uuid-1)
   - Grava comando #1: POST /pedidos
   - Atualiza mesa local
   - Grava comando #2: POST /mesas/123/ocupar
   - Responde PDV ✅

2. PDV → POST /pedidos/uuid-1/itens
   ↓
   API Local:
   - Salva item local
   - Grava comando #3: POST /pedidos/uuid-1/itens
   - Responde PDV ✅

3. PDV → POST /pedidos/uuid-1/finalizar
   ↓
   API Local:
   - Atualiza pedido local
   - Grava comando #4: POST /pedidos/uuid-1/finalizar
   - Responde PDV ✅

4. Serviço Sync (background):
   ↓
   Processa fila na ordem:
   ✅ Comando #1 → POST /pedidos (nuvem)
      - Sucesso: id_remoto = uuid-nuvem-1
      - Atualiza pedidos_local.id_remoto
   
   ✅ Comando #2 → POST /mesas/123/ocupar (nuvem)
      - Sucesso: mesa ocupada na nuvem
   
   ✅ Comando #3 → POST /pedidos/uuid-nuvem-1/itens (nuvem)
      - Sucesso: item adicionado na nuvem
   
   ✅ Comando #4 → POST /pedidos/uuid-nuvem-1/finalizar (nuvem)
      - Sucesso: pedido finalizado na nuvem
```

**Garantia:** Se enviar na mesma ordem, funciona! ✅

---

## ✅ Vantagens da Arquitetura

### **1. Simplicidade**
- ✅ PDV é apenas cliente HTTP simples
- ✅ Não precisa de lógica offline/online
- ✅ Não precisa de sincronização
- ✅ Mudança mínima no código

### **2. Desacoplamento**
- ✅ PDV não conhece nuvem
- ✅ Servidor local abstrai toda complexidade
- ✅ Fácil trocar servidor nuvem depois

### **3. Performance**
- ✅ Respostas instantâneas (banco local)
- ✅ Sincronização não bloqueia operações
- ✅ Cache otimizado

### **4. Confiabilidade**
- ✅ Funciona mesmo sem internet
- ✅ Dados sempre salvos localmente primeiro
- ✅ Sincronização pode falhar sem afetar PDV
- ✅ Fila garante ordem de execução

### **5. Rastreabilidade**
- ✅ Log completo de todas as operações
- ✅ Fácil debugar problemas
- ✅ Histórico de sincronizações

---

## 📋 Checklist de Implementação

### **Fase 1: Setup Inicial**
- [ ] Instalar PostgreSQL local
- [ ] Criar banco `mx_cloud_local`
- [ ] Criar projeto .NET
- [ ] Configurar Entity Framework Core
- [ ] Configurar connection string

### **Fase 2: Estrutura do Banco**
- [ ] Criar tabelas de cache (produtos_cache, mesas_cache, comandas_cache)
- [ ] Criar tabelas locais (pedidos_local, pedido_itens_local)
- [ ] Criar tabela fila_comandos
- [ ] Criar migrations
- [ ] Aplicar migrations

### **Fase 3: API Local**
- [ ] Criar controllers (Pedidos, Mesas, Comandas)
- [ ] Implementar endpoints de leitura (GET)
- [ ] Implementar endpoints de escrita (POST, PUT, DELETE)
- [ ] Implementar gravação na fila de comandos
- [ ] Testar endpoints

### **Fase 4: Sincronização Inicial**
- [ ] Implementar sincronização inicial do dia
- [ ] Buscar produtos da nuvem
- [ ] Buscar mesas/comandas da nuvem
- [ ] Salvar em cache local
- [ ] Testar sincronização

### **Fase 5: Serviço de Sincronização**
- [ ] Criar SyncService
- [ ] Implementar processamento da fila
- [ ] Implementar execução de comandos na nuvem
- [ ] Implementar retry automático
- [ ] Implementar detecção de online/offline
- [ ] Testar sincronização

### **Fase 6: Integração PDV**
- [ ] Mudar URL da API no PDV
- [ ] Testar criação de pedidos
- [ ] Testar busca de pedidos
- [ ] Testar operações offline
- [ ] Testar sincronização quando volta online

---

## 🎯 Resumo Final

### **Arquitetura:**
```
PDV → Servidor Local → (background) → Nuvem
     (única conexão)   (sincronização)
```

### **Tecnologias:**
- **Servidor Local:** .NET 8 + ASP.NET Core + PostgreSQL Local
- **PDV:** Flutter (mudança mínima: apenas URL)
- **Banco:** PostgreSQL (mesmo do servidor principal)

### **Princípios:**
1. PDV conhece apenas servidor local
2. Servidor local gerencia tudo
3. Fila de comandos garante ordem
4. Sincronização em background

### **Resultado:**
- ✅ Sistema funciona offline
- ✅ Sincronização automática quando volta online
- ✅ Múltiplos PDVs compartilham dados
- ✅ Mudança mínima no código
- ✅ Fácil de manter e debugar

**É isso! Arquitetura completa e funcional!** 🚀
