# 🔄 Solução Simples de Sincronização: Servidor Local

## 🎯 O que o PDV Realmente Usa

Baseado na análise do código:

### ✅ **Operações do PDV:**

1. **Pedidos:**
   - `POST /pedidos` - Criar pedido
   - `GET /pedidos/por-mesa/{mesaId}` - Buscar pedidos da mesa
   - `GET /pedidos/por-comanda/{comandaId}` - Buscar pedidos da comanda
   - `PUT /pedidos/{id}` - Atualizar pedido
   - `POST /pedidos/{id}/finalizar` - Finalizar pedido
   - `POST /pedidos/{id}/cancelar` - Cancelar pedido

2. **Mesas:**
   - `GET /mesas` - Listar mesas
   - `GET /mesas/{id}` - Buscar mesa por ID
   - `POST /mesas/{id}/ocupar` - Ocupar mesa
   - `POST /mesas/{id}/liberar` - Liberar mesa

3. **Comandas:**
   - `GET /comandas` - Listar comandas
   - `GET /comandas/{id}` - Buscar comanda por ID
   - `POST /comandas/{id}/encerrar` - Encerrar comanda
   - `POST /comandas/{id}/cancelar` - Cancelar comanda
   - `POST /comandas/{id}/reabrir` - Reabrir comanda

4. **Produtos:**
   - `GET /produto-pdv-sync/produtos` - Sincronizar produtos (já existe)
   - `GET /produto-pdv-sync/grupos-exibicao` - Sincronizar grupos (já existe)

---

## 🏗️ Arquitetura: API Local = API Nuvem

### **Princípio: Mesma Interface**

A API do servidor local **tem exatamente os mesmos endpoints** da API nuvem!

```
PDV → Servidor Local → (mesmos endpoints) → Banco Local
                      ↓
                   (se online)
                      ↓
                  API Nuvem
```

**Vantagem:** PDV não precisa mudar nada! Apenas muda a URL da API.

---

## 🔄 Fluxo de Sincronização: Dados, Não Comandos

### ❌ **NÃO fazer:** Enviar comandos para ambos

```javascript
// ❌ ERRADO - Enviar para ambos
await apiLocal.post('/pedidos', dados);
await apiNuvem.post('/pedidos', dados);  // Se online
```

**Problemas:**
- Duplicação de lógica
- Difícil manter sincronizado
- O que fazer se um falhar e outro não?

### ✅ **FAZER:** Sincronizar dados

```javascript
// ✅ CERTO - Salvar local, sincronizar depois
// 1. Salva localmente primeiro (sempre)
await dbLocal.pedidos.insert(dados);

// 2. Sincroniza com nuvem depois (se online)
if (await isOnline()) {
  await syncPedidoParaNuvem(dados);
}
```

---

## 📊 Estratégia: Write-Through Cache

### **Fluxo de Escrita (Criar/Atualizar)**

```
┌─────────────┐
│     PDV     │
└──────┬──────┘
       │ POST /pedidos
       ↓
┌──────────────────────┐
│  Servidor Local      │
│  1. Salva no banco   │ ← SEMPRE (rápido)
│     local primeiro   │
│                      │
│  2. Retorna resposta │ ← Resposta imediata
│     para PDV         │
│                      │
│  3. (Background)     │
│     Sincroniza com   │ ← Se online
│     nuvem depois     │
└──────────────────────┘
       │
       ↓ (se online)
┌──────────────────────┐
│    API Nuvem         │
│  Salva no banco      │
│  principal           │
└──────────────────────┘
```

### **Fluxo de Leitura (Buscar)**

```
┌─────────────┐
│     PDV     │
└──────┬──────┘
       │ GET /pedidos/por-mesa/123
       ↓
┌──────────────────────┐
│  Servidor Local      │
│                      │
│  1. Busca no banco   │ ← SEMPRE do local
│     local            │   (rápido)
│                      │
│  2. Retorna dados    │
│                      │
│  3. (Background)     │
│     Atualiza cache   │ ← Se online
│     se necessário    │
└──────────────────────┘
```

---

## 💾 Estrutura do Banco Local

### **Tabelas Necessárias:**

```sql
-- ============================================
-- CACHE (Dados de Leitura)
-- ============================================

-- Produtos (cache do início do dia)
CREATE TABLE produtos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  preco REAL,
  -- ... campos necessários
  sincronizado_em DATETIME
);

-- Mesas (cache)
CREATE TABLE mesas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  layout_id TEXT,
  -- ... campos necessários
  sincronizado_em DATETIME
);

-- Comandas (cache)
CREATE TABLE comandas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  -- ... campos necessários
  sincronizado_em DATETIME
);

-- ============================================
-- DADOS LOCAIS (Dados de Escrita)
-- ============================================

-- Pedidos criados localmente
CREATE TABLE pedidos_local (
  id_local TEXT PRIMARY KEY,      -- UUID gerado localmente
  id_remoto TEXT,                  -- Preenchido após sync
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  total REAL,
  dados_json TEXT NOT NULL,        -- JSON completo do pedido
  criado_em DATETIME NOT NULL,
  sincronizado INTEGER DEFAULT 0,  -- 0 = pendente, 1 = sincronizado
  tentativas_sync INTEGER DEFAULT 0,
  ultimo_erro TEXT
);

-- Movimentações de mesas/comandas (para sincronizar status)
CREATE TABLE movimentacoes_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,
  tipo TEXT,                       -- 'ocupar_mesa', 'liberar_mesa', 'encerrar_comanda', etc
  entidade_id TEXT,                -- ID da mesa ou comanda
  dados_json TEXT NOT NULL,        -- JSON com dados da operação
  criado_em DATETIME NOT NULL,
  sincronizado INTEGER DEFAULT 0
);
```

---

## 🔄 Implementação: Servidor Local

### **Exemplo: Endpoint POST /pedidos**

```javascript
// Servidor Local - Endpoint POST /pedidos
app.post('/pedidos', async (req, res) => {
  try {
    const pedidoData = req.body;
    
    // 1. Gerar ID local (UUID)
    const idLocal = generateUUID();
    pedidoData.idLocal = idLocal;
    
    // 2. Salvar no banco local (SEMPRE)
    await db.pedidos_local.insert({
      id_local: idLocal,
      numero: pedidoData.numero,
      tipo: pedidoData.tipo,
      status: pedidoData.status,
      mesa_id: pedidoData.mesaId,
      comanda_id: pedidoData.comandaId,
      total: pedidoData.total,
      dados_json: JSON.stringify(pedidoData),
      criado_em: new Date(),
      sincronizado: 0
    });
    
    // 3. Retornar resposta imediata para PDV
    res.json({
      success: true,
      data: {
        id: idLocal,  // Retorna ID local
        ...pedidoData
      },
      message: 'Pedido criado com sucesso'
    });
    
    // 4. Sincronizar com nuvem em background (não bloqueia resposta)
    syncPedidoParaNuvem(idLocal).catch(err => {
      console.error('Erro ao sincronizar pedido:', err);
      // Erro não afeta o PDV, será tentado depois
    });
    
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Função de sincronização (background)
async function syncPedidoParaNuvem(idLocal) {
  // Verificar se está online
  if (!await isOnline()) {
    return; // Não tenta se offline
  }
  
  // Buscar pedido local
  const pedidoLocal = await db.pedidos_local.findOne({ id_local: idLocal });
  if (!pedidoLocal || pedidoLocal.sincronizado) {
    return; // Já sincronizado
  }
  
  try {
    // Enviar para nuvem
    const pedidoData = JSON.parse(pedidoLocal.dados_json);
    const response = await apiNuvem.post('/pedidos', pedidoData);
    
    // Atualizar com ID remoto
    await db.pedidos_local.update(
      { id_local: idLocal },
      {
        id_remoto: response.data.id,
        sincronizado: 1,
        tentativas_sync: pedidoLocal.tentativas_sync + 1
      }
    );
    
    console.log(`✅ Pedido ${idLocal} sincronizado com sucesso`);
    
  } catch (error) {
    // Marcar erro, será tentado depois
    await db.pedidos_local.update(
      { id_local: idLocal },
      {
        tentativas_sync: pedidoLocal.tentativas_sync + 1,
        ultimo_erro: error.message
      }
    );
    
    console.error(`❌ Erro ao sincronizar pedido ${idLocal}:`, error.message);
  }
}
```

### **Exemplo: Endpoint GET /pedidos/por-mesa/{mesaId}**

```javascript
// Servidor Local - Endpoint GET /pedidos/por-mesa/{mesaId}
app.get('/pedidos/por-mesa/:mesaId', async (req, res) => {
  try {
    const { mesaId } = req.params;
    
    // 1. Buscar do banco local (SEMPRE)
    const pedidosLocais = await db.pedidos_local.find({
      mesa_id: mesaId,
      sincronizado: 0  // Apenas pedidos locais ainda não sincronizados
    });
    
    // 2. Se online, buscar também da nuvem
    let pedidosNuvem = [];
    if (await isOnline()) {
      try {
        const response = await apiNuvem.get(`/pedidos/por-mesa/${mesaId}`);
        pedidosNuvem = response.data || [];
      } catch (error) {
        console.error('Erro ao buscar pedidos da nuvem:', error);
        // Continua mesmo se falhar
      }
    }
    
    // 3. Combinar resultados (local + nuvem)
    const todosPedidos = [
      ...pedidosLocais.map(p => JSON.parse(p.dados_json)),
      ...pedidosNuvem
    ];
    
    // 4. Retornar para PDV
    res.json({
      success: true,
      data: todosPedidos,
      message: 'Pedidos encontrados'
    });
    
    // 5. (Background) Atualizar cache se necessário
    if (await isOnline()) {
      atualizarCachePedidos(mesaId).catch(console.error);
    }
    
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});
```

---

## 🔄 Sincronização Automática

### **Quando Sincronizar:**

1. **Imediatamente após criar** (em background, não bloqueia)
2. **Periodicamente** (a cada 5 minutos)
3. **Quando volta online** (detectar mudança de offline → online)

### **Implementação:**

```javascript
// Sincronização periódica
setInterval(async () => {
  if (await isOnline()) {
    await sincronizarPedidosPendentes();
    await sincronizarMovimentacoesPendentes();
  }
}, 5 * 60 * 1000); // A cada 5 minutos

// Sincronizar todos os pedidos pendentes
async function sincronizarPedidosPendentes() {
  const pedidosPendentes = await db.pedidos_local.find({
    sincronizado: 0,
    tentativas_sync: { $lt: 5 }  // Máximo 5 tentativas
  });
  
  for (const pedido of pedidosPendentes) {
    await syncPedidoParaNuvem(pedido.id_local);
    await sleep(100); // Pequeno delay entre sincronizações
  }
}
```

---

## 📋 Resumo: O que Precisa no Servidor Local

### ✅ **Cache (Sincronizar no início do dia):**

1. **Produtos** (já tem sincronização)
   - Produtos ativos e vendáveis
   - Variações, atributos, composições

2. **Mesas**
   - Todas as mesas disponíveis
   - Status atual

3. **Comandas**
   - Comandas disponíveis
   - Status atual

4. **Configurações**
   - Configuração do restaurante
   - Usuários e permissões básicas

### ✅ **Dados Locais (Criar localmente, sincronizar depois):**

1. **Pedidos**
   - Pedidos criados no dia
   - Status: pendente → sincronizado

2. **Movimentações**
   - Ocupar/liberar mesa
   - Encerrar/cancelar comanda
   - Mudanças de status

---

## 🎯 Vantagens desta Abordagem

### ✅ **Simplicidade**
- API local = API nuvem (mesmos endpoints)
- PDV não precisa mudar nada
- Lógica de sincronização centralizada no servidor local

### ✅ **Performance**
- Respostas instantâneas (banco local)
- Sincronização em background (não bloqueia)
- Cache otimizado para leitura

### ✅ **Confiabilidade**
- Dados sempre salvos localmente primeiro
- Funciona mesmo sem internet
- Sincronização pode falhar sem afetar operação

### ✅ **Manutenibilidade**
- Código simples e claro
- Fácil debugar (logs centralizados)
- Fácil adicionar novos endpoints

---

## 🔧 Configuração do PDV

### **Única Mudança Necessária:**

```dart
// Antes (conectava direto na nuvem)
final apiUrl = 'https://api.nuvem.com';

// Depois (conecta no servidor local)
final apiUrl = 'http://192.168.1.100:3000';  // IP do servidor local
```

**Isso é tudo!** O PDV continua funcionando exatamente igual.

---

## 📊 Fluxo Completo: Exemplo Prático

### **Cenário: Criar Pedido Offline**

1. **PDV chama:** `POST http://servidor-local:3000/pedidos`
2. **Servidor local:**
   - Salva no banco local ✅
   - Retorna resposta imediata para PDV ✅
   - Tenta sincronizar com nuvem (falha, está offline) ⚠️
   - Marca como pendente ✅
3. **PDV recebe:** Resposta de sucesso (não sabe que está offline)
4. **Quando volta internet:**
   - Servidor local detecta
   - Sincroniza pedido pendente automaticamente ✅
   - Marca como sincronizado ✅

### **Cenário: Buscar Pedidos da Mesa**

1. **PDV chama:** `GET http://servidor-local:3000/pedidos/por-mesa/123`
2. **Servidor local:**
   - Busca pedidos locais (pendentes) ✅
   - Se online: busca também da nuvem ✅
   - Combina resultados ✅
   - Retorna para PDV ✅
3. **PDV recebe:** Todos os pedidos (locais + nuvem)

---

## ❓ Perguntas Frequentes

### 1. **E se dois PDVs criarem pedidos offline com mesmo número?**

**Solução:** Usar UUIDs locais únicos. Servidor nuvem gera número real após sincronização.

### 2. **E se produto mudar de preço enquanto está offline?**

**Solução:** Usar preço do momento da criação (snapshot). Preço já está salvo no pedido.

### 3. **E se houver conflito ao sincronizar?**

**Solução:** Servidor nuvem resolve conflitos. Servidor local recebe resposta e atualiza.

### 4. **Precisa sincronizar tudo sempre?**

**Solução:** Não. Apenas:
- Cache: No início do dia
- Dados novos: Imediatamente (background)
- Dados pendentes: Periodicamente

---

## 🎉 Conclusão

**Solução Simples:**
- ✅ API local = API nuvem (mesmos endpoints)
- ✅ Salva local primeiro (sempre)
- ✅ Sincroniza depois (background)
- ✅ PDV não precisa mudar nada

**Resultado:** Sistema funciona offline, sincroniza automaticamente quando volta online! 🚀
