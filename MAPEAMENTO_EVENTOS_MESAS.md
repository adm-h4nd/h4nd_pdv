# Mapeamento de Eventos - Sistema de Mesas

## 📋 Resumo Executivo

Este documento mapeia **TODOS os eventos** que afetam o status das mesas e **QUEM os dispara**, para garantir controle centralizado e evitar conflitos.

---

## 🔴 EVENTOS IDENTIFICADOS

### 1. **Eventos do Hive (Mudanças na Box de Pedidos)**

#### **Tipo:** `BoxEvent` via `box.watch()`
#### **Disparado por:**
- `PedidoLocalRepository.upsert()` - Quando pedido é criado/modificado
- `PedidoLocalRepository.delete()` - Quando pedido é removido
- `SyncService` - Quando atualiza status de sincronização
- `AutoSyncManager` - Quando reseta pedidos travados

#### **Quem escuta atualmente:**
- ✅ `AutoSyncManager` - Escuta via `box.watch()` (linha 65-71)
- ✅ `MesasProvider` - Escuta via `box.watch()` (novo - linha 113-127)

#### **Quando dispara:**
- Pedido criado → `upsert()` → Hive dispara evento `BoxEvent` (não deletado)
- Pedido modificado → `upsert()` → Hive dispara evento `BoxEvent` (não deletado)
- Pedido removido → `delete()` → Hive dispara evento `BoxEvent` (deleted = true)
- Status mudado → `upsert()` → Hive dispara evento `BoxEvent`

#### **O que contém:**
```dart
BoxEvent {
  key: String (pedidoId),
  value: PedidoLocal? (pedido completo),
  deleted: bool (se foi removido)
}
```

---

### 2. **Evento de Sincronização Bem-Sucedida**

#### **Tipo:** Callback `onPedidoSincronizado`
#### **Disparado por:**
- `AutoSyncManager._processarMudancaPedido()` - Quando detecta `syncStatus == sincronizado` (linha 90-95)
- `AutoSyncManager._sincronizarPedido()` - Após sincronização bem-sucedida (linha 144-152)

#### **Quem escuta atualmente:**
- ⚠️ **PROBLEMA:** Callback único (`Function?`) - apenas UMA tela pode escutar
- `MesasProvider._setupSyncEventListener()` - Configura callback (linha 135)
- `detalhes_produtos_mesa_screen.dart` - Também configura callback (linha 125) ⚠️ **CONFLITO**

#### **Quando dispara:**
1. `AutoSyncManager` detecta pedido com `syncStatus == sincronizado` no Hive
2. OU após `SyncService.sincronizarPedidoIndividual()` retornar sucesso

#### **Parâmetros:**
```dart
onPedidoSincronizado(pedidoId, mesaId?, comandaId?)
```

#### **⚠️ PROBLEMA IDENTIFICADO:**
- Callback é **único** (`Function?`), não é uma lista
- Última tela que configura **sobrescreve** a anterior
- Se `MesasProvider` e `DetalhesProdutosMesaScreen` estão abertos simultaneamente → **conflito**

---

### 3. **Mudanças de Status de Sincronização**

#### **Quando acontece:**
- `pendente` → `sincronizando` → `sincronizado` (sucesso)
- `pendente` → `sincronizando` → `erro` (falha)
- `sincronizando` → `sincronizado` (após sucesso)
- `sincronizando` → `erro` (após falha)

#### **Disparado por:**
- `SyncService.sincronizarPedidoIndividual()` - Atualiza status durante sincronização
- `SyncService.sincronizarPedidos()` - Atualiza status em lote
- `AutoSyncManager` - Reseta pedidos travados

#### **Como detectado:**
- Via `box.watch()` - Qualquer mudança dispara evento do Hive
- Via `onPedidoSincronizado` - Apenas quando status vira `sincronizado`

---

## 🔄 FLUXO ATUAL DE EVENTOS

### **Cenário 1: Pedido Criado**

```
1. Usuário cria pedido
   ↓
2. PedidoProvider.upsert() salva no Hive
   ↓
3. Hive dispara BoxEvent (created/modified)
   ↓
4. AutoSyncManager recebe evento via box.watch()
   ↓
5. AutoSyncManager detecta status = pendente
   ↓
6. AutoSyncManager inicia sincronização
   ↓
7. SyncService atualiza status para sincronizando
   ↓
8. Hive dispara novo BoxEvent (status mudou)
   ↓
9. AutoSyncManager recebe evento (ignora - já está sincronizando)
   ↓
10. SyncService atualiza status para sincronizado
    ↓
11. Hive dispara novo BoxEvent (status = sincronizado)
    ↓
12. AutoSyncManager recebe evento
    ↓
13. AutoSyncManager dispara onPedidoSincronizado()
    ↓
14. MesasProvider recebe callback (se configurado)
    ↓
15. MesasProvider recalcula status da mesa
```

### **Cenário 2: Pedido Removido**

```
1. Pedido removido do Hive (delete)
   ↓
2. Hive dispara BoxEvent (deleted = true)
   ↓
3. AutoSyncManager recebe evento (ignora deleções - linha 67)
   ↓
4. MesasProvider recebe evento via box.watch()
   ↓
5. MesasProvider recalcula status da mesa
```

---

## ⚠️ PROBLEMAS IDENTIFICADOS

### **1. Callback Único (`onPedidoSincronizado`)**

**Problema:**
- `AutoSyncManager.onPedidoSincronizado` é um `Function?` único
- Apenas UMA tela pode escutar por vez
- Última configuração sobrescreve a anterior

**Exemplo de conflito:**
```dart
// Tela 1 (MesasScreen)
servicesProvider.autoSyncManager.onPedidoSincronizado = (id, mesaId, comandaId) {
  // Lógica da tela de mesas
};

// Tela 2 (DetalhesProdutosMesaScreen) - ABRE DEPOIS
servicesProvider.autoSyncManager.onPedidoSincronizado = (id, mesaId, comandaId) {
  // Lógica da tela de detalhes
  // ⚠️ SOBRESCREVE a configuração anterior!
};
```

**Solução proposta:**
- Sistema de eventos com múltiplos listeners (lista de callbacks)
- OU usar apenas eventos do Hive (mais confiável)

---

### **2. Múltiplos Listeners do Hive**

**Atual:**
- `AutoSyncManager` escuta via `box.watch()`
- `MesasProvider` escuta via `box.watch()`
- UI escuta via `ValueListenableBuilder` (removido na refatoração)

**Status:** ✅ OK - Múltiplos listeners do Hive são permitidos

---

### **3. Timing de Atualização**

**Problema:**
- Quando pedido sincroniza, status muda para `sincronizado`
- Mas pedido ainda está no Hive
- Backend pode levar tempo para atualizar status da mesa
- Status visual pode ficar inconsistente

**Solução atual:**
- Verificar pedidos recém-sincronizados (últimos 10s)
- Aguardar antes de atualizar do servidor

---

## ✅ ARQUITETURA PROPOSTA

### **Sistema de Eventos Centralizado**

```
┌─────────────────────────────────────────┐
│         Hive (Box de Pedidos)           │
│  - upsert() → BoxEvent                   │
│  - delete() → BoxEvent                   │
└──────────────┬──────────────────────────┘
               │
               │ box.watch()
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│AutoSyncManager│  │MesasProvider │
│              │  │              │
│- Sincroniza  │  │- Recalcula   │
│- Dispara     │  │  status      │
│  callback    │  │- Notifica UI │
└──────┬───────┘  └──────────────┘
       │
       │ onPedidoSincronizado
       │ (callback único)
       │
       ▼
┌──────────────┐
│MesasProvider │
│(se configurado)│
└──────────────┘
```

---

## ✅ SOLUÇÃO IMPLEMENTADA: Sistema de Eventos Centralizado

### **MesaEventManager - Sistema Centralizado**

**Arquivo:** `lib/core/events/mesa_event_manager.dart`

**Características:**
- ✅ Suporta múltiplos listeners (sem conflitos)
- ✅ Suporta listeners específicos por tipo de evento
- ✅ Suporta eventos do Hive E eventos manuais
- ✅ Singleton global (acessível de qualquer lugar)

**Tipos de Eventos Suportados:**
1. `pedidoLocalMudou` - Pedido criado/modificado/removido no Hive
2. `pedidoSincronizado` - Pedido sincronizado com sucesso
3. `vendaFinalizada` - Venda finalizada (pagamento completo)
4. `comandaPaga` - Comanda paga
5. `pedidoFinalizado` - Pedido finalizado no servidor
6. `mesaLiberada` - Mesa liberada manualmente
7. `statusMesaAtualizado` - Status da mesa atualizado no servidor

**Como Usar:**

```dart
// Disparar evento manualmente
MesaEventManager().dispararVendaFinalizada(
  vendaId: vendaId,
  mesaId: mesaId,
  comandaId: comandaId,
);

// Escutar eventos
MesaEventManager().addListenerPorTipo(
  TipoEventoMesa.vendaFinalizada,
  (evento) {
    // Lógica quando venda é finalizada
  },
);
```

---

## 🔄 FLUXO ATUALIZADO COM SISTEMA DE EVENTOS

### **Cenário 1: Pedido Criado**

```
1. Usuário cria pedido
   ↓
2. PedidoProvider.upsert() salva no Hive
   ↓
3. Hive dispara BoxEvent
   ↓
4. MesasProvider recebe evento via box.watch()
   ↓
5. MesasProvider dispara evento centralizado: pedidoLocalMudou
   ↓
6. MesasProvider recalcula status da mesa
   ↓
7. AutoSyncManager também recebe evento (sincroniza)
   ↓
8. Quando sincroniza, AutoSyncManager dispara evento: pedidoSincronizado
   ↓
9. MesasProvider recebe evento centralizado
   ↓
10. MesasProvider recalcula status e agenda atualização do servidor
```

### **Cenário 2: Venda Finalizada**

```
1. Usuário finaliza venda
   ↓
2. VendaService.concluirVenda() chamado
   ↓
3. Backend processa e atualiza status da mesa
   ↓
4. Código dispara evento manual: vendaFinalizada
   ↓
5. MesasProvider recebe evento centralizado
   ↓
6. MesasProvider recalcula status e atualiza do servidor imediatamente
```

### **Cenário 3: Comanda Paga**

```
1. Usuário paga comanda
   ↓
2. Pagamento processado no servidor
   ↓
3. Código dispara evento manual: comandaPaga
   ↓
4. MesasProvider recebe evento centralizado
   ↓
5. MesasProvider atualiza status da mesa
```

---

## 📊 QUADRO RESUMO

| Evento | Disparado Por | Quem Escuta | Tipo | Problema |
|--------|---------------|-------------|------|----------|
| `BoxEvent` (Hive) | `upsert()`, `delete()` | `AutoSyncManager`, `MesasProvider` | Stream | ✅ OK |
| `onPedidoSincronizado` | `AutoSyncManager` | Único callback | Function? | ⚠️ Conflito |

---

## 🔧 PRÓXIMOS PASSOS

1. **Decidir:** Usar apenas Hive OU sistema de múltiplos listeners?
2. **Implementar:** Escolha feita
3. **Testar:** Validar que não há conflitos
4. **Documentar:** Atualizar arquitetura final

