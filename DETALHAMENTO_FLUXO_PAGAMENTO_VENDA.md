# 📋 Detalhamento Completo: Como Funciona Pagamento e Conclusão de Venda HOJE

## 🎯 Visão Geral

O sistema atual tem **2 fluxos principais** para pagamento e conclusão de venda:

1. **Fluxo de Pagamento** → Processa pagamento parcial/total
2. **Fluxo de Finalização** → Conclui venda e emite nota fiscal

Ambos estão **misturados com a UI**, sem provider dedicado.

---

## 🔄 FLUXO 1: Processamento de Pagamento

### 📍 Localização
- **Tela:** `detalhes_produtos_mesa_screen.dart`
- **Método:** `_abrirTelaPagamento()` (linhas 483-534)
- **Tela de Pagamento:** `pagamento_restaurante_screen.dart`
- **Método Principal:** `_processarPagamento()` (linhas 187-366)

### 📊 Fluxo Passo a Passo

#### **Etapa 1: Usuário clica em "Pagar"**
```dart
// detalhes_produtos_mesa_screen.dart:300
onPagar: _abrirTelaPagamento,
```

#### **Etapa 2: Validações Iniciais** (`_abrirTelaPagamento`)
```dart
1. Busca venda usando _getVendaParaAcao()
   └─> Chama _provider.getVendaParaAcao()
       └─> Se controle por comanda:
           └─> Retorna venda da comanda selecionada (_vendasPorComanda[_abaSelecionada])
           └─> Senão: Retorna _vendaAtual
   
2. Se venda == null:
   └─> Tenta buscar venda aberta: _buscarVendaAberta()
       └─> Chama _provider.buscarVendaAberta()
           └─> Usa vendaService.getVendaAbertaPorComanda()
   
3. Valida se há produtos: _getProdutosParaAcao()
   └─> Retorna produtos da comanda selecionada ou visão geral
   
4. Valida configuração:
   └─> Se controle por comanda E está na visão geral:
       └─> BLOQUEIA com erro: "Selecione uma comanda específica"
```

#### **Etapa 3: Abre Tela de Pagamento**
```dart
PagamentoRestauranteScreen.show(
  context,
  venda: venda,
  produtosAgrupados: produtos,
  onPaymentSuccess: () {
    // CALLBACK: Recarrega dados após pagamento
    _provider.loadVendaAtual();
    _provider.loadProdutos(refresh: true);
  },
);
```

**Adaptação de Layout:**
- **Mobile:** Tela cheia (Navigator.push)
- **Desktop/Tablet:** Modal (showDialog)

#### **Etapa 4: Inicialização da Tela de Pagamento**
```dart
// pagamento_restaurante_screen.dart:100-131
initState() {
  _initializePayment();
  _valorController.text = widget.venda.saldoRestante.toStringAsFixed(2);
}

_initializePayment() {
  1. Carrega PaymentService.getInstance()
  2. Busca métodos disponíveis: _paymentService.getAvailablePaymentMethods()
     └─> Retorna: Dinheiro, Cartão (Stone POS), PIX (DeepLink)
  3. Seleciona primeiro método por padrão
  4. Atualiza estado: _isLoading = false
}
```

**Estado Inicial:**
- `_isLoading = false`
- `_isProcessing = false`
- `_selectedMethod = primeiro método disponível`
- `_valorController = saldoRestante da venda`
- `_emitirNotaParcial = false`
- `_produtosSelecionados = {}`

#### **Etapa 5: Usuário Seleciona Forma de Pagamento**
```dart
// Opções disponíveis:
- Dinheiro (Cash)
- Cartão (Stone POS SDK)
- PIX (DeepLink)
```

#### **Etapa 6: Usuário Pode Selecionar "Emitir Nota Parcial"**
```dart
// Se _emitirNotaParcial = true:
1. Permite selecionar produtos específicos
2. Calcula valor dos produtos selecionados
3. Atualiza campo de valor automaticamente
```

#### **Etapa 7: Usuário Clica em "Processar Pagamento"**
```dart
// _processarPagamento() - linhas 187-366
```

**7.1 Validações:**
```dart
1. Verifica se método foi selecionado
   └─> Se não: Erro "Selecione uma forma de pagamento"

2. Se emitirNotaParcial:
   └─> Valida se há produtos selecionados
   └─> Valida se valor digitado corresponde aos produtos
   └─> Se diferente: Mostra confirmação

3. Se modo normal:
   └─> Valida valor digitado > 0
   └─> Valida valor <= saldoRestante
   └─> Se maior: Mostra confirmação
```

**7.2 Processamento:**
```dart
setState(() {
  _isProcessing = true; // Bloqueia UI
});

// Determina provider e dados adicionais
String providerKey = 'cash';
Map<String, dynamic>? additionalData;

if (_selectedMethod!.type == PaymentType.cash) {
  providerKey = 'cash';
  additionalData = {'valorRecebido': valor};
  
} else if (_selectedMethod!.type == PaymentType.pos) {
  providerKey = 'stone_pos';
  additionalData = {
    'tipoTransacao': 'credit',
    'parcelas': 1,
    'imprimirRecibo': false,
  };
  // Mostra diálogo "Aguardando cartão..."
  
} else if (_selectedMethod!.type == PaymentType.deepLink) {
  providerKey = _selectedMethod!.providerKey; // 'pix'
  additionalData = {'tipo': 'pix'};
}
```

**7.3 Chama PaymentService:**
```dart
final result = await _paymentService!.processPayment(
  providerKey: providerKey,
  amount: valor,
  vendaId: widget.venda.id,
  additionalData: additionalData,
);
```

**O que acontece no PaymentService:**
- **Cash:** Retorna sucesso imediatamente
- **Stone POS:** Abre SDK, processa transação, retorna resultado
- **PIX:** Gera QR Code, retorna com `metadata['pending'] = true`

**7.4 Registra Pagamento no Servidor:**
```dart
// Se NÃO for deeplink pendente:
if (providerKey == 'cash' || providerKey == 'stone_pos' || !(result.metadata?['pending'] == true)) {
  
  // Prepara produtos para nota fiscal (se nota parcial)
  List<Map<String, dynamic>>? produtosParaNota;
  if (_emitirNotaParcial && _temProdutosSelecionados) {
    produtosParaNota = _produtosSelecionados.entries
        .where((e) => e.value > 0)
        .map((e) => ProdutoNotaFiscalDto(
              produtoId: e.key,
              quantidade: e.value,
            ).toJson())
        .toList();
  }
  
  // Chama API
  final response = await _vendaService.registrarPagamento(
    vendaId: widget.venda.id,
    valor: valor,
    formaPagamento: _selectedMethod!.label,
    tipoFormaPagamento: tipoFormaPagamento, // 1 = Dinheiro, 2 = Cartão
    bandeiraCartao: bandeiraCartao, // Se Stone POS
    identificadorTransacao: identificadorTransacao, // Se Stone POS
    produtos: produtosParaNota, // Se nota parcial
  );
}
```

**API Call:**
```
POST /api/vendas/{vendaId}/pagamentos
Body: {
  valor: 100.00,
  formaPagamento: "Dinheiro",
  tipoFormaPagamento: 1,
  produtos: [...] // Se nota parcial
}
```

**7.5 Após Sucesso:**
```dart
if (response.success) {
  AppToast.showSuccess(context, 'Pagamento realizado com sucesso!');
  
  // Limpa seleção de produtos
  _produtosSelecionados.clear();
  
  // Chama callback
  if (widget.onPaymentSuccess != null) {
    widget.onPaymentSuccess!(); // ← Recarrega dados na tela anterior
  }
  
  // Verifica se saldo zerou
  final vendaAtualizada = await _vendaService.getVendaById(widget.venda.id);
  final novoSaldo = vendaAtualizada.data!.saldoRestante;
  
  if (novoSaldo <= 0.01) {
    // Saldo zerou → Oferece conclusão
    _oferecerConclusaoVenda();
  } else {
    Navigator.of(context).pop(true); // Volta para tela anterior
  }
}
```

**7.6 Se Saldo Zerou:**
```dart
_oferecerConclusaoVenda() {
  1. Mostra diálogo de confirmação:
     "O saldo foi totalmente pago. Deseja concluir a venda?"
  
  2. Se confirmar:
     └─> Chama _concluirVenda() (ver Fluxo 2)
  
  3. Se cancelar:
     └─> Navigator.pop(true) // Volta sem concluir
}
```

#### **Etapa 8: Retorno para Tela de Detalhes**
```dart
// detalhes_produtos_mesa_screen.dart:525-533
if (result == true) {
  // Pagamento realizado com sucesso
  _provider.loadVendaAtual();      // ← Recarrega venda
  _provider.loadProdutos(refresh: true); // ← Recarrega produtos
  
  // NOTA: Comandas são recarregadas automaticamente dentro de loadProdutos()
}
```

**O que acontece:**
1. `loadVendaAtual()` → Busca venda atualizada do servidor
2. `loadProdutos(refresh: true)` → Busca produtos atualizados
3. Provider atualiza estado interno
4. `notifyListeners()` → UI atualiza automaticamente

---

## 🔄 FLUXO 2: Finalização de Venda

### 📍 Localização
- **Tela:** `detalhes_produtos_mesa_screen.dart`
- **Método:** `_finalizarVenda()` (linhas 537-627)
- **Alternativa:** `pagamento_restaurante_screen.dart::_concluirVenda()` (linhas 389-424)

### 📊 Fluxo Passo a Passo

#### **Etapa 1: Usuário clica em "Finalizar"**
```dart
// detalhes_produtos_mesa_screen.dart:301
onFinalizar: _finalizarVenda,
```

#### **Etapa 2: Validações Iniciais** (`_finalizarVenda`)
```dart
1. Busca venda: _getVendaParaAcao()
   └─> Mesma lógica do fluxo de pagamento
   
2. Se venda == null:
   └─> Tenta buscar: _buscarVendaAberta()
   
3. Valida configuração:
   └─> Se controle por comanda E visão geral:
       └─> BLOQUEIA: "Selecione uma comanda específica"
```

#### **Etapa 3: Confirmação**
```dart
final confirmar = await AppDialog.showConfirm(
  context: context,
  title: 'Finalizar Venda',
  message: 'Deseja finalizar esta venda? A nota fiscal será emitida automaticamente se necessário.',
  confirmText: 'Finalizar',
  cancelText: 'Cancelar',
);

if (confirmar != true) return; // Cancela se não confirmar
```

#### **Etapa 4: Mostra Loading**
```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => const Center(child: CircularProgressIndicator()),
);
```

#### **Etapa 5: Chama API**
```dart
try {
  final response = await _servicesProvider.vendaService.concluirVenda(venda!.id);
```

**API Call:**
```
POST /api/vendas/{vendaId}/concluir
Body: {}
```

**O que acontece no backend:**
1. Valida se venda pode ser concluída
2. Emite nota fiscal final (se necessário)
3. Atualiza status da venda para "Concluída"
4. Libera mesa/comanda (se aplicável)
5. Retorna venda atualizada

#### **Etapa 6: Tratamento de Resposta**
```dart
if (response.success && response.data != null) {
  // SUCESSO
  AppToast.showSuccess(context, 'Venda finalizada com sucesso!');
  
  // Dispara evento manualmente
  if (widget.entidade.tipo == TipoEntidade.mesa) {
    AppEventBus.instance.dispararVendaFinalizada(
      vendaId: venda!.id,
      mesaId: widget.entidade.id,
      comandaId: null,
    );
  } else if (widget.entidade.tipo == TipoEntidade.comanda) {
    if (venda!.mesaId != null) {
      AppEventBus.instance.dispararVendaFinalizada(
        vendaId: venda.id,
        mesaId: venda.mesaId!,
        comandaId: widget.entidade.id,
      );
    }
  }
  
  // Recarrega dados manualmente
  _provider.loadVendaAtual();
  _provider.loadProdutos(refresh: true);
  
} else {
  // ERRO
  AppToast.showError(context, response.message ?? 'Erro ao finalizar venda');
}
```

#### **Etapa 7: Evento é Escutado**
```dart
// mesa_detalhes_provider.dart:253-263
eventBus.on(TipoEvento.vendaFinalizada).listen((evento) {
  if (_eventoPertenceAEstaEntidade(evento)) {
    debugPrint('📢 Venda ${evento.vendaId} finalizada');
    
    // Recarrega venda e produtos
    loadVendaAtual();
    loadProdutos(refresh: true);
    
    // Atualiza status da mesa
    _atualizarStatusMesa();
  }
});
```

**O que acontece:**
1. Provider escuta evento
2. Verifica se evento pertence à entidade atual
3. Recarrega dados automaticamente
4. Atualiza status da mesa
5. `notifyListeners()` → UI atualiza

#### **Etapa 8: Outros Providers Escutam**
```dart
// mesas_provider.dart:201
eventBus.on(TipoEvento.vendaFinalizada).listen((evento) {
  // Atualiza lista de mesas
  // Atualiza status da mesa na lista
});
```

---

## 🔄 FLUXO ALTERNATIVO: Conclusão após Pagamento

### 📍 Localização
- **Tela:** `pagamento_restaurante_screen.dart`
- **Método:** `_concluirVenda()` (linhas 389-424)

### Quando é Chamado:
- Após pagamento quando saldo zera (`_oferecerConclusaoVenda()`)
- Usuário confirma conclusão

### Diferenças do Fluxo Principal:
```dart
// Mais simples, sem validações extras
_concluirVenda() {
  1. setState(_isProcessing = true)
  
  2. Chama API: vendaService.concluirVenda(widget.venda.id)
  
  3. Se sucesso:
     └─> AppToast.showSuccess()
     └─> Dispara evento vendaFinalizada
     └─> Chama callback onPaymentSuccess
     └─> Navigator.pop(true)
  
  4. Se erro:
     └─> AppToast.showError()
  
  5. finally:
     └─> setState(_isProcessing = false)
}
```

**Problema:** Código duplicado com `_finalizarVenda()`

---

## 📊 Diagrama de Fluxo Completo

```
┌─────────────────────────────────────────────────────────────┐
│                    TELA DE DETALHES                         │
│              (detalhes_produtos_mesa_screen)                │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Usuário clica "Pagar"
                            ▼
        ┌───────────────────────────────────────┐
        │   _abrirTelaPagamento()                │
        │   1. Valida venda                      │
        │   2. Valida produtos                   │
        │   3. Valida configuração               │
        └───────────────────────────────────────┘
                            │
                            │ Abre tela
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              TELA DE PAGAMENTO                               │
│         (pagamento_restaurante_screen)                       │
│                                                              │
│  Estado:                                                     │
│  - _isLoading: false                                         │
│  - _isProcessing: false                                      │
│  - _selectedMethod: PaymentMethodOption                      │
│  - _valorController: saldoRestante                          │
│  - _emitirNotaParcial: false                                 │
│  - _produtosSelecionados: {}                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Usuário processa pagamento
                            ▼
        ┌───────────────────────────────────────┐
        │   _processarPagamento()                │
        │   1. Valida método                     │
        │   2. Valida valor                      │
        │   3. Processa via PaymentService      │
        │   4. Registra no servidor             │
        │   5. Verifica saldo                    │
        └───────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        Saldo > 0              Saldo = 0
                │                       │
                │                       ▼
                │           ┌───────────────────────┐
                │           │ _oferecerConclusaoVenda│
                │           │ Mostra diálogo         │
                │           └───────────────────────┘
                │                       │
                │                       │ Usuário confirma
                │                       ▼
                │           ┌───────────────────────┐
                │           │   _concluirVenda()    │
                │           │   Chama API           │
                │           │   Dispara evento      │
                │           └───────────────────────┘
                │                       │
                └───────────┬───────────┘
                            │
                            │ Retorna true
                            ▼
        ┌───────────────────────────────────────┐
        │   Callback: onPaymentSuccess()       │
        │   _provider.loadVendaAtual()          │
        │   _provider.loadProdutos()            │
        └───────────────────────────────────────┘
                            │
                            │ Evento disparado
                            ▼
        ┌───────────────────────────────────────┐
        │   AppEventBus.vendaFinalizada         │
        └───────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼────────┐    ┌────────▼────────┐
        │ MesaDetalhes    │    │ MesasProvider   │
        │ Provider        │    │                 │
        │ Escuta evento   │    │ Escuta evento   │
        │ Recarrega dados │    │ Atualiza lista  │
        └─────────────────┘    └─────────────────┘
```

---

## 🔍 Pontos Críticos Identificados

### 1. **Estado Duplicado**
- `_isProcessing` na tela de pagamento
- `_isLoading` na tela de pagamento
- Não compartilhado com outras telas

### 2. **Lógica de Negócio na UI**
- Validações complexas na tela
- Cálculos na tela
- Chamadas de API na tela

### 3. **Recarregamento Manual**
- `_provider.loadVendaAtual()` chamado manualmente
- `_provider.loadProdutos()` chamado manualmente
- Deveria ser automático via eventos

### 4. **Eventos Manuais**
- Eventos disparados manualmente na UI
- Deveriam ser disparados automaticamente pelo provider

### 5. **Código Duplicado**
- `_finalizarVenda()` em detalhes_produtos_mesa_screen.dart
- `_concluirVenda()` em pagamento_restaurante_screen.dart
- Mesma lógica em dois lugares

### 6. **Callbacks Manuais**
- `onPaymentSuccess` callback manual
- Deveria ser automático via eventos

---

## 📝 Resumo dos Problemas

| Problema | Impacto | Solução Proposta |
|----------|---------|------------------|
| Lógica na UI | Difícil testar | Mover para Provider |
| Estado duplicado | Inconsistências | Centralizar no Provider |
| Recarregamento manual | Fácil esquecer | Automatizar via eventos |
| Eventos manuais | Fácil esquecer | Automatizar no Provider |
| Código duplicado | Manutenção difícil | Criar Provider único |
| Callbacks manuais | Acoplamento | Usar eventos |

---

## 🎯 Próximos Passos Sugeridos

1. **Criar `VendaProvider`** com toda lógica de pagamento/conclusão
2. **Migrar métodos** das telas para o provider
3. **Automatizar eventos** - provider dispara automaticamente
4. **Automatizar recarregamento** - providers escutam eventos
5. **Remover callbacks** - usar eventos em vez de callbacks
6. **Testar fluxo completo** após migração

---

**Documento criado para análise detalhada do fluxo atual! 🚀**
