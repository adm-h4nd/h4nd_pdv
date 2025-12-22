# Arquitetura de Eventos - Sistema Completo

## 🎯 Conceito: Event Bus Único Genérico (Observable Pattern)

Similar ao Observable do Angular, temos um sistema centralizado de eventos onde:
- **Quando algo acontece**, dispara um evento
- **Múltiplos listeners** podem escutar o mesmo evento
- **Cada listener trata** o que precisa fazer
- **Um único Event Bus** para todo o sistema (`AppEventBus`)

---

## 📊 Arquitetura

```
┌─────────────────────────────────────────┐
│         Ações do Sistema                │
│  - Pedido criado                        │
│  - Venda finalizada                     │
│  - Comanda paga                         │
│  - Pedido sincronizado                  │
└──────────────┬──────────────────────────┘
               │
               │ dispara evento
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│MesaEventBus  │  │Hive (técnico) │
│(negócio)     │  │              │
│              │  │- upsert()    │
│- broadcast() │  │- delete()    │
│- múltiplos   │  │              │
│  listeners   │  └──────┬───────┘
└──────┬───────┘         │
       │                 │ dispara evento técnico
       │                 │
       │                 ▼
       │         ┌──────────────┐
       │         │AutoSyncManager│
       │         │              │
       │         │- detecta     │
       │         │  sincronizado│
       │         └──────┬───────┘
       │                │ dispara evento de negócio
       │                │
       └────────────────┘
               │
               │ eventos
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│MesasProvider │  │Outros        │
│              │  │Listeners     │
│- escuta      │  │              │
│- atualiza    │  │- podem       │
│  status      │  │  escutar     │
└──────────────┘  └──────────────┘
```

---

## 🔔 Eventos Disponíveis

### **Eventos de Negócio (AppEventBus)**

#### **Domínio: Mesas**
| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `pedidoCriado` | `PedidoProvider.finalizarPedido()` | Pedido salvo localmente |
| `pedidoSincronizado` | `AutoSyncManager` | Pedido sincronizado com sucesso |
| `pedidoFinalizado` | Quando pedido finalizado no servidor | Pedido finalizado |
| `vendaFinalizada` | `VendaService.concluirVenda()` | Venda finalizada |
| `comandaPaga` | Quando comanda é paga | Comanda paga |
| `mesaLiberada` | Quando mesa é liberada | Mesa liberada |
| `statusMesaMudou` | Quando status muda | Status mudou |

#### **Domínio: Produtos**
| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `produtoCriado` | Quando produto é criado | Produto criado |
| `produtoAtualizado` | Quando produto é atualizado | Produto atualizado |
| `produtoDeletado` | Quando produto é deletado | Produto deletado |
| `produtoSincronizado` | Quando produto sincroniza | Produto sincronizado |

#### **Domínio: Vendas**
| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `vendaCriada` | Quando venda é criada | Venda criada |
| `vendaCancelada` | Quando venda é cancelada | Venda cancelada |
| `pagamentoProcessado` | Quando pagamento é processado | Pagamento processado |

#### **Domínio: Sincronização**
| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `sincronizacaoIniciada` | Quando sincronização inicia | Sincronização inicia |
| `sincronizacaoConcluida` | Quando sincronização termina | Sincronização termina |
| `sincronizacaoErro` | Quando há erro na sincronização | Erro na sincronização |

#### **Domínio: Autenticação**
| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `usuarioLogado` | Quando usuário faz login | Login realizado |
| `usuarioDeslogado` | Quando usuário faz logout | Logout realizado |
| `tokenExpirado` | Quando token expira | Token expirado |

### **Eventos Técnicos (Hive)**

| Evento | Disparado Por | Quando |
|--------|---------------|--------|
| `BoxEvent` | Hive | Pedido criado/modificado/removido |

---

## 🔧 Como Usar

### **1. Disparar Evento**

```dart
// Método auxiliar (recomendado)
AppEventBus.instance.dispararVendaFinalizada(
  vendaId: vendaId,
  mesaId: mesaId,
  comandaId: comandaId,
);

// Ou evento genérico
AppEventBus.instance.disparar(AppEvent(
  tipo: TipoEvento.vendaFinalizada,
  dominio: DominioEvento.mesa,
  dados: {
    'vendaId': vendaId,
    'mesaId': mesaId,
    'comandaId': comandaId,
  },
));
```

### **2. Escutar Eventos**

```dart
// Escutar tipo específico
AppEventBus.instance.on(TipoEvento.vendaFinalizada).listen((evento) {
  // Fazer algo quando venda é finalizada
  final mesaId = evento.mesaId;
  final vendaId = evento.vendaId;
});

// Escutar eventos de um domínio específico
AppEventBus.instance.onDominio(DominioEvento.mesa).listen((evento) {
  // Fazer algo quando qualquer evento de mesa acontece
});

// Escutar eventos de uma mesa específica
AppEventBus.instance.onMesa(mesaId).listen((evento) {
  // Fazer algo quando qualquer evento acontece na mesa
});

// Escutar tipo E domínio
AppEventBus.instance.onTipoEDominio(
  TipoEvento.vendaFinalizada,
  DominioEvento.mesa,
).listen((evento) {
  // Fazer algo quando venda específica é finalizada
});
```

---

## 📍 Pontos de Integração

### **✅ Já Integrados**

1. **Pedido Criado**
   - `PedidoProvider.finalizarPedido()` → dispara `pedidoCriado`

2. **Pedido Sincronizado**
   - `AutoSyncManager` → dispara `pedidoSincronizado` via `MesasProvider._setupSyncEventListener()`

3. **Venda Finalizada**
   - `detalhes_produtos_mesa_screen.dart` → dispara `vendaFinalizada`
   - `pagamento_restaurante_screen.dart` → dispara `vendaFinalizada`

### **⚠️ Pendentes de Integração**

1. **Comanda Paga**
   - Quando comanda é paga → disparar `comandaPaga`

2. **Pedido Finalizado**
   - Quando pedido é finalizado no servidor → disparar `pedidoFinalizado`

3. **Mesa Liberada**
   - Quando mesa é liberada manualmente → disparar `mesaLiberada`

---

## 🎯 Fluxo Completo: Pedido Criado → Mesa Atualizada

```
1. Usuário cria pedido
   ↓
2. PedidoProvider.finalizarPedido()
   ↓
3. Salva no Hive (upsert)
   ↓
4. Dispara evento: pedidoCriado
   ↓
5. Hive dispara BoxEvent (técnico)
   ↓
6. MesasProvider escuta BoxEvent
   ↓
7. MesasProvider recalcula status local
   ↓
8. AutoSyncManager detecta pedido pendente
   ↓
9. AutoSyncManager sincroniza pedido
   ↓
10. AutoSyncManager atualiza status no Hive
    ↓
11. Hive dispara BoxEvent (status = sincronizado)
    ↓
12. AutoSyncManager dispara evento: pedidoSincronizado
    ↓
13. MesasProvider escuta evento
    ↓
14. MesasProvider recalcula status
    ↓
15. MesasProvider agenda atualização do servidor
    ↓
16. MesasProvider atualiza do servidor
    ↓
17. UI atualiza automaticamente (notifyListeners)
```

---

## ✅ Vantagens

1. **Desacoplamento:** Quem dispara não precisa saber quem escuta
2. **Múltiplos Listeners:** Vários componentes podem reagir ao mesmo evento
3. **Fácil de Estender:** Adicionar novos listeners é simples
4. **Testável:** Eventos podem ser mockados facilmente
5. **Centralizado:** Um único ponto de verdade para eventos
6. **Genérico:** Suporta múltiplos domínios (mesas, produtos, vendas, etc)
7. **Organizado:** Eventos organizados por domínio facilitam manutenção

---

## 📝 Resumo

- **AppEventBus:** Sistema centralizado único de eventos (tipo Observable do Angular)
- **Domínios:** Mesas, Produtos, Vendas, Sincronização, Autenticação
- **Hive:** Apenas dispara eventos técnicos de sincronização
- **MesasProvider:** Escuta eventos e atualiza status das mesas
- **Outros Listeners:** Podem escutar eventos conforme necessário
- **Extensível:** Fácil adicionar novos eventos e domínios

