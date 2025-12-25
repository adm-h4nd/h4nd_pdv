# 🏗️ Arquitetura: Servidor Local + Sincronização com Nuvem

## 🎯 Visão Geral

**Problema:** Sistema precisa funcionar mesmo sem internet, mas com múltiplas máquinas na mesma rede local.

**Solução:** Servidor local na rede que funciona como cache/proxy entre PDVs e nuvem.

---

## 🏛️ Arquitetura Proposta

```
┌─────────────────────────────────────────────────────────────┐
│                    REDE LOCAL                                │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │   PDV 1  │    │   PDV 2  │    │   PDV 3  │              │
│  │ (Flutter)│    │ (Flutter)│    │ (Flutter)│              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                      │
│       └───────────────┼───────────────┘                      │
│                       │                                      │
│              ┌────────▼────────┐                            │
│              │  SERVIDOR LOCAL │                            │
│              │   (Node.js/.NET) │                            │
│              │   + SQLite/PostgreSQL                        │
│              └────────┬────────┘                            │
│                       │                                      │
└───────────────────────┼───────────────────────────────────────┘
                        │
                        │ (Internet - quando disponível)
                        │
              ┌─────────▼─────────┐
              │   SERVIDOR NUVEM  │
              │   (Backend atual) │
              └───────────────────┘
```

---

## 🔄 Fluxo de Funcionamento

### 1. **Inicialização do Dia**

**Quando o servidor local inicia:**

1. **Carrega dados do dia** da nuvem (se tiver internet):
   - Produtos ativos
   - Mesas/Comandas disponíveis
   - Configurações
   - Estoque inicial do dia
   - Pedidos do dia (se houver)

2. **Salva tudo localmente** (SQLite/PostgreSQL local)

3. **PDVs se conectam** ao servidor local (HTTP REST API)

### 2. **Operação Normal (Online)**

```
PDV → Servidor Local → Nuvem
     (cache rápido)   (sincronização)
```

- PDV faz requisição ao servidor local
- Servidor local responde imediatamente (cache)
- Servidor local sincroniza com nuvem em background

### 3. **Operação Offline**

```
PDV → Servidor Local (funciona normalmente)
     (sem internet)
```

- PDV continua funcionando normalmente
- Servidor local armazena todas as operações
- Quando volta internet: sincroniza tudo

### 4. **Sincronização Manual/Automática**

**Quando sincronizar:**
- Manual: Botão "Sincronizar" no servidor local
- Automática: A cada X minutos (configurável)
- Automática: Quando volta internet

**O que sincroniza:**
- Envia: Pedidos criados/modificados
- Envia: Atualizações de estoque
- Recebe: Novos produtos/configurações
- Recebe: Atualizações de outros PDVs (se houver)

---

## 🛠️ Tecnologias Recomendadas

### Opção 1: Node.js + Express + SQLite (Mais Simples)

**Vantagens:**
- ✅ Rápido de desenvolver
- ✅ SQLite é simples (arquivo único)
- ✅ JavaScript/TypeScript (mesma stack do frontend se usar)
- ✅ Leve e portável

**Stack:**
- Node.js + Express
- SQLite (via `better-sqlite3` ou `sql.js`)
- REST API simples

### Opção 2: .NET + ASP.NET Core + SQLite (Mesma Stack do Backend)

**Vantagens:**
- ✅ Mesma linguagem do backend atual
- ✅ Pode reutilizar código/DTOs
- ✅ Fácil integração com backend existente
- ✅ Performance excelente

**Stack:**
- .NET 8 + ASP.NET Core
- SQLite (via Entity Framework Core)
- REST API

### Opção 3: Python + FastAPI + SQLite (Rápido de Prototipar)

**Vantagens:**
- ✅ Muito rápido de desenvolver
- ✅ SQLite simples
- ✅ Boa para prototipagem

---

## 📊 Estrutura do Banco Local

### Tabelas Principais

```sql
-- Cache de produtos (do dia)
CREATE TABLE produtos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  preco REAL,
  estoque REAL,
  -- ... outros campos necessários
  sincronizado_em DATETIME,
  versao INTEGER  -- Para controle de conflitos
);

-- Pedidos locais (pendentes de sync)
CREATE TABLE pedidos_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,  -- Preenchido após sync
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  total REAL,
  criado_em DATETIME,
  sincronizado BOOLEAN DEFAULT 0,
  tentativas_sync INTEGER DEFAULT 0,
  ultimo_erro TEXT
);

-- Itens de pedidos
CREATE TABLE pedido_itens_local (
  id TEXT PRIMARY KEY,
  pedido_id_local TEXT,
  produto_id TEXT,
  quantidade REAL,
  preco_unitario REAL,
  FOREIGN KEY(pedido_id_local) REFERENCES pedidos_local(id_local)
);

-- Log de sincronização
CREATE TABLE sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tipo TEXT,  -- 'pedido', 'produto', etc
  operacao TEXT,  -- 'create', 'update', 'delete'
  dados TEXT,  -- JSON
  sucesso BOOLEAN,
  erro TEXT,
  criado_em DATETIME
);
```

---

## 🔌 API do Servidor Local

### Endpoints Principais

```http
# Produtos
GET    /api/produtos                    # Lista produtos (cache local)
GET    /api/produtos/:id                 # Detalhes produto

# Pedidos
GET    /api/pedidos                      # Lista pedidos do dia
POST   /api/pedidos                      # Criar pedido (salva local)
PUT    /api/pedidos/:id                  # Atualizar pedido
DELETE /api/pedidos/:id                  # Cancelar pedido

# Mesas/Comandas
GET    /api/mesas                        # Lista mesas
GET    /api/comandas                     # Lista comandas

# Sincronização
POST   /api/sync/iniciar                 # Iniciar sincronização manual
GET    /api/sync/status                  # Status da sincronização
GET    /api/sync/pendentes               # Quantidade de itens pendentes
```

---

## 🔄 Lógica de Sincronização

### Fluxo de Sincronização

```javascript
async function sincronizar() {
  // 1. Enviar pedidos pendentes
  const pedidosPendentes = await db.pedidos_local.findAll({
    where: { sincronizado: false }
  });
  
  for (const pedido of pedidosPendentes) {
    try {
      const response = await apiNuvem.post('/pedidos', pedido);
      await db.pedidos_local.update({
        id_remoto: response.data.id,
        sincronizado: true
      }, { where: { id_local: pedido.id_local } });
    } catch (error) {
      // Log erro, incrementa tentativas
    }
  }
  
  // 2. Buscar atualizações da nuvem
  const ultimaSync = await db.getUltimaSync();
  const atualizacoes = await apiNuvem.get('/sync/atualizacoes', {
    params: { desde: ultimaSync }
  });
  
  // 3. Atualizar cache local
  for (const produto of atualizacoes.produtos) {
    await db.produtos_cache.upsert(produto);
  }
  
  // 4. Atualizar timestamp de sincronização
  await db.setUltimaSync(new Date());
}
```

---

## 📱 Mudanças no PDV (Flutter)

### Antes (conectava direto na nuvem):
```dart
final apiUrl = 'https://api.nuvem.com';
```

### Depois (conecta no servidor local):
```dart
final apiUrl = 'http://192.168.1.100:3000';  // IP do servidor local
```

**Isso é tudo!** O PDV não precisa saber se está online ou offline. O servidor local resolve tudo.

---

## 🚀 Vantagens desta Arquitetura

### ✅ Simplicidade
- PDV é apenas cliente HTTP (sem lógica offline complexa)
- Toda lógica offline fica no servidor local
- Fácil de manter e debugar

### ✅ Performance
- Respostas instantâneas (servidor local na mesma rede)
- Cache local reduz latência
- Sincronização em background não bloqueia operações

### ✅ Escalabilidade
- Múltiplos PDVs podem usar o mesmo servidor
- Servidor local pode ser um PC simples na rede
- Fácil adicionar mais PDVs

### ✅ Confiabilidade
- Funciona mesmo sem internet
- Dados sempre salvos localmente primeiro
- Sincronização pode ser retentada sem perder dados

### ✅ Manutenção
- Atualizações centralizadas (servidor local)
- Logs centralizados
- Fácil fazer backup do banco local

---

## 📋 Checklist de Implementação

### Fase 1: Servidor Local Básico
- [ ] Escolher tecnologia (Node.js ou .NET)
- [ ] Criar estrutura básica do servidor
- [ ] Configurar banco local (SQLite)
- [ ] Criar API REST básica
- [ ] Testar conexão do PDV

### Fase 2: Cache de Dados
- [ ] Endpoint para carregar dados do dia
- [ ] Salvar produtos/configurações localmente
- [ ] Endpoint para buscar produtos (cache)
- [ ] Testar funcionamento offline

### Fase 3: Operações de Escrita
- [ ] Endpoint para criar pedidos (salvar local)
- [ ] Endpoint para atualizar pedidos
- [ ] Endpoint para cancelar pedidos
- [ ] Testar operações offline

### Fase 4: Sincronização
- [ ] Implementar sincronização com nuvem
- [ ] Enviar pedidos pendentes
- [ ] Receber atualizações da nuvem
- [ ] Tratamento de erros e retry
- [ ] Interface para sincronização manual

### Fase 5: PDV
- [ ] Mudar URL da API para servidor local
- [ ] Configurar IP do servidor local
- [ ] Testar funcionamento completo

---

## 🎯 Decisões a Tomar

### 1. **Onde rodar o servidor local?**

**Opção A:** PC dedicado na rede
- ✅ Sempre ligado
- ✅ Mais confiável
- ❌ Precisa de hardware dedicado

**Opção B:** Um dos PDVs (modo servidor)
- ✅ Não precisa hardware extra
- ❌ Precisa estar ligado sempre
- ❌ Pode impactar performance do PDV

**Opção C:** Servidor físico pequeno (Raspberry Pi, Mini PC)
- ✅ Barato
- ✅ Consome pouca energia
- ✅ Pode deixar sempre ligado

**Recomendação:** Opção C (Mini PC ou Raspberry Pi)

### 2. **Como descobrir o IP do servidor local?**

**Opção A:** Configuração manual no PDV
- ✅ Simples
- ❌ Precisa configurar em cada PDV

**Opção B:** Descoberta automática (mDNS/Bonjour)
- ✅ Automático
- ✅ Mais fácil para usuário
- ❌ Mais complexo de implementar

**Recomendação:** Opção A inicialmente, migrar para B depois

### 3. **Banco de dados local?**

**SQLite:**
- ✅ Simples (arquivo único)
- ✅ Não precisa instalar servidor
- ✅ Perfeito para servidor local
- ✅ Fácil backup (copiar arquivo)

**PostgreSQL:**
- ✅ Mais robusto
- ✅ Melhor para múltiplas conexões simultâneas
- ❌ Precisa instalar e configurar

**Recomendação:** SQLite (mais simples, suficiente para servidor local)

---

## 🔧 Configuração do Servidor Local

### Variáveis de Ambiente

```env
# Porta do servidor local
PORT=3000

# URL da API nuvem
API_NUVEM_URL=https://api.nuvem.com

# Token de autenticação
API_NUVEM_TOKEN=xxx

# Intervalo de sincronização (minutos)
SYNC_INTERVAL=5

# Modo offline (não tenta conectar na nuvem)
OFFLINE_MODE=false
```

---

## 📊 Monitoramento

### Dashboard do Servidor Local

Interface web simples para:
- Ver status de sincronização
- Ver pedidos pendentes
- Iniciar sincronização manual
- Ver logs
- Ver estatísticas do dia

---

## 🎯 Próximos Passos

1. **Decidir tecnologia** (Node.js ou .NET)
2. **Criar servidor local básico**
3. **Implementar cache de produtos**
4. **Implementar operações de pedidos**
5. **Implementar sincronização**
6. **Configurar PDV para usar servidor local**
7. **Testar cenários offline/online**

---

## ❓ Perguntas Frequentes

### 1. E se o servidor local cair?

**Solução:** Ter backup automático do banco SQLite. Se cair, restaurar backup e continuar.

### 2. E se dois servidores locais estiverem na mesma rede?

**Solução:** Cada loja/filial tem seu próprio servidor local. Não há conflito.

### 3. E se houver conflito ao sincronizar?

**Solução:** Servidor nuvem resolve conflitos. Servidor local recebe resposta e atualiza.

### 4. Quanto espaço precisa no servidor local?

**Solução:** Pouco. Apenas dados do dia. SQLite de alguns MB é suficiente.

### 5. Precisa de internet sempre?

**Solução:** Não. Servidor local funciona offline. Sincroniza quando tiver internet.

---

## 🎉 Resultado Final

Com esta arquitetura:
- ✅ PDVs funcionam normalmente mesmo sem internet
- ✅ Respostas rápidas (servidor local na rede)
- ✅ Sincronização automática quando tem internet
- ✅ Múltiplos PDVs compartilham os mesmos dados
- ✅ PDV fica simples (apenas cliente HTTP)
- ✅ Fácil de manter e debugar

**É a solução perfeita para o seu caso!** 🚀
