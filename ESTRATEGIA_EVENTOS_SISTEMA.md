# Estratégia de Eventos no Sistema

## 🎯 Análise dos Domínios

### **Domínios Identificados:**

1. **Mesas** ✅ (já tem Event Bus)
   - Eventos: pedido criado, venda finalizada, comanda paga, etc.

2. **Pedidos**
   - Operações: criar, atualizar, finalizar, cancelar, sincronizar
   - Quem precisa saber: MesasProvider, SyncProvider, telas de pedidos

3. **Vendas**
   - Operações: criar, finalizar, cancelar, pagar
   - Quem precisa saber: MesasProvider, telas de vendas, relatórios

4. **Produtos**
   - Operações: criar, atualizar, deletar, sincronizar
   - Quem precisa saber: Telas de produtos, sincronização, cache

5. **Comandas**
   - Operações: criar, pagar, fechar
   - Quem precisa saber: MesasProvider, telas de comandas

6. **Sincronização**
   - Operações: iniciar, concluir, erro
   - Quem precisa saber: SyncProvider, telas de sincronização, indicadores

7. **Autenticação**
   - Operações: login, logout, token expirado
   - Quem precisa saber: Todas as telas, navegação

---

## 🤔 Opções de Arquitetura

### **Opção 1: Event Bus Único Genérico** ⭐ RECOMENDADO

**Estrutura:**
```dart
enum TipoEvento {
  // Mesas
  pedidoCriado,
  vendaFinalizada,
  comandaPaga,
  
  // Produtos
  produtoCriado,
  produtoAtualizado,
  produtoSincronizado,
  
  // Sincronização
  sincronizacaoIniciada,
  sincronizacaoConcluida,
  sincronizacaoErro,
  
  // Autenticação
  usuarioLogado,
  usuarioDeslogado,
  tokenExpirado,
}

class AppEvent {
  final TipoEvento tipo;
  final String? dominio; // 'mesa', 'produto', 'sincronizacao', etc
  final Map<String, dynamic>? dados;
  final DateTime timestamp;
}

class AppEventBus {
  final StreamController<AppEvent> _controller;
  
  void disparar(AppEvent evento);
  Stream<AppEvent> on(TipoEvento tipo);
  Stream<AppEvent> onDominio(String dominio);
}
```

**Vantagens:**
- ✅ Um único ponto de verdade
- ✅ Fácil de gerenciar e debugar
- ✅ Listeners podem escutar múltiplos domínios
- ✅ Menos código duplicado

**Desvantagens:**
- ⚠️ Enum pode ficar grande (mas é gerenciável)
- ⚠️ Precisa filtrar por domínio se necessário

---

### **Opção 2: Event Buses Separados por Domínio**

**Estrutura:**
```dart
MesaEventBus
ProdutoEventBus
VendaEventBus
SincronizacaoEventBus
AuthEventBus
```

**Vantagens:**
- ✅ Separação clara de responsabilidades
- ✅ Enums menores e mais específicos
- ✅ Type-safe por domínio

**Desvantagens:**
- ❌ Múltiplos singletons para gerenciar
- ❌ Código duplicado (cada um tem mesma estrutura)
- ❌ Mais complexo para listeners que precisam de múltiplos domínios

---

### **Opção 3: Event Bus Genérico com Tipos**

**Estrutura:**
```dart
class AppEventBus<T> {
  final StreamController<T> _controller;
  
  void disparar(T evento);
  Stream<T> on<U extends T>(bool Function(U) filter);
}

// Uso:
MesaEventBus = AppEventBus<MesaEvento>
ProdutoEventBus = AppEventBus<ProdutoEvento>
```

**Vantagens:**
- ✅ Type-safe
- ✅ Reutilizável
- ✅ Separação por domínio mantida

**Desvantagens:**
- ⚠️ Mais complexo de implementar
- ⚠️ Listeners precisam conhecer tipos específicos

---

## 🎯 Recomendação: Opção 1 (Event Bus Único Genérico)

### **Por quê?**

1. **Simplicidade:** Um único ponto de verdade é mais fácil de gerenciar
2. **Flexibilidade:** Listeners podem escutar eventos de múltiplos domínios
3. **Manutenibilidade:** Menos código duplicado
4. **Escalabilidade:** Fácil adicionar novos tipos de eventos

### **Estrutura Proposta:**

```dart
// lib/core/events/app_event_bus.dart

enum TipoEvento {
  // === MESAS ===
  pedidoCriado,
  pedidoSincronizado,
  pedidoFinalizado,
  vendaFinalizada,
  comandaPaga,
  mesaLiberada,
  statusMesaMudou,
  
  // === PRODUTOS ===
  produtoCriado,
  produtoAtualizado,
  produtoDeletado,
  produtoSincronizado,
  
  // === VENDAS ===
  vendaCriada,
  vendaCancelada,
  pagamentoProcessado,
  
  // === SINCRONIZAÇÃO ===
  sincronizacaoIniciada,
  sincronizacaoConcluida,
  sincronizacaoErro,
  
  // === AUTENTICAÇÃO ===
  usuarioLogado,
  usuarioDeslogado,
  tokenExpirado,
}

class AppEvent {
  final TipoEvento tipo;
  final String? dominio; // 'mesa', 'produto', 'venda', etc
  final Map<String, dynamic>? dados;
  final DateTime timestamp;
  
  // Getters auxiliares
  String? get mesaId => dados?['mesaId'];
  String? get pedidoId => dados?['pedidoId'];
  String? get produtoId => dados?['produtoId'];
  // ... outros getters conforme necessário
}

class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  
  final StreamController<AppEvent> _controller = 
    StreamController<AppEvent>.broadcast();
  
  Stream<AppEvent> get stream => _controller.stream;
  
  void disparar(AppEvent evento);
  Stream<AppEvent> on(TipoEvento tipo);
  Stream<AppEvent> onDominio(String dominio);
  
  // Métodos auxiliares por domínio
  void dispararPedidoCriado({required String pedidoId, ...});
  void dispararProdutoAtualizado({required String produtoId, ...});
  // ... outros métodos auxiliares
}
```

---

## 📋 Migração do MesaEventBus Atual

### **Passo 1:** Criar `AppEventBus` genérico
### **Passo 2:** Migrar eventos de mesa para `AppEventBus`
### **Passo 3:** Atualizar `MesasProvider` para usar `AppEventBus`
### **Passo 4:** Remover `MesaEventBus` antigo
### **Passo 5:** Adicionar eventos de outros domínios conforme necessário

---

## 🎯 Eventos Prioritários para Implementar

### **Alta Prioridade:**
1. ✅ Mesas (já feito)
2. 🔴 Produtos (sincronização, atualização)
3. 🔴 Sincronização (status geral)

### **Média Prioridade:**
4. 🟡 Vendas (criação, cancelamento)
5. 🟡 Comandas (operações)

### **Baixa Prioridade:**
6. 🟢 Autenticação (se necessário)

---

## ✅ Próximos Passos

1. **Decidir arquitetura** (recomendo Opção 1)
2. **Criar AppEventBus genérico**
3. **Migrar MesaEventBus para AppEventBus**
4. **Adicionar eventos de Produtos**
5. **Adicionar eventos de Sincronização**
6. **Documentar uso**

---

## 💡 Conclusão

**Recomendação:** Criar um **Event Bus único genérico** (`AppEventBus`) que suporta todos os domínios. Isso mantém a simplicidade enquanto permite crescimento futuro.

**Alternativa:** Se preferir separação mais rígida, usar **Opção 3** (genérico com tipos), mas é mais complexo.
