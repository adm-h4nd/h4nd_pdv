# Fluxo Completo: Modo Balcão

## 📋 Entendendo o Fluxo Atual

### Relação Pedido ↔ Venda

```
┌─────────────┐
│   Pedido    │
│  (Order)    │
└──────┬──────┘
       │
       │ VendaId (FK)
       │
       ▼
┌─────────────┐
│    Venda    │
│   (Sale)    │
└─────────────┘
```

**Quando cria um Pedido:**
- Se tiver **Mesa**: Backend busca/cria Venda da mesa
- Se tiver **Comanda**: Backend busca/cria Venda da comanda  
- Se **não tiver nem mesa nem comanda**: Backend cria **Venda Avulsa**
- O Pedido fica **vinculado à Venda** através de `VendaId`

**Importante**: A Venda é criada **automaticamente** pelo backend quando cria o pedido!

### Fluxo de Pagamento

```
1. Registrar Pagamento
   └─ POST /api/vendas/{vendaId}/pagamentos
   └─ Adiciona pagamento à venda
   └─ NÃO finaliza a venda automaticamente
   └─ Venda continua com Status = "Aberta"

2. Concluir Venda (separado)
   └─ POST /api/vendas/{vendaId}/concluir
   └─ Valida que está totalmente paga
   └─ Marca Status = "Finalizada"
   └─ Libera mesa/comanda
   └─ Emite nota fiscal final (se necessário)
```

## 🎯 Fluxo do Modo Balcão

### Passo a Passo Detalhado

```
┌─────────────────────────────────────────────────────────┐
│ 1. Usuário seleciona produtos                           │
│    └─ PedidoProvider gerencia itens localmente         │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Usuário clica "Finalizar e Pagar"                   │
│    └─ Verifica conexão (obrigatório)                   │
│    └─ Se offline: ERRO (não permite)                   │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼ (Se online)
┌─────────────────────────────────────────────────────────┐
│ 3. Criar Pedido na API                                  │
│    └─ POST /api/pedidos                                 │
│    └─ Backend cria:                                     │
│       ├─ Pedido (com itens)                             │
│       └─ Venda Avulsa (automaticamente)                 │
│    └─ Retorna:                                          │
│       ├─ pedidoId                                       │
│       └─ vendaId (da venda avulsa criada)               │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Abrir Tela de Pagamento                              │
│    └─ Buscar venda completa: GET /api/vendas/{vendaId}  │
│    └─ Abrir PagamentoScreen com a venda                 │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Usuário confirma pagamento                           │
│    └─ Seleciona forma de pagamento                      │
│    └─ Processa via PaymentService (SDK, PIX, etc)      │
│    └─ Registra pagamento:                               │
│       └─ POST /api/vendas/{vendaId}/pagamentos          │
│    └─ Venda continua "Aberta" (não finaliza ainda)     │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Finalizar Venda Automaticamente                       │
│    └─ POST /api/vendas/{vendaId}/concluir               │
│    └─ Backend:                                           │
│       ├─ Valida que está totalmente paga                │
│       ├─ Marca Status = "Finalizada"                     │
│       ├─ Libera mesa/comanda (se houver)                 │
│       └─ Emite nota fiscal final (se necessário)        │
│    └─ NÃO pergunta confirmação (automático)             │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 7. Voltar para Home                                      │
│    └─ Venda finalizada com sucesso                      │
│    └─ Pronto para nova venda                            │
└─────────────────────────────────────────────────────────┘
```

## 💻 Implementação no Código

### 1. Modificar `PedidoProvider.finalizarPedido()`

```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool requerConexao = false,
  bool modoBalcao = false,
  bool tentarEnviarDireto = false,
}) async {
  // ... validações e verificação de conexão ...

  if (modoBalcao || tentarEnviarDireto) {
    // Converter pedido local para DTO
    final pedidoDto = await _converterParaDto(_pedidoAtual!);
    
    // Enviar para API
    final response = await _pedidoService.createPedido(pedidoDto);
    
    if (response.success && response.data != null) {
      final pedidoData = response.data!;
      
      // Extrair IDs
      final pedidoId = pedidoData['id'] as String?;
      final vendaId = pedidoData['vendaId'] as String?; // Backend retorna vendaId
      
      // Limpar pedido atual
      _inicializarPedido();
      notifyListeners();
      
      return FinalizarPedidoResult(
        sucesso: true,
        pedidoId: pedidoId,
        pedidoRemoteId: pedidoId,
        vendaId: vendaId, // IMPORTANTE: retornar vendaId
        foiEnviadoDireto: true,
      );
    }
  }
  
  // ... fallback para Hive se não for modo balcão ...
}
```

### 2. Modificar `NovoPedidoRestauranteScreen._finalizarPedido()`

```dart
Future<void> _finalizarPedido(BuildContext context) async {
  final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
  final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
  final vendaProvider = servicesProvider.vendaProvider;
  
  if (pedidoProvider.isEmpty) {
    // ... erro ...
    return;
  }

  showDialog(/* loading */);

  try {
    if (widget.modoBalcao) {
      // ========== MODO BALCÃO ==========
      
      // 1. Finalizar pedido (cria pedido + venda na API)
      final resultado = await pedidoProvider.finalizarPedido(
        requerConexao: true,
        modoBalcao: true,
        tentarEnviarDireto: true,
      );

      Navigator.of(context, rootNavigator: true).pop(); // Fecha loading

      if (!resultado.sucesso || resultado.vendaId == null) {
        // Erro ao criar pedido/venda
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado.erro ?? 'Erro ao finalizar pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Buscar venda criada
      final vendaResponse = await servicesProvider.vendaService.getVendaById(
        resultado.vendaId!,
      );

      if (!vendaResponse.success || vendaResponse.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao buscar venda criada'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final venda = vendaResponse.data!;

      // 3. Abrir tela de pagamento
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: PagamentoScreen(
              venda: venda,
              onPaymentSuccess: () async {
                // 4. Após pagamento confirmado, finalizar venda automaticamente
                final sucesso = await vendaProvider.finalizarVenda(
                  vendaId: resultado.vendaId!,
                );

                if (sucesso) {
                  // 5. Voltar para home
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).popUntil(
                      (route) => route.isFirst,
                    );
                    
                    // Mostrar mensagem de sucesso
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Venda finalizada com sucesso!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // Erro ao finalizar (mas pagamento foi registrado)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        vendaProvider.erroFinalizacao ?? 
                        'Pagamento registrado, mas erro ao finalizar venda'
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      );
    } else {
      // ========== MODO NORMAL (comportamento atual) ==========
      final resultado = await pedidoProvider.finalizarPedido();
      
      Navigator.of(context, rootNavigator: true).pop();
      
      if (resultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido finalizado! Sincronizando...'),
            backgroundColor: Colors.green,
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      }
    }
  } catch (e) {
    Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

## 🔍 Pontos Importantes

### 1. Como obter `vendaId`?

**Situação**: O `PedidoDto` retornado pelo backend **NÃO** tem campo `vendaId` diretamente.

**Solução**: Precisamos buscar o pedido criado para obter a venda:

```dart
// Após criar pedido
final pedidoResponse = await _pedidoService.createPedido(pedidoDto);

if (pedidoResponse.success && pedidoResponse.data != null) {
  final pedidoId = pedidoResponse.data!['id'] as String?;
  
  // Buscar pedido completo para obter vendaId
  final pedidoCompletoResponse = await _pedidoService.getPedidoById(pedidoId!);
  
  if (pedidoCompletoResponse.success && pedidoCompletoResponse.data != null) {
    // O pedido tem relação com Venda, mas não expõe vendaId diretamente
    // Precisamos buscar a venda através da mesa/comanda ou criar endpoint específico
    // 
    // ALTERNATIVA: Modificar backend para retornar vendaId no PedidoDto
    // OU: Buscar venda aberta por cliente (se for venda avulsa)
  }
}
```

**Melhor solução**: Modificar backend para incluir `vendaId` no `PedidoDto` ou criar endpoint que retorna pedido com vendaId.

**Solução temporária**: Para venda avulsa (balcão), podemos buscar a venda mais recente do cliente ou criar endpoint específico.

### 2. Pagamento pode ser parcial?

No modo balcão, assumimos que o pagamento é **sempre do valor total** da venda.

Se o usuário quiser pagar parcialmente:
- Mostrar erro: "Balcão requer pagamento total"
- Ou permitir múltiplos pagamentos até zerar

### 3. E se o pagamento falhar?

Se o pagamento via SDK/PIX falhar:
- Venda fica aberta (não foi finalizada)
- Pedido já foi criado na API
- Usuário pode tentar novamente ou cancelar

**Decisão**: O que fazer se pagamento falhar?
- Opção A: Cancelar pedido automaticamente
- Opção B: Manter pedido e permitir tentar novamente
- Opção C: Mostrar opção de "Cancelar venda"

## ✅ Resumo do Fluxo

```
1. Criar Pedido → API cria Pedido + Venda Avulsa
2. Abrir Pagamento → Tela de pagamento com a venda
3. Confirmar Pagamento → Registra pagamento na venda
4. Finalizar Venda → Conclui venda automaticamente (sem perguntar)
5. Voltar Home → Pronto para nova venda
```

**Tudo em sequência, sem perguntar confirmações intermediárias!**

