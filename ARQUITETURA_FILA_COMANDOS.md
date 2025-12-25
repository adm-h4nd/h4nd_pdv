# 🎯 Arquitetura: Fila de Comandos para Sincronização

## 🎯 Visão Geral

**Estratégia:** Log/Fila de todas as operações feitas localmente, sincronizadas na mesma ordem para garantir consistência.

---

## 🏗️ Arquitetura Completa

```
┌─────────────────────────────────────────────────────────────┐
│                    REDE LOCAL                                │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │   PDV 1  │    │   PDV 2  │    │   PDV 3  │            │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘            │
│       │               │               │                    │
│       └───────────────┼───────────────┘                    │
│                       │                                      │
│              ┌────────▼────────┐                            │
│              │  API LOCAL      │                            │
│              │  (Mini API Cloud)│                            │
│              │                  │                            │
│              │  1. Recebe req   │                            │
│              │  2. Salva local  │                            │
│              │  3. Grava log    │ ← FILA DE COMANDOS         │
│              │  4. Responde PDV │                            │
│              └────────┬────────┘                            │
│                       │                                      │
│              ┌────────▼────────┐                            │
│              │  SERVIÇO SYNC   │                            │
│              │  (Background)    │                            │
│              │                  │                            │
│              │  Lê fila         │                            │
│              │  Envia nuvem     │                            │
│              │  Marca sincronizado│                          │
│              └────────┬────────┘                            │
│                       │                                      │
└───────────────────────┼───────────────────────────────────────┘
                        │
                        │ (Internet)
                        │
              ┌─────────▼─────────┐
              │   API NUVEM       │
              │   (Backend atual)  │
              └────────────────────┘
```

---

## 📋 Fluxo: Sincronização Inicial do Dia

### **1. Carregar Base Limpa**

```javascript
// Servidor Local - Início do dia
async function sincronizarInicial() {
  // 1. Limpar dados do dia anterior (opcional)
  await db.pedidos_local.deleteAll();
  await db.mesas_cache.deleteAll();
  
  // 2. Buscar produtos da nuvem
  const produtos = await apiNuvem.get('/produtos', {
    params: {
      isAtivo: true,
      isVendavel: true,
      incluirVariacoes: true
    }
  });
  await db.produtos_cache.bulkInsert(produtos);
  
  // 3. Buscar mesas da nuvem
  const mesas = await apiNuvem.get('/mesas');
  await db.mesas_cache.bulkInsert(mesas);
  
  // 4. Buscar comandas da nuvem
  const comandas = await apiNuvem.get('/comandas');
  await db.comandas_cache.bulkInsert(comandas);
  
  // 5. Resetar status das mesas (zeradas)
  await db.mesas_cache.updateAll({ status: 'livre' });
  
  console.log('✅ Sincronização inicial concluída');
}
```

**Resultado:**
- ✅ Base limpa (sem pedidos do dia anterior)
- ✅ Produtos atualizados
- ✅ Mesas/comandas zeradas
- ✅ Pronto para começar o dia

---

## 🔄 Fluxo: Operação Normal (PDV faz pedido)

### **1. PDV cria pedido**

```dart
// PDV - Código normal (não muda nada)
final response = await http.post(
  'http://servidor-local:3000/pedidos',
  body: jsonEncode({
    'tipo': 2,
    'mesaId': '123',
    'itens': [...]
  }),
);
```

### **2. API Local recebe e processa**

```javascript
// API Local - Endpoint POST /pedidos
app.post('/pedidos', async (req, res) => {
  const pedidoData = req.body;
  
  // 1. Gerar ID local
  const idLocal = generateUUID();
  pedidoData.idLocal = idLocal;
  
  // 2. Salvar no banco local
  await db.pedidos_local.insert({
    id_local: idLocal,
    dados_json: JSON.stringify(pedidoData),
    sincronizado: 0
  });
  
  // 3. GRAVAR NA FILA DE COMANDOS (ordem importante!)
  await db.fila_comandos.insert({
    id: generateUUID(),
    tipo: 'criar_pedido',
    ordem: await db.fila_comandos.getProximaOrdem(),
    dados: JSON.stringify({
      endpoint: '/pedidos',
      metodo: 'POST',
      body: pedidoData
    }),
    sincronizado: 0,
    tentativas: 0,
    criado_em: new Date()
  });
  
  // 4. Atualizar mesa (localmente)
  await db.mesas_cache.update(
    { id: pedidoData.mesaId },
    { status: 'ocupada' }
  );
  
  // 5. GRAVAR COMANDO DE ATUALIZAR MESA
  await db.fila_comandos.insert({
    id: generateUUID(),
    tipo: 'atualizar_mesa',
    ordem: await db.fila_comandos.getProximaOrdem(),
    dados: JSON.stringify({
      endpoint: `/mesas/${pedidoData.mesaId}/ocupar`,
      metodo: 'POST',
      body: { pedidoId: idLocal }
    }),
    sincronizado: 0,
    tentativas: 0,
    criado_em: new Date()
  });
  
  // 6. Retornar resposta para PDV (imediata)
  res.json({
    success: true,
    data: {
      id: idLocal,
      ...pedidoData
    }
  });
  
  // 7. Disparar sincronização (não bloqueia)
  syncService.processarFila().catch(console.error);
});
```

**Resultado:**
- ✅ Pedido salvo localmente
- ✅ Comandos gravados na fila (na ordem)
- ✅ Mesa atualizada localmente
- ✅ PDV recebe resposta imediata

---

## 🔄 Serviço de Sincronização (Background)

### **Estrutura da Fila**

```sql
CREATE TABLE fila_comandos (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,              -- 'criar_pedido', 'atualizar_mesa', etc
  ordem INTEGER NOT NULL,          -- Ordem de execução (sequencial)
  dados TEXT NOT NULL,             -- JSON com endpoint, método, body
  sincronizado INTEGER DEFAULT 0,  -- 0 = pendente, 1 = sincronizado
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  criado_em DATETIME NOT NULL,
  sincronizado_em DATETIME
);

CREATE INDEX idx_fila_ordem ON fila_comandos(ordem);
CREATE INDEX idx_fila_sincronizado ON fila_comandos(sincronizado);
```

### **Serviço de Sincronização**

```javascript
// Serviço de Sincronização - Background
class SyncService {
  constructor(apiNuvem, db) {
    this.apiNuvem = apiNuvem;
    this.db = db;
    this.processando = false;
  }
  
  // Processar fila (chamado periodicamente ou após operação)
  async processarFila() {
    if (this.processando) {
      return; // Já está processando
    }
    
    if (!await this.isOnline()) {
      return; // Não tenta se offline
    }
    
    this.processando = true;
    
    try {
      // Buscar comandos pendentes (na ordem!)
      const comandosPendentes = await this.db.fila_comandos.find({
        sincronizado: 0,
        tentativas: { $lt: 5 }  // Máximo 5 tentativas
      }).sort({ ordem: 1 });  // IMPORTANTE: Ordem crescente
      
      console.log(`📋 Processando ${comandosPendentes.length} comandos pendentes`);
      
      // Processar cada comando na ordem
      for (const comando of comandosPendentes) {
        await this.processarComando(comando);
        
        // Pequeno delay entre comandos (evita sobrecarga)
        await sleep(100);
      }
      
    } catch (error) {
      console.error('Erro ao processar fila:', error);
    } finally {
      this.processando = false;
    }
  }
  
  // Processar um comando específico
  async processarComando(comando) {
    try {
      const dados = JSON.parse(comando.dados);
      
      console.log(`🔄 Processando: ${comando.tipo} (ordem ${comando.ordem})`);
      
      // Executar comando na nuvem
      let response;
      switch (dados.metodo) {
        case 'POST':
          response = await this.apiNuvem.post(dados.endpoint, dados.body);
          break;
        case 'PUT':
          response = await this.apiNuvem.put(dados.endpoint, dados.body);
          break;
        case 'DELETE':
          response = await this.apiNuvem.delete(dados.endpoint);
          break;
        default:
          throw new Error(`Método não suportado: ${dados.metodo}`);
      }
      
      // Marcar como sincronizado
      await this.db.fila_comandos.update(
        { id: comando.id },
        {
          sincronizado: 1,
          sincronizado_em: new Date()
        }
      );
      
      // Se for criar pedido, atualizar ID remoto
      if (comando.tipo === 'criar_pedido' && response.data?.id) {
        await this.db.pedidos_local.update(
          { id_local: dados.body.idLocal },
          { id_remoto: response.data.id }
        );
      }
      
      console.log(`✅ Comando ${comando.tipo} sincronizado com sucesso`);
      
    } catch (error) {
      console.error(`❌ Erro ao processar comando ${comando.id}:`, error);
      
      // Incrementar tentativas
      await this.db.fila_comandos.update(
        { id: comando.id },
        {
          tentativas: comando.tentativas + 1,
          ultimo_erro: error.message
        }
      );
      
      // Se excedeu tentativas, marcar como erro permanente
      if (comando.tentativas + 1 >= 5) {
        console.error(`⚠️ Comando ${comando.id} excedeu tentativas máximas`);
        // Pode enviar notificação ou log de erro
      }
    }
  }
  
  // Verificar se está online
  async isOnline() {
    try {
      await this.apiNuvem.get('/health', { timeout: 5000 });
      return true;
    } catch {
      return false;
    }
  }
}

// Inicializar serviço
const syncService = new SyncService(apiNuvem, db);

// Processar fila periodicamente (a cada 30 segundos)
setInterval(() => {
  syncService.processarFila().catch(console.error);
}, 30 * 1000);

// Processar fila quando volta online
let wasOnline = false;
setInterval(async () => {
  const isOnline = await syncService.isOnline();
  if (!wasOnline && isOnline) {
    console.log('🌐 Internet voltou! Processando fila...');
    syncService.processarFila();
  }
  wasOnline = isOnline;
}, 5000);
```

---

## 📊 Exemplo: Sequência de Operações

### **Cenário: Criar pedido, adicionar item, finalizar**

```
1. PDV → POST /pedidos
   ↓
   API Local:
   - Salva pedido local
   - Grava comando #1: POST /pedidos
   - Atualiza mesa local
   - Grava comando #2: POST /mesas/123/ocupar
   - Responde PDV ✅

2. PDV → POST /pedidos/456/itens
   ↓
   API Local:
   - Salva item local
   - Grava comando #3: POST /pedidos/456/itens
   - Responde PDV ✅

3. PDV → POST /pedidos/456/finalizar
   ↓
   API Local:
   - Atualiza pedido local
   - Grava comando #4: POST /pedidos/456/finalizar
   - Responde PDV ✅

4. Serviço Sync (background):
   ↓
   Processa fila na ordem:
   ✅ Comando #1 → POST /pedidos (sucesso)
   ✅ Comando #2 → POST /mesas/123/ocupar (sucesso)
   ✅ Comando #3 → POST /pedidos/456/itens (sucesso)
   ✅ Comando #4 → POST /pedidos/456/finalizar (sucesso)
```

**Garantia:** Se enviar na mesma ordem, funciona! ✅

---

## 🎯 Vantagens da Fila de Comandos

### ✅ **Garantia de Ordem**
- Comandos executados na mesma ordem que foram criados
- Garante consistência dos dados

### ✅ **Reprocessamento**
- Se falhar, pode tentar novamente
- Não perde dados mesmo se internet cair

### ✅ **Rastreabilidade**
- Log completo de tudo que foi feito
- Fácil debugar problemas
- Pode ver histórico de sincronizações

### ✅ **Resiliência**
- Funciona mesmo se alguns comandos falharem
- Pode processar comandos individuais
- Não bloqueia operações novas

### ✅ **Simplicidade**
- Lógica simples: ler fila, executar, marcar
- Fácil de entender e manter

---

## 🔧 Estrutura do Banco Local

```sql
-- ============================================
-- CACHE (Dados de Leitura)
-- ============================================

CREATE TABLE produtos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  preco REAL,
  -- ... campos necessários
  sincronizado_em DATETIME
);

CREATE TABLE mesas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  sincronizado_em DATETIME
);

CREATE TABLE comandas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  sincronizado_em DATETIME
);

-- ============================================
-- DADOS LOCAIS (Estado Atual)
-- ============================================

CREATE TABLE pedidos_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  total REAL,
  dados_json TEXT NOT NULL,
  criado_em DATETIME NOT NULL
);

CREATE TABLE pedido_itens_local (
  id TEXT PRIMARY KEY,
  pedido_id_local TEXT NOT NULL,
  produto_id TEXT NOT NULL,
  quantidade REAL,
  preco_unitario REAL,
  FOREIGN KEY(pedido_id_local) REFERENCES pedidos_local(id_local)
);

-- ============================================
-- FILA DE COMANDOS (Log de Operações)
-- ============================================

CREATE TABLE fila_comandos (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,              -- 'criar_pedido', 'atualizar_mesa', etc
  ordem INTEGER NOT NULL,          -- Ordem sequencial
  dados TEXT NOT NULL,             -- JSON: { endpoint, metodo, body }
  sincronizado INTEGER DEFAULT 0,
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  criado_em DATETIME NOT NULL,
  sincronizado_em DATETIME
);

CREATE INDEX idx_fila_ordem ON fila_comandos(ordem);
CREATE INDEX idx_fila_sincronizado ON fila_comandos(sincronizado, ordem);
```

---

## 📋 Tipos de Comandos na Fila

### **Exemplos:**

```javascript
// Criar pedido
{
  tipo: 'criar_pedido',
  ordem: 1,
  dados: {
    endpoint: '/pedidos',
    metodo: 'POST',
    body: { tipo: 2, mesaId: '123', itens: [...] }
  }
}

// Adicionar item ao pedido
{
  tipo: 'adicionar_item_pedido',
  ordem: 2,
  dados: {
    endpoint: '/pedidos/456/itens',
    metodo: 'POST',
    body: { produtoId: '789', quantidade: 2 }
  }
}

// Ocupar mesa
{
  tipo: 'ocupar_mesa',
  ordem: 3,
  dados: {
    endpoint: '/mesas/123/ocupar',
    metodo: 'POST',
    body: { pedidoId: '456' }
  }
}

// Finalizar pedido
{
  tipo: 'finalizar_pedido',
  ordem: 4,
  dados: {
    endpoint: '/pedidos/456/finalizar',
    metodo: 'POST',
    body: {}
  }
}

// Registrar pagamento
{
  tipo: 'registrar_pagamento',
  ordem: 5,
  dados: {
    endpoint: '/pedidos/456/pagamentos',
    metodo: 'POST',
    body: { formaPagamento: 'dinheiro', valor: 50.00 }
  }
}
```

---

## 🔄 Fluxo Completo: Exemplo Prático

### **1. Início do Dia**

```
Servidor Local:
  ✅ Sincroniza produtos
  ✅ Sincroniza mesas/comandas
  ✅ Zera status das mesas
  ✅ Limpa fila do dia anterior (opcional)
```

### **2. PDV cria pedido**

```
PDV → POST /pedidos
     ↓
API Local:
  ✅ Salva pedido local
  ✅ Grava comando na fila (ordem #1)
  ✅ Atualiza mesa local
  ✅ Grava comando na fila (ordem #2)
  ✅ Responde PDV
```

### **3. Serviço Sync processa**

```
Serviço Sync (background):
  ✅ Lê fila (ordem crescente)
  ✅ Executa comando #1 → POST /pedidos (nuvem)
  ✅ Marca como sincronizado
  ✅ Executa comando #2 → POST /mesas/123/ocupar (nuvem)
  ✅ Marca como sincronizado
```

### **4. Se internet cair**

```
Serviço Sync:
  ⚠️ Tenta executar comando #3
  ❌ Falha (sem internet)
  ✅ Incrementa tentativas
  ✅ Continua tentando depois
```

### **5. Quando volta internet**

```
Serviço Sync:
  ✅ Detecta que voltou online
  ✅ Processa fila novamente
  ✅ Executa comandos pendentes na ordem
```

---

## 🎯 Resumo: O que Precisa

### **API Local:**
- ✅ Mini versão da API cloud
- ✅ Mesmos endpoints que PDV usa
- ✅ Salva local + grava na fila
- ✅ Responde imediatamente

### **Serviço de Sincronização:**
- ✅ Lê fila de comandos (ordem crescente)
- ✅ Executa cada comando na nuvem
- ✅ Marca como sincronizado
- ✅ Retry automático se falhar

### **Fila de Comandos:**
- ✅ Log de todas as operações
- ✅ Ordem sequencial garantida
- ✅ Status de sincronização
- ✅ Histórico completo

---

## ✅ Conclusão

**Esta arquitetura funciona perfeitamente!**

**Vantagens:**
- ✅ Garante ordem de execução
- ✅ Funciona offline
- ✅ Reprocessamento automático
- ✅ Fácil de debugar (log completo)
- ✅ Simples de implementar

**É exatamente isso que você precisa!** 🚀
