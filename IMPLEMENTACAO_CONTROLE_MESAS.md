# Implementação: Controle de Mesas com Múltiplos Pedidos

## ✅ O que foi implementado

### **1. Novos Eventos no AppEventBus**

Adicionados eventos para cobrir todas as situações:
- ✅ `pedidoCriado` - Quando pedido pendente é criado
- ✅ `pedidoSincronizando` - Quando pedido começa a sincronizar
- ✅ `pedidoSincronizado` - Quando pedido sincroniza com sucesso
- ✅ `pedidoErro` - Quando pedido falha na sincronização
- ✅ `pedidoRemovido` - Quando pedido é deletado

---

### **2. AutoSyncManager Refatorado**

**Responsabilidades:**
- ✅ ÚNICO lugar que escuta BoxEvent do Hive
- ✅ Rastreia status anterior dos pedidos para detectar mudanças
- ✅ Processa deleções (não ignora mais)
- ✅ Dispara TODOS os eventos de negócio via AppEventBus
- ✅ Gerencia sincronização de pedidos

**Mudanças:**
- ✅ Adicionado `_carregarStatusInicial()` para rastrear status inicial
- ✅ Adicionado `_statusAnteriorPorPedido` para detectar mudanças
- ✅ Refatorado `_processarMudancaPedido()` para processar deleções
- ✅ Adicionado `_dispararEventosPorMudancaStatus()` para disparar eventos apropriados
- ✅ Processa pedidos novos e detecta mudanças de status

---

### **3. MesasProvider Refatorado**

**Responsabilidades:**
- ✅ Escuta APENAS AppEventBus (eventos de negócio)
- ✅ NÃO escuta Hive diretamente
- ✅ Implementa contadores por status
- ✅ Implementa regras de prioridade para status visual

**Mudanças:**
- ❌ Removido `_setupHiveListener()` - não escuta Hive mais
- ❌ Removido `_hiveSubscription` - não precisa mais
- ❌ Removido `_setupSyncEventListener()` - AutoSyncManager dispara eventos diretamente
- ✅ Refatorado `_setupEventBusListener()` para escutar todos os eventos de pedidos
- ✅ Refatorado `MesaStatusCalculado` para incluir contadores por status
- ✅ Refatorado `_recalcularStatusMesa()` para implementar regras de prioridade

---

### **4. MesaStatusCalculado Aprimorado**

**Novos campos:**
```dart
final int pedidosPendentes;
final int pedidosSincronizando;
final int pedidosComErro;
final int pedidosSincronizados;
```

**Novos getters:**
- `totalPedidosLocais` - Soma de pendentes + sincronizando + erros
- `temPedidosPendentesOuErro` - Se tem pedidos que precisam atenção
- `estaSincronizando` - Se está sincronizando no momento

---

### **5. Regras de Prioridade Implementadas**

**Lógica de Status Visual:**
```dart
if (pedidosPendentes > 0) {
  statusVisual = 'ocupada'; // Prioridade máxima
} else if (pedidosSincronizando > 0) {
  statusVisual = 'ocupada'; // Prioridade alta
} else if (pedidosComErro > 0) {
  statusVisual = 'ocupada'; // Prioridade média
} else if (pedidosRecemSincronizados) {
  statusVisual = 'ocupada'; // Temporário
} else {
  statusVisual = statusDoServidor; // Usa servidor
}
```

**Prioridade:** `pendente > sincronizando > erro > servidor`

---

## 🔄 Fluxo Completo

### **Cenário: Pedido Criado**

```
1. PedidoProvider.finalizarPedido()
   ↓
2. pedidoRepo.upsert(pedido) → box.put()
   ↓
3. Hive dispara BoxEvent (técnico)
   ↓
4. AutoSyncManager escuta BoxEvent
   ↓
5. AutoSyncManager detecta: pedido novo pendente
   ↓
6. AutoSyncManager dispara: pedidoCriado (negócio)
   ↓
7. MesasProvider escuta AppEventBus
   ↓
8. MesasProvider recalcula status:
   - Incrementa pedidosPendentes
   - Status visual: "ocupada" (pendente)
   ↓
9. UI atualiza automaticamente
```

### **Cenário: Múltiplos Pedidos**

```
Mesa 5 tem:
- Pedido A: pendente
- Pedido B: sincronizando
- Pedido C: sincronizado
- Pedido D: erro

Contadores:
- pendentes: 1
- sincronizando: 1
- sincronizados: 1
- erros: 1

Status Visual: "ocupada" (pendente)
Por quê? Pedidos pendentes têm prioridade máxima
```

---

## 📊 Arquitetura Final

```
┌─────────────────────────────────────────┐
│         Hive (Box de Pedidos)          │
│  box.put() / box.delete()               │
└──────────────┬──────────────────────────┘
               │
               │ BoxEvent (técnico)
               │
               ▼
┌─────────────────────────────────────────┐
│      AutoSyncManager                     │
│  (ÚNICO que escuta Hive)                │
│                                         │
│  - Escuta BoxEvent                      │
│  - Rastreia mudanças de status          │
│  - Processa deleções                    │
│  - Dispara eventos de NEGÓCIO          │
└──────────────┬──────────────────────────┘
               │
               │ AppEvent (negócio)
               │
               ▼
┌─────────────────────────────────────────┐
│         AppEventBus                      │
│  - pedidoCriado                         │
│  - pedidoSincronizando                  │
│  - pedidoSincronizado                   │
│  - pedidoErro                           │
│  - pedidoRemovido                       │
└──────────────┬──────────────────────────┘
               │
               │ Eventos de negócio
               │
               ▼
┌─────────────────────────────────────────┐
│      MesasProvider                       │
│  (Escuta APENAS AppEventBus)            │
│                                         │
│  - Escuta eventos de pedidos            │
│  - Recalcula contadores por status      │
│  - Aplica regras de prioridade          │
│  - Atualiza status visual               │
└─────────────────────────────────────────┘
```

---

## ✅ Vantagens da Implementação

1. **Separação de Responsabilidades**
   - AutoSyncManager: técnico (Hive)
   - MesasProvider: negócio (mesas)

2. **Desacoplamento**
   - MesasProvider não conhece Hive
   - Mudanças no Hive não afetam MesasProvider diretamente

3. **Manutenibilidade**
   - Um único lugar escuta BoxEvent
   - Eventos de negócio são claros e semânticos
   - Fácil adicionar novos listeners

4. **Escalabilidade**
   - Fácil adicionar novos eventos
   - Fácil adicionar novos listeners
   - Regras de prioridade bem definidas

5. **Testabilidade**
   - Pode mockar AppEventBus facilmente
   - Não precisa mockar Hive para testar MesasProvider

---

## 🎯 Próximos Passos para Teste

1. **Testar criação de pedido**
   - Criar pedido → Verificar se mesa fica ocupada
   - Verificar contadores

2. **Testar sincronização**
   - Verificar se status muda para sincronizando
   - Verificar se status muda para sincronizado
   - Verificar se busca servidor após todos sincronizados

3. **Testar múltiplos pedidos**
   - Criar vários pedidos na mesma mesa
   - Verificar se status reflete corretamente
   - Verificar prioridade

4. **Testar erros**
   - Simular erro na sincronização
   - Verificar se status mostra erro
   - Verificar se retry funciona

5. **Testar deleção**
   - Deletar pedido
   - Verificar se status recalcula
   - Verificar se mesa fica livre se era último pedido

---

## 📝 Resumo

✅ **Implementação completa e organizada**
✅ **Seguindo melhores práticas**
✅ **Separação clara de responsabilidades**
✅ **Pronto para testes**
