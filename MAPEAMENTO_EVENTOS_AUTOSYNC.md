# Mapeamento de Eventos - AutoSyncManager

## 🎯 Situações e Eventos a Disparar

### **Status Possíveis de um Pedido:**

- `pendente` - Pedido criado, aguardando sincronização
- `sincronizando` - Pedido sendo sincronizado no momento
- `sincronizado` - Pedido sincronizado com sucesso
- `erro` - Erro na sincronização

---

## 📊 Situações e Eventos

### **1. Pedido Criado (Novo Pedido Pendente)**

**Situação:**
- BoxEvent detectado com `pedido.syncStatus == pendente`
- É um pedido novo (não estava sendo sincronizado antes)

**O que acontece:**
- AutoSyncManager detecta pedido pendente
- Inicia sincronização

**Evento a disparar:**
```dart
AppEventBus.instance.dispararPedidoCriado(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
);
```

**Por quê?**
- Mesa precisa saber que há um novo pedido pendente
- Mesa deve ficar "ocupada" ou "pendente de sincronização"
- Outros componentes podem precisar reagir

---

### **2. Pedido Sendo Sincronizado**

**Situação:**
- Status muda de `pendente` → `sincronizando`
- SyncService atualiza status antes de enviar

**O que acontece:**
- AutoSyncManager detecta mudança de status
- Pedido está sendo enviado ao servidor

**Evento a disparar:**
```dart
// NOVO EVENTO - precisa adicionar no AppEventBus
AppEventBus.instance.dispararPedidoSincronizando(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
);
```

**Por quê?**
- UI pode mostrar indicador de sincronização
- Mesa pode mostrar status "sincronizando"
- Usuário sabe que está processando

**⚠️ Observação:** Este evento ainda não existe no AppEventBus, precisa ser criado.

---

### **3. Pedido Sincronizado com Sucesso**

**Situação:**
- Status muda para `sincronizado`
- SyncService atualiza após resposta bem-sucedida

**O que acontece:**
- AutoSyncManager detecta status sincronizado
- Pedido foi enviado com sucesso

**Evento a disparar:**
```dart
AppEventBus.instance.dispararPedidoSincronizado(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
);
```

**Por quê?**
- Mesa precisa atualizar status
- Pode buscar dados atualizados do servidor
- Outros componentes podem reagir

**✅ Já existe e está sendo usado**

---

### **4. Pedido com Erro na Sincronização**

**Situação:**
- Status muda para `erro`
- SyncService atualiza após falha
- Pode acontecer durante sincronização ou retry

**O que acontece:**
- AutoSyncManager detecta status erro
- Pedido falhou ao sincronizar

**Evento a disparar:**
```dart
// NOVO EVENTO - precisa adicionar no AppEventBus
AppEventBus.instance.dispararPedidoErro(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
  erro: pedido.lastSyncError,
);
```

**Por quê?**
- UI pode mostrar erro
- Mesa pode manter status "ocupada" mas com erro
- Usuário pode ser notificado
- Sistema pode tentar novamente

**⚠️ Observação:** Este evento ainda não existe no AppEventBus, precisa ser criado.

---

### **5. Pedido Removido**

**Situação:**
- BoxEvent com `event.deleted == true`
- Pedido foi deletado do Hive

**O que acontece:**
- AutoSyncManager detecta deleção
- Pedido não existe mais localmente

**Evento a disparar:**
```dart
// NOVO EVENTO - precisa adicionar no AppEventBus
AppEventBus.instance.dispararPedidoRemovido(
  pedidoId: pedidoRemovido.id,
  mesaId: pedidoRemovido.mesaId,
  comandaId: pedidoRemovido.comandaId,
);
```

**Por quê?**
- Mesa precisa recalcular status
- Se era o último pedido, mesa pode ficar livre
- Outros componentes podem precisar reagir

**⚠️ Observação:** 
- Atualmente AutoSyncManager ignora deleções (`if (event.deleted) return;`)
- Precisa mudar para processar deleções

---

### **6. Pedido Travado (Timeout)**

**Situação:**
- Pedido está em `sincronizando` há mais de 2 minutos
- Timer detecta e reseta para `erro`

**O que acontece:**
- AutoSyncManager detecta timeout
- Reseta status para erro

**Evento a disparar:**
```dart
// Usa o mesmo evento de erro
AppEventBus.instance.dispararPedidoErro(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
  erro: 'Sincronização travada, tentando novamente',
);
```

**Por quê?**
- Mesmo que erro normal
- Sistema pode tentar novamente
- UI pode mostrar problema

---

### **7. Retry de Pedido com Erro**

**Situação:**
- Timer encontra pedido com `erro`
- Tenta sincronizar novamente

**O que acontece:**
- AutoSyncManager tenta sincronizar novamente
- Status muda para `sincronizando` (depois pode ir para `sincronizado` ou `erro`)

**Eventos a disparar:**
- Quando inicia retry: `pedidoSincronizando` (se mudou status)
- Quando sucesso: `pedidoSincronizado`
- Quando falha novamente: `pedidoErro`

**Por quê?**
- Mesmo fluxo de sincronização normal
- UI pode mostrar tentativa

---

## 📋 Resumo: Eventos Necessários

### **✅ Eventos que já existem:**

1. `pedidoCriado` - Quando pedido pendente é detectado
2. `pedidoSincronizado` - Quando pedido sincroniza com sucesso

### **⚠️ Eventos que precisam ser criados:**

3. `pedidoSincronizando` - Quando pedido começa a sincronizar
4. `pedidoErro` - Quando pedido falha na sincronização
5. `pedidoRemovido` - Quando pedido é deletado

---

## 🔄 Fluxo Completo de um Pedido

```
1. Pedido criado (pendente)
   ↓
   Evento: pedidoCriado
   ↓
2. AutoSyncManager detecta e inicia sincronização
   ↓
   Status muda: pendente → sincronizando
   ↓
   Evento: pedidoSincronizando
   ↓
3. SyncService envia ao servidor
   ↓
   ├─→ Sucesso
   │   ↓
   │   Status muda: sincronizando → sincronizado
   │   ↓
   │   Evento: pedidoSincronizado
   │
   └─→ Erro
       ↓
       Status muda: sincronizando → erro
       ↓
       Evento: pedidoErro
       ↓
       Timer tenta novamente (retry)
       ↓
       Volta para passo 2
```

---

## 🎯 Pontos Importantes

### **1. Detecção de Mudança de Status**

AutoSyncManager precisa detectar mudanças de status, não apenas status atual:

```dart
// Precisa rastrear status anterior
Map<String, SyncStatusPedido> _statusAnterior = {};

// Quando detecta mudança:
if (statusAnterior != statusAtual) {
  // Dispara evento apropriado
}
```

### **2. Processar Deleções**

Atualmente ignora deleções, precisa processar:

```dart
if (event.deleted) {
  // Processar deleção
  // Disparar pedidoRemovido
}
```

### **3. Evitar Eventos Duplicados**

Garantir que não dispara o mesmo evento múltiplas vezes:

```dart
// Rastrear últimos eventos disparados
// Evitar disparar se já foi disparado recentemente
```

---

## ✅ Conclusão

**Eventos que AutoSyncManager deve disparar:**

1. ✅ `pedidoCriado` - Quando detecta pedido pendente novo
2. ⚠️ `pedidoSincronizando` - Quando status muda para sincronizando (NOVO)
3. ✅ `pedidoSincronizado` - Quando status muda para sincronizado
4. ⚠️ `pedidoErro` - Quando status muda para erro (NOVO)
5. ⚠️ `pedidoRemovido` - Quando pedido é deletado (NOVO)

**Faz sentido?** ✅ Sim, cobre todas as situações importantes!
