# Solução Simplificada: Modo Balcão

## 🎯 Entendimento Correto

### Diferença entre Venda Mesa e Venda Balcão

**Venda Mesa:**
- Cria pedido → fecha tela e finaliza
- Pode funcionar offline (salva no Hive)

**Venda Balcão:**
- Cria pedido → **abre tela de pagamento**
- **Sempre precisa de conexão** (não funciona offline)

### O que acontece quando cria pedido

1. Backend cria o pedido
2. Backend cria a venda automaticamente
3. Backend retorna `PedidoDto` com `vendaId`
4. Frontend recebe o `vendaId`

### Comportamento após criar pedido

**Se for venda mesa:**
- Fecha a tela
- Mostra mensagem de sucesso
- Pronto!

**Se for venda balcão:**
- Abre tela de pagamento (passando o `vendaId`)
- Após pagamento, finaliza a venda
- Fecha tudo

---

## 📝 PASSO 1: Adicionar Flag de Tipo de Venda na Tela

### O que fazer?
Adicionar um parâmetro `isVendaBalcao: bool` na tela `NovoPedidoRestauranteScreen`.

### Onde?
**Arquivo:** `lib/screens/pedidos/restaurante/novo_pedido_restaurante_screen.dart`

### Como?
```dart
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId;
  final String? comandaId;
  final bool isVendaBalcao;  // NOVO: true = balcão, false = mesa
  
  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.isVendaBalcao = false,  // Padrão: false (venda mesa)
  });
}
```

---

## 📝 PASSO 2: Modificar `PedidoProvider.finalizarPedido()`

### O que fazer?
Modificar para:
- Se tiver conexão → enviar para API (retorna `PedidoDto` com `vendaId`)
- Se não tiver conexão:
  - Se for balcão → ERRO (não permite offline)
  - Se for mesa → salvar no Hive (comportamento atual)

### Onde?
**Arquivo:** `lib/presentation/providers/pedido_provider.dart`
**Método:** `finalizarPedido()`

### Como?
```dart
Future<PedidoDto?> finalizarPedido({
  bool isVendaBalcao = false,  // NOVO: flag de tipo de venda
}) async {
  if (_pedidoAtual == null || _pedidoAtual!.itens.isEmpty) {
    return null;
  }

  // Verificar conexão
  final config = Environment.config;
  final healthCheck = await HealthCheckService.checkHealth(config.apiBaseUrl);
  final temConexao = healthCheck.success;
  
  // Se for balcão e não tiver conexão → ERRO
  if (isVendaBalcao && !temConexao) {
    throw Exception('Venda balcão requer conexão com o servidor.');
  }
  
  // Se tiver conexão → enviar para API
  if (temConexao) {
    try {
      // Converter pedido local para DTO
      final pedidoDto = await _converterParaDto(_pedidoAtual!);
      
      // Enviar para API
      final response = await _pedidoService.createPedido(pedidoDto);
      
      if (response.success && response.data != null) {
        // Parsear resposta para PedidoDto
        final pedidoData = response.data!;
        final pedidoDto = PedidoDto.fromJson(pedidoData);
        
        // Limpar pedido atual
        _inicializarPedido();
        notifyListeners();
        
        // Retornar PedidoDto com vendaId
        return pedidoDto;
      }
    } catch (e) {
      // Se for balcão, não permite fallback
      if (isVendaBalcao) {
        throw Exception('Erro ao enviar pedido: ${e.toString()}');
      }
      // Se for mesa, pode tentar Hive (continua código abaixo)
    }
  }
  
  // Se não tiver conexão E for mesa → salvar no Hive
  if (!temConexao && !isVendaBalcao) {
    _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
    await _pedidoRepo.upsert(_pedidoAtual!);
    
    final pedidoIdSalvo = _pedidoAtual!.id;
    _inicializarPedido();
    notifyListeners();
    
    // Retorna null porque foi salvo no Hive (não tem vendaId ainda)
    return null;
  }
  
  return null;
}
```

**OBS:** Precisa criar método `_converterParaDto()` que converte `PedidoLocal` para `Map<String, dynamic>` (igual ao que existe no `SyncService`).

---

## 📝 PASSO 3: Modificar `_finalizarPedido()` na Tela

### O que fazer?
Modificar o método `_finalizarPedido()` para:
- Chamar `finalizarPedido(isVendaBalcao: widget.isVendaBalcao)`
- Se retornar `PedidoDto` com `vendaId` E for balcão → abrir pagamento
- Se retornar `PedidoDto` E for mesa → fechar tela (comportamento atual)
- Se retornar `null` (foi para Hive) → fechar tela (comportamento atual)

### Onde?
**Arquivo:** `lib/screens/pedidos/restaurante/novo_pedido_restaurante_screen.dart`
**Método:** `_finalizarPedido()` (linha ~979)

### Como?
```dart
Future<void> _finalizarPedido(BuildContext context) async {
  final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
  
  if (pedidoProvider.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adicione pelo menos um item ao pedido')),
    );
    return;
  }

  // Mostrar loading
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => Center(child: H4ndLoading(size: 60)),
  );

  try {
    // Finalizar pedido
    final pedidoDto = await pedidoProvider.finalizarPedido(
      isVendaBalcao: widget.isVendaBalcao,  // Passar flag
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Fechar loading

    if (pedidoDto != null) {
      // Pedido foi criado na API
      
      if (widget.isVendaBalcao && pedidoDto.vendaId != null) {
        // VENDA BALCÃO: Abrir pagamento
        await _abrirPagamentoEfinalizar(context, pedidoDto.vendaId!);
      } else {
        // VENDA MESA: Fechar tela (comportamento atual)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido finalizado! Sincronizando...'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      }
    } else {
      // Foi salvo no Hive (só acontece em venda mesa offline)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido finalizado! Sincronizando...'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// NOVO: Método para abrir pagamento e finalizar venda
Future<void> _abrirPagamentoEfinalizar(BuildContext context, String vendaId) async {
  // 1. Buscar venda
  // 2. Abrir tela de pagamento
  // 3. Após pagamento concluído, finalizar venda
  // 4. Fechar tudo e voltar para home
}
```

---

## 📝 PASSO 4: Criar Widget "Balcão" na Home

### O que fazer?
Adicionar botão/card na tela inicial que abre `NovoPedidoRestauranteScreen` com `isVendaBalcao: true`.

### Onde?
**Arquivo:** `lib/screens/home/home_unified_screen.dart`

### Como?
```dart
// No switch/case dos widgets
case HomeWidgetType.balcao:
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => NovoPedidoRestauranteScreen(
        isVendaBalcao: true,  // IMPORTANTE: marca como venda balcão
      ),
    ),
  );
  break;
```

---

## 📋 Resumo Simplificado

1. **Adicionar flag `isVendaBalcao`** na tela
2. **Modificar `finalizarPedido()`** para:
   - Verificar conexão
   - Se balcão e offline → ERRO
   - Se online → enviar para API e retornar `PedidoDto` com `vendaId`
   - Se mesa e offline → salvar no Hive (retorna `null`)
3. **Modificar `_finalizarPedido()`** na tela para:
   - Se balcão e tem `vendaId` → abrir pagamento
   - Se mesa → fechar tela (comportamento atual)
4. **Criar widget "Balcão"** na home que abre com `isVendaBalcao: true`

---

## ✅ Vantagens desta Abordagem

- ✅ Mais simples: não precisa de `FinalizarPedidoResult`
- ✅ Usa `PedidoDto` que já existe e já tem `vendaId`
- ✅ Flag clara: `isVendaBalcao` (tipo de venda, não "permiteHive")
- ✅ Comportamento direto: balcão abre pagamento, mesa fecha tela

