# Análise: Arquitetura de Eventos

## 🎯 Situação Atual (Problema)

### **O que está acontecendo:**

1. **MesasProvider escuta BoxEvent diretamente do Hive** ❌
   ```dart
   _hiveSubscription = box.watch().listen((event) {
     // Recalcula status da mesa
   });
   ```

2. **AutoSyncManager também escuta BoxEvent** ✅
   ```dart
   _pedidoBoxSubscription = stream.listen((event) {
     // Sincroniza pedidos e dispara eventos
   });
   ```

3. **MesasProvider também escuta AppEventBus** ✅
   ```dart
   AppEventBus.instance.on(TipoEvento.pedidoSincronizado).listen(...)
   ```

### **Problemas:**

1. ❌ **MesasProvider conhece detalhes técnicos do Hive** (não deveria)
2. ❌ **Duplicação de lógica** (dois lugares escutam BoxEvent)
3. ❌ **Responsabilidades misturadas** (MesasProvider faz duas coisas)
4. ❌ **Difícil de manter** (mudanças no Hive afetam MesasProvider diretamente)

---

## ✅ Arquitetura Proposta (Correta)

### **Separação de Responsabilidades:**

```
┌─────────────────────────────────────────┐
│         Hive (Box de Pedidos)           │
│  box.put() / box.delete()               │
└──────────────┬──────────────────────────┘
               │
               │ BoxEvent (técnico)
               │
               ▼
┌─────────────────────────────────────────┐
│    AutoSyncManager / SyncProvider       │
│  (ÚNICO responsável por escutar Hive)  │
│                                         │
│  - Escuta BoxEvent                      │
│  - Detecta mudanças                     │
│  - Sincroniza pedidos                   │
│  - Dispara eventos de NEGÓCIO          │
│    no AppEventBus                       │
└──────────────┬──────────────────────────┘
               │
               │ AppEvent (negócio)
               │
               ▼
┌─────────────────────────────────────────┐
│         AppEventBus                      │
│  - pedidoCriado                         │
│  - pedidoSincronizado                   │
│  - pedidoRemovido                       │
└──────────────┬──────────────────────────┘
               │
               │ Eventos de negócio
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│MesasProvider │  │Outros        │
│              │  │Providers     │
│- Escuta      │  │              │
│  APENAS      │  │- Escutam     │
│  AppEventBus │  │  AppEventBus │
│- Reage a     │  │              │
│  eventos de  │  │              │
│  negócio     │  │              │
└──────────────┘  └──────────────┘
```

---

## 🎯 Responsabilidades Corretas

### **AutoSyncManager / SyncProvider (Sincronização)**

**Responsabilidades:**
- ✅ Escutar BoxEvent do Hive (único lugar)
- ✅ Detectar quando pedido é criado/modificado/deletado
- ✅ Gerenciar sincronização de pedidos
- ✅ Disparar eventos de negócio no AppEventBus:
  - `pedidoCriado` - quando pedido pendente é inserido
  - `pedidoSincronizado` - quando pedido sincroniza
  - `pedidoRemovido` - quando pedido é deletado
  - `pedidoErro` - quando há erro na sincronização

**Não faz:**
- ❌ Não atualiza status de mesas diretamente
- ❌ Não conhece sobre mesas (só sobre pedidos)

---

### **MesasProvider (Gerenciamento de Mesas)**

**Responsabilidades:**
- ✅ Escutar APENAS AppEventBus (eventos de negócio)
- ✅ Reagir a eventos de negócio:
  - `pedidoCriado` → Mesa fica ocupada/pendente
  - `pedidoSincronizado` → Atualiza status da mesa
  - `pedidoRemovido` → Recalcula status da mesa
- ✅ Gerenciar estado de mesas
- ✅ Buscar dados do servidor quando necessário

**Não faz:**
- ❌ Não escuta BoxEvent do Hive
- ❌ Não conhece detalhes técnicos de sincronização
- ❌ Não conhece sobre Hive diretamente

---

## 📊 Fluxo Correto

### **Cenário 1: Pedido Criado**

```
1. PedidoProvider.finalizarPedido()
   ↓
2. pedidoRepo.upsert(pedido) → box.put()
   ↓
3. Hive dispara BoxEvent (técnico)
   ↓
4. AutoSyncManager escuta BoxEvent
   ↓
5. AutoSyncManager detecta: pedido pendente criado
   ↓
6. AutoSyncManager dispara AppEventBus.pedidoCriado (negócio)
   ↓
7. MesasProvider escuta AppEventBus
   ↓
8. MesasProvider recalcula status: mesa ocupada/pendente
   ↓
9. AutoSyncManager sincroniza pedido (em paralelo)
```

### **Cenário 2: Pedido Sincronizado**

```
1. AutoSyncManager sincroniza pedido
   ↓
2. Atualiza status no Hive: syncStatus = sincronizado
   ↓
3. box.put() → Hive dispara BoxEvent
   ↓
4. AutoSyncManager escuta BoxEvent
   ↓
5. AutoSyncManager detecta: pedido sincronizado
   ↓
6. AutoSyncManager dispara AppEventBus.pedidoSincronizado (negócio)
   ↓
7. MesasProvider escuta AppEventBus
   ↓
8. MesasProvider recalcula status e atualiza do servidor
```

### **Cenário 3: Pedido Removido**

```
1. pedidoRepo.delete(id) → box.delete()
   ↓
2. Hive dispara BoxEvent (deleted = true)
   ↓
3. AutoSyncManager escuta BoxEvent
   ↓
4. AutoSyncManager detecta: pedido removido
   ↓
5. AutoSyncManager dispara AppEventBus.pedidoRemovido (negócio)
   ↓
6. MesasProvider escuta AppEventBus
   ↓
7. MesasProvider recalcula status da mesa
```

---

## ✅ Vantagens da Arquitetura Proposta

1. **Separação de Responsabilidades**
   - AutoSyncManager: técnico (Hive)
   - MesasProvider: negócio (mesas)

2. **Desacoplamento**
   - MesasProvider não conhece Hive
   - Mudanças no Hive não afetam MesasProvider diretamente

3. **Manutenibilidade**
   - Um único lugar escuta BoxEvent
   - Eventos de negócio são claros e semânticos

4. **Testabilidade**
   - Pode mockar AppEventBus facilmente
   - Não precisa mockar Hive para testar MesasProvider

5. **Escalabilidade**
   - Fácil adicionar novos listeners de eventos de negócio
   - Fácil adicionar novos tipos de eventos

---

## 🔧 Mudanças Necessárias

### **1. AutoSyncManager deve disparar mais eventos:**

```dart
// Quando pedido pendente é criado
AppEventBus.instance.dispararPedidoCriado(
  pedidoId: pedido.id,
  mesaId: pedido.mesaId,
  comandaId: pedido.comandaId,
);

// Quando pedido é removido
AppEventBus.instance.dispararPedidoRemovido(
  pedidoId: pedidoRemovido.id,
  mesaId: pedidoRemovido.mesaId,
  comandaId: pedidoRemovido.comandaId,
);
```

### **2. MesasProvider deve:**

- ❌ Remover `_setupHiveListener()`
- ❌ Remover `_hiveSubscription`
- ✅ Escutar apenas AppEventBus
- ✅ Adicionar listener para `pedidoCriado`
- ✅ Adicionar listener para `pedidoRemovido`

---

## 💡 Conclusão

**Você está absolutamente certo!** 

A arquitetura atual está errada porque:
- MesasProvider não deveria escutar Hive diretamente
- AutoSyncManager deveria ser o único responsável por escutar BoxEvent
- AutoSyncManager deveria disparar TODOS os eventos de negócio relacionados a pedidos

**A arquitetura proposta:**
- ✅ Separação clara de responsabilidades
- ✅ Desacoplamento correto
- ✅ Mais fácil de manter e testar
- ✅ Escalável

**Faz sentido?** ✅ **SIM, totalmente!**
