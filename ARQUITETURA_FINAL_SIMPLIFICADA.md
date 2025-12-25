# 🏗️ Arquitetura Final: PDV → Servidor Local → Nuvem

## 🎯 Princípio Fundamental

**PDV conhece APENAS o servidor local. Ponto.**

O servidor local é quem se vira com a nuvem. PDV não sabe nem se está online ou offline.

---

## 🏛️ Arquitetura Completa

```
┌─────────────────────────────────────────────────────────────┐
│                    REDE LOCAL                                │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │   PDV 1  │    │   PDV 2  │    │   PDV 3  │            │
│  │ (Flutter)│    │ (Flutter)│    │ (Flutter)│            │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘            │
│       │               │               │                    │
│       └───────────────┼───────────────┘                    │
│                       │                                      │
│              ┌────────▼────────┐                            │
│              │  SERVIDOR LOCAL │                            │
│              │   (Node.js/.NET) │                            │
│              │   Banco Local    │                            │
│              │   (SQLite)       │                            │
│              └────────┬────────┘                            │
│                       │                                      │
└───────────────────────┼───────────────────────────────────────┘
                        │
                        │ (Internet - quando disponível)
                        │
              ┌─────────▼─────────┐
              │   SERVIDOR NUVEM  │
              │   (Backend atual) │
              │   Banco Nuvem     │
              └───────────────────┘
```

---

## 🔄 Fluxo de Funcionamento

### **PDV → Servidor Local (SEMPRE)**

PDV **sempre** se conecta no servidor local. Nunca na nuvem.

```dart
// PDV - Configuração ÚNICA
final apiUrl = 'http://192.168.1.100:3000';  // Servidor local
```

**PDV não sabe:**
- ❌ Se está online ou offline
- ❌ Se dados estão sincronizados
- ❌ Nada sobre a nuvem

**PDV só sabe:**
- ✅ Endereço do servidor local
- ✅ Como fazer requisições HTTP

---

## 🗄️ Banco Local (Servidor Local)

### **Estrutura:**

O banco local do servidor local é **independente** do banco da nuvem.

```sql
-- ============================================
-- CACHE (Dados de Leitura - do início do dia)
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
  -- ... campos necessários
  sincronizado_em DATETIME
);

CREATE TABLE comandas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  -- ... campos necessários
  sincronizado_em DATETIME
);

-- ============================================
-- DADOS LOCAIS (Dados de Escrita - do dia)
-- ============================================

CREATE TABLE pedidos_local (
  id_local TEXT PRIMARY KEY,      -- UUID gerado localmente
  id_remoto TEXT,                  -- Preenchido após sync com nuvem
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  total REAL,
  dados_json TEXT NOT NULL,        -- JSON completo do pedido
  criado_em DATETIME NOT NULL,
  sincronizado INTEGER DEFAULT 0   -- 0 = pendente, 1 = sincronizado
);

CREATE TABLE movimentacoes_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,
  tipo TEXT,                       -- 'ocupar_mesa', 'liberar_mesa', etc
  entidade_id TEXT,                -- ID da mesa ou comanda
  dados_json TEXT NOT NULL,
  criado_em DATETIME NOT NULL,
  sincronizado INTEGER DEFAULT 0
);
```

**Importante:** Este banco é **apenas do servidor local**. Não altera nada do banco da nuvem.

---

## 🔄 Fluxo: Criar Pedido

### **1. PDV cria pedido**

```dart
// PDV - Código normal
final response = await http.post(
  'http://servidor-local:3000/pedidos',
  body: jsonEncode(pedidoData),
);
```

### **2. Servidor Local recebe**

```javascript
// Servidor Local - Endpoint POST /pedidos
app.post('/pedidos', async (req, res) => {
  const pedidoData = req.body;
  
  // 1. Gerar ID local
  const idLocal = generateUUID();
  pedidoData.idLocal = idLocal;
  
  // 2. Salvar no banco LOCAL (sempre)
  await dbLocal.pedidos_local.insert({
    id_local: idLocal,
    dados_json: JSON.stringify(pedidoData),
    sincronizado: 0  // Pendente
  });
  
  // 3. Retornar resposta para PDV (imediata)
  res.json({
    success: true,
    data: {
      id: idLocal,
      ...pedidoData
    }
  });
  
  // 4. Tentar sincronizar com nuvem (background, não bloqueia)
  syncComNuvem(idLocal).catch(console.error);
});
```

### **3. Servidor Local sincroniza com Nuvem (background)**

```javascript
// Servidor Local - Sincronização
async function syncComNuvem(idLocal) {
  // Verificar se está online
  if (!await isOnline()) {
    return; // Não tenta se offline
  }
  
  // Buscar pedido local
  const pedidoLocal = await dbLocal.pedidos_local.findOne({ 
    id_local: idLocal 
  });
  
  if (pedidoLocal.sincronizado) {
    return; // Já sincronizado
  }
  
  try {
    // Enviar para NUVEM
    const pedidoData = JSON.parse(pedidoLocal.dados_json);
    const response = await apiNuvem.post('/pedidos', pedidoData);
    
    // Atualizar com ID remoto
    await dbLocal.pedidos_local.update(
      { id_local: idLocal },
      {
        id_remoto: response.data.id,
        sincronizado: 1
      }
    );
    
  } catch (error) {
    // Erro não afeta PDV, será tentado depois
    console.error('Erro ao sincronizar:', error);
  }
}
```

**Resultado:**
- ✅ PDV recebe resposta imediata (não espera nuvem)
- ✅ Dados salvos localmente (funciona offline)
- ✅ Sincronização acontece em background (não bloqueia)

---

## 🔄 Fluxo: Buscar Pedidos da Mesa

### **1. PDV busca pedidos**

```dart
// PDV - Código normal
final response = await http.get(
  'http://servidor-local:3000/pedidos/por-mesa/123',
);
```

### **2. Servidor Local busca**

```javascript
// Servidor Local - Endpoint GET /pedidos/por-mesa/:mesaId
app.get('/pedidos/por-mesa/:mesaId', async (req, res) => {
  const { mesaId } = req.params;
  
  // 1. Buscar do banco LOCAL (sempre)
  const pedidosLocais = await dbLocal.pedidos_local.find({
    mesa_id: mesaId
  });
  
  // 2. Se online, buscar também da nuvem e combinar
  let todosPedidos = pedidosLocais.map(p => JSON.parse(p.dados_json));
  
  if (await isOnline()) {
    try {
      const pedidosNuvem = await apiNuvem.get(`/pedidos/por-mesa/${mesaId}`);
      todosPedidos = [...todosPedidos, ...pedidosNuvem.data];
    } catch (error) {
      // Se falhar, continua só com dados locais
      console.error('Erro ao buscar da nuvem:', error);
    }
  }
  
  // 3. Retornar para PDV
  res.json({
    success: true,
    data: todosPedidos
  });
});
```

**Resultado:**
- ✅ PDV sempre recebe dados (local + nuvem se online)
- ✅ Funciona mesmo offline (só dados locais)

---

## 🔄 Sincronização: Servidor Local → Nuvem

### **Quando Sincronizar:**

1. **Imediatamente após criar** (background)
2. **Periodicamente** (a cada 5 minutos)
3. **Quando volta online** (detectar mudança)

### **O que Sincronizar:**

```javascript
// Servidor Local - Sincronização Periódica
async function sincronizarTudo() {
  if (!await isOnline()) {
    return; // Não tenta se offline
  }
  
  // 1. Enviar pedidos pendentes
  const pedidosPendentes = await dbLocal.pedidos_local.find({
    sincronizado: 0
  });
  
  for (const pedido of pedidosPendentes) {
    await syncPedidoParaNuvem(pedido.id_local);
  }
  
  // 2. Enviar movimentações pendentes
  const movimentacoesPendentes = await dbLocal.movimentacoes_local.find({
    sincronizado: 0
  });
  
  for (const mov of movimentacoesPendentes) {
    await syncMovimentacaoParaNuvem(mov.id_local);
  }
  
  // 3. Buscar atualizações da nuvem (opcional)
  await atualizarCacheDaNuvem();
}

// Executar a cada 5 minutos
setInterval(sincronizarTudo, 5 * 60 * 1000);
```

---

## 📋 Resumo: Responsabilidades

### **PDV:**
- ✅ Conecta apenas no servidor local
- ✅ Faz requisições HTTP normais
- ✅ Não sabe nada sobre nuvem/offline

### **Servidor Local:**
- ✅ Recebe todas as requisições do PDV
- ✅ Salva tudo no banco local primeiro
- ✅ Responde imediatamente para PDV
- ✅ Sincroniza com nuvem em background
- ✅ Gerencia cache de produtos/mesas/comandas

### **Servidor Nuvem:**
- ✅ Recebe sincronizações do servidor local
- ✅ Armazena dados definitivos
- ✅ Não precisa saber que existe servidor local

---

## 🎯 Vantagens desta Arquitetura

### ✅ **Simplicidade Máxima**
- PDV é apenas cliente HTTP simples
- Não precisa de lógica offline/online
- Não precisa de sincronização

### ✅ **Desacoplamento Total**
- PDV não conhece nuvem
- Servidor local abstrai toda complexidade
- Fácil trocar servidor nuvem depois

### ✅ **Performance**
- Respostas instantâneas (banco local)
- Sincronização não bloqueia operações
- Cache otimizado

### ✅ **Confiabilidade**
- Funciona mesmo sem internet
- Dados sempre salvos localmente primeiro
- Sincronização pode falhar sem afetar PDV

---

## 🔧 Configuração

### **PDV (Única Configuração):**

```dart
// lib/core/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.100:3000';
  // Ou configurável via settings
}
```

### **Servidor Local (Configuração):**

```env
# Porta do servidor local
PORT=3000

# URL da API nuvem
API_NUVEM_URL=https://api.nuvem.com

# Token de autenticação
API_NUVEM_TOKEN=xxx

# Intervalo de sincronização (minutos)
SYNC_INTERVAL=5
```

---

## 📊 Exemplo Completo: Cenário Offline

### **1. PDV cria pedido (offline)**

```
PDV → POST /pedidos
     ↓
Servidor Local:
  ✅ Salva no banco local
  ✅ Retorna resposta imediata
  ⚠️ Tenta sincronizar (falha, está offline)
  ✅ Marca como pendente
```

### **2. PDV busca pedidos (offline)**

```
PDV → GET /pedidos/por-mesa/123
     ↓
Servidor Local:
  ✅ Busca do banco local
  ✅ Retorna pedidos locais
```

### **3. Internet volta**

```
Servidor Local detecta:
  ✅ Sincroniza pedidos pendentes automaticamente
  ✅ Marca como sincronizado
```

### **4. PDV busca pedidos (agora online)**

```
PDV → GET /pedidos/por-mesa/123
     ↓
Servidor Local:
  ✅ Busca do banco local
  ✅ Busca também da nuvem
  ✅ Combina resultados
  ✅ Retorna tudo para PDV
```

**PDV não percebeu nada!** Funcionou normalmente em todos os momentos.

---

## 🎉 Conclusão

**Arquitetura Final:**

```
PDV → Servidor Local → (background) → Nuvem
     (única conexão)   (sincronização)
```

**Resultado:**
- ✅ PDV é simples (apenas cliente HTTP)
- ✅ Funciona offline automaticamente
- ✅ Sincronização transparente
- ✅ Fácil de manter e debugar

**É isso! Simples e eficiente!** 🚀
