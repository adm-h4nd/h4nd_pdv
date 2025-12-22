# Arquitetura: Hive e Eventos

## 🎯 Resumo

**Hive tem eventos próprios** (`BoxEvent`) que são **técnicos** e **diferentes** do nosso sistema de eventos de negócio (`AppEventBus`).

---

## 📦 Eventos do Hive (Nativos)

### **O que é BoxEvent?**

O Hive dispara eventos nativos através de `box.watch()`:

```dart
Stream<BoxEvent> watch()
```

**BoxEvent** contém:
- `event.deleted` - `bool` - Indica se o objeto foi deletado
- `event.value` - `T?` - O valor (objeto) que foi modificado
- `event.key` - `dynamic` - A chave do objeto na box

### **Quando o Hive dispara BoxEvent?**

O Hive dispara `BoxEvent` automaticamente quando:
1. **`box.put(key, value)`** - Objeto criado ou atualizado
2. **`box.delete(key)`** - Objeto deletado
3. **`box.clear()`** - Box limpa

**Não dispara quando:**
- Você apenas lê dados (`box.get()`, `box.values`)
- Você apenas itera sobre dados

---

## 🔄 Fluxo Atual no Sistema

### **Cenário 1: Pedido Criado**

```
1. PedidoProvider.finalizarPedido()
   ↓
2. pedidoRepo.upsert(pedido) → box.put()
   ↓
3. Hive dispara BoxEvent (técnico)
   ↓
   ├─→ MesasProvider escuta BoxEvent
   │   └─→ Recalcula status da mesa
   │
   └─→ AutoSyncManager escuta BoxEvent
       └─→ Detecta pedido pendente
       └─→ Sincroniza pedido
       └─→ Quando sincroniza, atualiza status no Hive
           └─→ Hive dispara novo BoxEvent (status = sincronizado)
           └─→ AutoSyncManager detecta sincronizado
           └─→ Dispara AppEventBus.pedidoSincronizado (negócio)
               └─→ MesasProvider escuta AppEventBus
                   └─→ Recalcula status e atualiza do servidor
```

### **Cenário 2: Pedido Sincronizado**

```
1. AutoSyncManager sincroniza pedido
   ↓
2. Atualiza status no Hive: pedido.syncStatus = sincronizado
   ↓
3. pedidoRepo.upsert(pedido) → box.put()
   ↓
4. Hive dispara BoxEvent (técnico)
   ↓
   ├─→ MesasProvider escuta BoxEvent
   │   └─→ Recalcula status da mesa
   │
   └─→ AutoSyncManager escuta BoxEvent
       └─→ Detecta status = sincronizado
       └─→ Chama callback onPedidoSincronizado
           └─→ MesasProvider._setupSyncEventListener() recebe
           └─→ Dispara AppEventBus.pedidoSincronizado (negócio)
               └─→ MesasProvider escuta AppEventBus
                   └─→ Agenda atualização do servidor
```

---

## 🎯 Diferença: BoxEvent vs AppEvent

| Aspecto | BoxEvent (Hive) | AppEvent (AppEventBus) |
|---------|-----------------|------------------------|
| **Tipo** | Técnico | Negócio |
| **Disparado por** | Hive automaticamente | Código de negócio |
| **Quando** | Qualquer mudança na box | Ações de negócio específicas |
| **Conteúdo** | `deleted`, `value`, `key` | `tipo`, `dominio`, `dados` |
| **Propósito** | Notificar mudanças técnicas | Notificar eventos de negócio |
| **Listeners** | Múltiplos (via `box.watch()`) | Múltiplos (via `AppEventBus`) |

---

## 📍 Onde Escutamos BoxEvent?

### **1. MesasProvider**

```dart
_hiveSubscription = box.watch().listen((event) {
  if (event.deleted) {
    // Pedido removido
    _recalcularStatusMesa(pedidoRemovido.mesaId);
  } else {
    // Pedido adicionado/modificado
    _recalcularStatusMesa(pedido.mesaId!);
  }
});
```

**Propósito:** Recalcular status da mesa quando pedidos mudam.

---

### **2. AutoSyncManager**

```dart
_pedidoBoxSubscription = stream.listen((event) {
  if (event.deleted) return;
  Future.microtask(() => _processarMudancaPedido(event));
});
```

**Propósito:** 
- Detectar pedidos pendentes e sincronizar
- Detectar pedidos sincronizados e disparar evento de negócio

---

## 🔗 Integração: Hive → AppEventBus

### **Como funciona:**

1. **Hive dispara BoxEvent** (técnico)
2. **AutoSyncManager escuta BoxEvent**
3. **AutoSyncManager detecta evento de negócio** (ex: pedido sincronizado)
4. **AutoSyncManager dispara AppEvent** (negócio) via `AppEventBus`
5. **Outros componentes escutam AppEvent** e reagem

### **Código atual:**

```dart
// AutoSyncManager detecta sincronização via BoxEvent
if (pedido.syncStatus == SyncStatusPedido.sincronizado) {
  onPedidoSincronizado!(pedido.id, pedido.mesaId, pedido.comandaId);
}

// MesasProvider configura callback que dispara AppEvent
servicesProvider.autoSyncManager.onPedidoSincronizado = (pedidoId, mesaId, comandaId) {
  AppEventBus.instance.dispararPedidoSincronizado(
    pedidoId: pedidoId,
    mesaId: mesaId,
    comandaId: comandaId,
  );
};
```

---

## ✅ Situação Atual: Está Correto?

### **Pontos Positivos:**

1. ✅ **Separação clara:** BoxEvent (técnico) vs AppEvent (negócio)
2. ✅ **Hive funciona como esperado:** Dispara eventos técnicos automaticamente
3. ✅ **Integração funciona:** AutoSyncManager converte BoxEvent → AppEvent
4. ✅ **Múltiplos listeners:** Ambos suportam múltiplos listeners

### **Possíveis Melhorias:**

1. **Opção A: Manter como está** (Recomendado)
   - Funciona bem
   - Separação clara entre técnico e negócio
   - AutoSyncManager faz a ponte

2. **Opção B: Integrar diretamente no Repository**
   - Repository dispara AppEvent quando detecta mudanças importantes
   - Mais acoplado, mas mais direto

3. **Opção C: Criar camada intermediária**
   - Wrapper que escuta BoxEvent e dispara AppEvent automaticamente
   - Mais complexo, mas mais automático

---

## 📊 Diagrama Completo

```
┌─────────────────────────────────────────┐
│         Operações no Hive               │
│  box.put() / box.delete()               │
└──────────────┬──────────────────────────┘
               │
               │ Hive dispara automaticamente
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│  BoxEvent    │  │  BoxEvent    │
│  (técnico)   │  │  (técnico)   │
└──────┬───────┘  └──────┬───────┘
       │                 │
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│MesasProvider │  │AutoSyncManager│
│              │  │              │
│- Escuta      │  │- Escuta      │
│- Recalcula   │  │- Sincroniza  │
│  status      │  │- Detecta     │
│              │  │  sincronizado│
└──────────────┘  └──────┬───────┘
                         │
                         │ Dispara AppEvent
                         │
                         ▼
                  ┌──────────────┐
                  │  AppEventBus │
                  │  (negócio)   │
                  └──────┬───────┘
                         │
                         │ Eventos de negócio
                         │
                  ┌──────┴───────┐
                  │              │
                  ▼              ▼
            ┌──────────┐  ┌──────────┐
            │MesasProv │  │Outros    │
            │          │  │Listeners │
            │- Escuta  │  │          │
            │- Atualiza│  │- Escutam  │
            └──────────┘  └──────────┘
```

---

## 💡 Conclusão

**Hive tem eventos próprios** (`BoxEvent`) que são **técnicos** e **diferentes** do nosso sistema de eventos de negócio (`AppEventBus`).

**Fluxo atual:**
- Hive → BoxEvent (técnico) → AutoSyncManager → AppEventBus (negócio) → Listeners

**Está funcionando bem assim?**
- ✅ Sim, está correto!
- Separação clara entre técnico e negócio
- AutoSyncManager faz a ponte quando necessário

**Precisa mudar?**
- Não necessariamente, mas podemos melhorar se quiser integrar mais diretamente
