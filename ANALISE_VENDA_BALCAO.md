# Análise Completa - Venda Balcão

## 📋 Índice
1. [Fluxo Completo](#fluxo-completo)
2. [Flags e Estados](#flags-e-estados)
3. [Arquitetura e Componentes](#arquitetura-e-componentes)
4. [Duplicação de Código](#duplicação-de-código)
5. [Problemas Identificados](#problemas-identificados)
6. [Sugestões de Refatoração](#sugestões-de-refatoração)

---

## 🔄 Fluxo Completo

### 1. Navegação para Tela Balcão
```
Usuário clica em "Balcão" no bottom navigation
  ↓
BalcaoScreen é exibida no IndexedStack
  ↓
_onNavigationIndexChanged() detecta navegação
  ↓
_verificarVendaPendente() é chamado
```

### 2. Verificação de Venda Pendente
```
_verificarVendaPendente()
  ↓
_isChecking = true (mostra loading)
  ↓
VendaBalcaoPendenteService.obterVendaPendente()
  ↓
  ├─ Se vendaId == null:
  │   └─ _isChecking = false
  │   └─ _hasVendaPendente = false
  │   └─ Mostra NovoPedidoRestauranteScreen (isVendaBalcao=true)
  │
  └─ Se vendaId != null:
      └─ _hasVendaPendente = true (continua loading)
      └─ _abrirPagamentoPendente(vendaId)
```

### 3. Busca e Abertura de Pagamento Pendente
```
_abrirPagamentoPendente(vendaId)
  ↓
_hasVendaPendente = true (loading)
  ↓
vendaService.getVendaById(vendaId) [CHAMADA API]
  ↓
  ├─ Se erro:
  │   └─ Limpa venda pendente
  │   └─ Mostra tela de pedido
  │
  └─ Se sucesso:
      └─ BalcaoPaymentHelper.abrirPagamentoComConfirmacao()
```

### 4. Criação de Novo Pedido Balcão
```
NovoPedidoRestauranteScreen (isVendaBalcao=true)
  ↓
initState() verifica venda pendente
  ├─ Se tem pendente → fecha tela
  └─ Se não tem → inicializa pedido normalmente
  ↓
Usuário seleciona produtos
  ↓
Clica em "Finalizar"
  ↓
_finalizarPedido() detecta isVendaBalcao=true
  ↓
_finalizarPedidoBalcao()
```

### 5. Finalização do Pedido Balcão
```
_finalizarPedidoBalcao()
  ↓
Mostra loading
  ↓
pedidoProvider.finalizarPedidoBalcao()
  ↓
  ├─ Converte PedidoLocal → CreatePedidoDto
  └─ Envia para API (pedidoService.createPedido())
  ↓
Recebe PedidoDto com vendaId
  ↓
VendaBalcaoPendenteService.salvarVendaPendente(vendaId)
  ↓
Busca venda (vendaService.getVendaById())
  ↓
Fecha tela de pedido
  ↓
BalcaoPaymentHelper.abrirPagamentoComConfirmacao()
```

### 6. Fluxo de Pagamento
```
BalcaoPaymentHelper.abrirPagamentoComConfirmacao()
  ↓
Loop while (!pagamentoFinalizado):
  ↓
PagamentoRestauranteScreen.show()
  ↓
  ├─ Se result == true (pagamento processado):
  │   └─ Busca venda atualizada
  │   └─ Se saldo > 0.01 → reabre pagamento (parcial)
  │   └─ Se saldo <= 0.01 → reabre para concluir
  │
  ├─ Se result != true (fechou sem finalizar):
  │   └─ Mostra modal de confirmação
  │   └─ Se "Cancelar" → limpa pendente → sai do loop
  │   └─ Se "Continuar" → busca venda → reabre pagamento
  │
  └─ Se onPaymentSuccess() chamado:
      └─ Limpa venda pendente
      └─ pagamentoFinalizado = true → sai do loop
```

---

## 🏷️ Flags e Estados

### Flags Principais

#### 1. `isVendaBalcao` (bool)
- **Localização**: `NovoPedidoRestauranteScreen`
- **Propósito**: Indica se é venda balcão ou venda mesa
- **Uso**:
  - Controla qual fluxo usar ao finalizar pedido
  - Bloqueia criação de novo pedido se houver venda pendente
  - Passado para `NovoPedidoRestauranteScreen` via construtor

#### 2. `_isChecking` (bool)
- **Localização**: `BalcaoScreen._BalcaoScreenState`
- **Propósito**: Indica se está verificando venda pendente
- **Estados**:
  - `true`: Verificando venda pendente → mostra loading
  - `false`: Verificação terminou → pode mostrar tela de pedido

#### 3. `_hasVendaPendente` (bool)
- **Localização**: `BalcaoScreen._BalcaoScreenState`
- **Propósito**: Indica se tem venda pendente sendo processada
- **Estados**:
  - `true`: Buscando dados da venda ou abrindo pagamento → mostra loading
  - `false`: Não tem venda pendente → mostra tela de pedido

#### 4. `_ultimoIndiceVerificado` (int?)
- **Localização**: `BalcaoScreen._BalcaoScreenState`
- **Propósito**: Controla verificação de navegação (evita múltiplas verificações)
- **Uso**: Resetado quando navega para outra tela

#### 5. `_pedidoScreenKey` (int)
- **Localização**: `BalcaoScreen._BalcaoScreenState`
- **Propósito**: Força reconstrução da tela de pedido
- **Uso**: Incrementado quando não há venda pendente para garantir recarregamento de produtos

#### 6. `pagamentoFinalizado` (bool)
- **Localização**: `BalcaoPaymentHelper.abrirPagamentoComConfirmacao()`
- **Propósito**: Controla loop de pagamento
- **Estados**:
  - `false`: Continua loop, reabre pagamento
  - `true`: Sai do loop, finaliza fluxo

---

## 🏗️ Arquitetura e Componentes

### Componentes Principais

#### 1. `BalcaoScreen`
- **Responsabilidade**: Gerenciar navegação e verificação de venda pendente
- **Estados**: Loading, Tela de Pedido, Pagamento Pendente
- **Dependências**: `VendaBalcaoPendenteService`, `ServicesProvider`

#### 2. `NovoPedidoRestauranteScreen`
- **Responsabilidade**: Tela unificada para seleção de produtos (mesa e balcão)
- **Comportamento Adaptativo**: Baseado em `isVendaBalcao`
- **Fluxos**:
  - `isVendaBalcao=false`: Salva no Hive, fecha tela
  - `isVendaBalcao=true`: Envia para API, abre pagamento

#### 3. `BalcaoPaymentHelper`
- **Responsabilidade**: Gerenciar fluxo de pagamento com confirmação
- **Características**:
  - Loop até finalizar ou cancelar
  - Detecta pagamento parcial e reabre automaticamente
  - Mostra modal de confirmação ao fechar sem finalizar

#### 4. `VendaBalcaoPendenteService`
- **Responsabilidade**: Persistir ID da venda pendente
- **Armazenamento**: `PreferencesService` (não usa Hive)
- **Métodos**: `salvarVendaPendente()`, `obterVendaPendente()`, `limparVendaPendente()`

#### 5. `PedidoProvider.finalizarPedidoBalcao()`
- **Responsabilidade**: Enviar pedido diretamente para API
- **Diferença de `finalizarPedido()`**: Não salva no Hive, retorna `PedidoDto` com `vendaId`

---

## 🔁 Duplicação de Código

### 1. Busca de Venda Repetida
**Localizações**:
- `BalcaoScreen._abrirPagamentoPendente()` (linha 285)
- `BalcaoPaymentHelper.abrirPagamentoComConfirmacao()` (linhas 100, 125)
- `NovoPedidoRestauranteScreen._finalizarPedidoBalcao()` (linha 1135)

**Código Duplicado**:
```dart
final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
final vendaService = servicesProvider.vendaService;
final vendaResponse = await vendaService.getVendaById(vendaId);
if (vendaResponse.success && vendaResponse.data != null) {
  final venda = vendaResponse.data!;
  // ...
}
```

**Solução**: Criar método helper `_buscarVendaAtualizada(String vendaId)`

### 2. Lógica de Loading Similar
**Localizações**:
- `BalcaoScreen` usa `_isChecking` e `_hasVendaPendente`
- `BalcaoPaymentHelper` usa `_LoadingOverlay`
- `NovoPedidoRestauranteScreen._finalizarPedidoBalcao()` usa `showDialog` com `H4ndLoading`

**Problema**: Três formas diferentes de mostrar loading

**Solução**: Unificar em um helper/service de loading

### 3. Construção de `produtosAgrupados`
**Localizações**:
- `NovoPedidoRestauranteScreen._finalizarPedidoBalcao()` (linha 1131)
- `BalcaoScreen._abrirPagamentoPendente()` usa lista vazia (linha 304)

**Problema**: Em `BalcaoScreen`, usa lista vazia porque não tem acesso ao `PedidoLocal`

**Solução**: Buscar pedido da venda para construir `produtosAgrupados` corretamente

### 4. Tratamento de Erros Similar
**Padrão Repetido**:
```dart
if (!vendaResponse.success || vendaResponse.data == null) {
  await VendaBalcaoPendenteService.limparVendaPendente();
  if (mounted) {
    setState(() {
      _isChecking = false;
      _hasVendaPendente = false;
    });
  }
  return;
}
```

**Solução**: Extrair para método `_tratarErroBuscaVenda()`

### 5. Verificação de Venda Pendente
**Localizações**:
- `BalcaoScreen._verificarVendaPendente()` (linha 245)
- `NovoPedidoRestauranteScreen.initState()` (linha 93)

**Código Similar**:
```dart
final vendaIdPendente = VendaBalcaoPendenteService.obterVendaPendente();
if (vendaIdPendente != null) {
  // Ação diferente em cada lugar
}
```

---

## ⚠️ Problemas Identificados

### 1. **Estados de Loading Conflitantes**
- `_isChecking` e `_hasVendaPendente` têm propósitos similares
- Pode causar confusão sobre qual usar
- **Impacto**: Código difícil de manter

### 2. **Delay Artificial no Loading**
```dart
await Future.delayed(const Duration(milliseconds: 50));
```
- **Problema**: Delay fixo não garante que o loading apareça
- **Solução**: Usar `WidgetsBinding.instance.endOfFrame` ou remover delay

### 3. **Lista Vazia de `produtosAgrupados`**
- Em `BalcaoScreen._abrirPagamentoPendente()`, usa lista vazia
- Tela de pagamento pode não mostrar produtos corretamente
- **Solução**: Buscar pedido da venda para construir lista correta

### 4. **Duplicação de Lógica de Busca**
- Busca de venda repetida em 3 lugares
- Sem tratamento de erro unificado
- **Solução**: Extrair para método reutilizável

### 5. **Verificação de Navegação Complexa**
- `_ultimoIndiceVerificado` e `_onNavigationIndexChanged()` têm lógica complexa
- Pode não detectar todas as navegações corretamente
- **Solução**: Simplificar ou usar `AutomaticKeepAliveClientMixin`

### 6. **Falta de Loading Durante Busca no Helper**
- `BalcaoPaymentHelper` mostra loading apenas em alguns casos
- Durante pagamento parcial, pode não mostrar loading
- **Solução**: Garantir loading em todas as buscas

### 7. **Key de Reconstrução Pode Não Funcionar**
- `_pedidoScreenKey` incrementado apenas quando não há venda pendente
- Pode não forçar reconstrução quando necessário
- **Solução**: Usar timestamp ou outro mecanismo mais confiável

---

## 🔧 Sugestões de Refatoração

### 1. Criar `BalcaoVendaService`
**Responsabilidades**:
- Buscar venda atualizada
- Construir `produtosAgrupados` a partir da venda
- Gerenciar estados de loading
- Tratar erros de busca

**Benefícios**:
- Elimina duplicação
- Centraliza lógica
- Facilita testes

### 2. Unificar Estados de Loading
**Proposta**:
```dart
enum BalcaoLoadingState {
  idle,           // Sem loading
  verificando,    // Verificando venda pendente
  buscandoVenda,  // Buscando dados da venda
  abrindoPagamento, // Abrindo tela de pagamento
}
```

**Benefícios**:
- Estado único e claro
- Fácil de debugar
- Evita conflitos

### 3. Extrair Lógica de Verificação
**Criar**: `BalcaoVerificationService`
- Verifica venda pendente
- Retorna resultado estruturado
- Usado por `BalcaoScreen` e `NovoPedidoRestauranteScreen`

### 4. Simplificar `BalcaoPaymentHelper`
**Problemas Atuais**:
- Método muito longo (160 linhas)
- Lógica complexa de loop
- Múltiplas responsabilidades

**Solução**: Dividir em métodos menores:
- `_processarResultadoPagamento()`
- `_tratarPagamentoParcial()`
- `_tratarFechamentoSemFinalizar()`
- `_buscarVendaEAtualizar()`

### 5. Melhorar Construção de `produtosAgrupados`
**Problema**: Lista vazia em `BalcaoScreen`

**Solução**:
```dart
Future<List<ProdutoAgrupado>> _construirProdutosAgrupadosDaVenda(
  String vendaId
) async {
  // Buscar pedido da venda
  // Construir lista de produtos agrupados
  // Retornar lista completa
}
```

### 6. Usar `ValueNotifier` para Estados
**Proposta**: Substituir múltiplos `setState()` por `ValueNotifier`
- `_loadingStateNotifier`
- `_vendaPendenteNotifier`

**Benefícios**:
- Reatividade automática
- Menos `setState()` manuais
- Código mais limpo

### 7. Extrair Constantes
**Problema**: Valores mágicos no código
- `0.01` (threshold de saldo)
- `50` (delay em ms)
- Mensagens hardcoded

**Solução**: Criar classe `BalcaoConstants`

### 8. Melhorar Tratamento de Erros
**Proposta**: Criar `BalcaoErrorHandler`
- Trata erros de busca de venda
- Trata erros de criação de pedido
- Mostra mensagens apropriadas
- Limpa estados corretamente

---

## 📊 Métricas de Código

### Complexidade
- `BalcaoPaymentHelper.abrirPagamentoComConfirmacao()`: **Alta** (loop complexo, múltiplas condições)
- `BalcaoScreen._abrirPagamentoPendente()`: **Média**
- `NovoPedidoRestauranteScreen._finalizarPedidoBalcao()`: **Média**

### Duplicação
- **3 locais** com busca de venda similar
- **2 locais** com verificação de venda pendente
- **3 formas diferentes** de mostrar loading

### Linhas de Código
- `balcao_screen.dart`: ~394 linhas
- `novo_pedido_restaurante_screen.dart`: ~1257 linhas (apenas ~100 relacionadas a balcão)
- `BalcaoPaymentHelper`: ~160 linhas (método único)

---

## ✅ Checklist de Melhorias

- [ ] Extrair busca de venda para método reutilizável
- [ ] Unificar estados de loading
- [ ] Criar `BalcaoVendaService` para lógica centralizada
- [ ] Melhorar construção de `produtosAgrupados`
- [ ] Simplificar `BalcaoPaymentHelper` (dividir em métodos menores)
- [ ] Extrair constantes (valores mágicos)
- [ ] Melhorar tratamento de erros
- [ ] Adicionar testes unitários
- [ ] Documentar fluxos complexos
- [ ] Remover delay artificial de loading

---

## 🎯 Prioridades

### Alta Prioridade
1. **Unificar busca de venda** - Elimina duplicação crítica
2. **Melhorar construção de produtosAgrupados** - Corrige possível bug
3. **Simplificar estados de loading** - Melhora manutenibilidade

### Média Prioridade
4. **Criar BalcaoVendaService** - Refatoração arquitetural
5. **Dividir BalcaoPaymentHelper** - Melhora legibilidade
6. **Melhorar tratamento de erros** - Robustez

### Baixa Prioridade
7. **Extrair constantes** - Organização
8. **Usar ValueNotifier** - Otimização
9. **Adicionar testes** - Qualidade

---

## 📝 Conclusão

O código da venda balcão está **funcional**, mas apresenta oportunidades de melhoria:

1. **Duplicação**: Busca de venda repetida em 3 lugares
2. **Complexidade**: `BalcaoPaymentHelper` muito longo
3. **Estados**: Múltiplos flags com propósitos similares
4. **Loading**: Três formas diferentes de mostrar

**Recomendação**: Priorizar refatoração da busca de venda e unificação de estados de loading, pois são as melhorias com maior impacto e menor risco.

