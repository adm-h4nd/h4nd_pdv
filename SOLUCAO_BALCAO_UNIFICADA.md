# Solução Unificada: Balcão + Pedidos Restaurante

## 🎯 Objetivo

Criar uma solução unificada que:
- **Reutiliza a mesma tela** (`NovoPedidoRestauranteScreen`)
- **Modifica a lógica de finalização** para ser inteligente
- **Evita duplicação de código**
- **Mantém compatibilidade** com o fluxo atual

## 📋 Estratégia

### 1. Modificar `PedidoProvider.finalizarPedido()`

Adicionar parâmetros opcionais para controlar o comportamento:

```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool requerConexao = false,  // Se true, verifica conexão antes
  bool modoBalcao = false,     // Se true, sempre exige conexão e não salva no Hive
  bool tentarEnviarDireto = false, // Se true, tenta API primeiro
}) async
```

### 2. Lógica Unificada

```
┌─────────────────────────────────────┐
│ finalizarPedido()                   │
└─────────────────────────────────────┘
           │
           ├─ Se modoBalcao == true
           │   ├─ Verifica conexão (obrigatório)
           │   ├─ Se offline: ERRO (não permite)
           │   └─ Se online: Envia direto para API
           │
           ├─ Se requerConexao == true (mas não é balcão)
           │   ├─ Verifica conexão
           │   ├─ Se offline: Salva no Hive (fallback)
           │   └─ Se online: Tenta API primeiro, Hive se falhar
           │
           └─ Se nenhum flag (comportamento atual)
               └─ Salva no Hive (AutoSync sincroniza depois)
```

### 3. Modificar `NovoPedidoRestauranteScreen`

Adicionar parâmetro `modoBalcao`:

```dart
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId;
  final String? comandaId;
  final bool modoBalcao; // NOVO
  
  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.modoBalcao = false, // Padrão: false (comportamento atual)
  });
}
```

### 4. Comportamento do Botão "Finalizar"

```dart
// Na tela
Future<void> _finalizarPedido(BuildContext context) async {
  final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
  
  if (widget.modoBalcao) {
    // Modo balcão: finaliza e vai direto para pagamento
    final resultado = await pedidoProvider.finalizarPedido(
      requerConexao: true,
      modoBalcao: true,
      tentarEnviarDireto: true,
    );
    
    if (resultado.sucesso) {
      // Abre tela de pagamento automaticamente
      // Após pagamento, finaliza venda automaticamente
    } else {
      // Mostra erro (ex: "Balcão requer conexão")
    }
  } else {
    // Modo normal: comportamento atual
    final resultado = await pedidoProvider.finalizarPedido();
    // Salva no Hive, AutoSync sincroniza depois
  }
}
```

## 🔧 Implementação

### Passo 1: Criar `FinalizarPedidoResult`

```dart
// lib/data/models/local/finalizar_pedido_result.dart
class FinalizarPedidoResult {
  final bool sucesso;
  final String? pedidoId; // ID do pedido criado (local ou remoto)
  final String? pedidoRemoteId; // ID remoto se foi enviado direto
  final String? vendaId; // ID da venda criada (se modo balcão)
  final String? erro;
  final bool foiSalvoNoHive;
  final bool foiEnviadoDireto;

  FinalizarPedidoResult({
    required this.sucesso,
    this.pedidoId,
    this.pedidoRemoteId,
    this.vendaId,
    this.erro,
    this.foiSalvoNoHive = false,
    this.foiEnviadoDireto = false,
  });
}
```

### Passo 2: Modificar `PedidoProvider.finalizarPedido()`

```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool requerConexao = false,
  bool modoBalcao = false,
  bool tentarEnviarDireto = false,
}) async {
  if (_pedidoAtual == null || _pedidoAtual!.itens.isEmpty) {
    return FinalizarPedidoResult(
      sucesso: false,
      erro: 'Pedido vazio',
    );
  }

  try {
    // 1. Verificar conexão se necessário
    if (modoBalcao || requerConexao) {
      final healthCheck = await HealthCheckService.checkHealth(
        // URL do servidor
      );
      
      if (!healthCheck.success) {
        if (modoBalcao) {
          // Modo balcão: não permite offline
          return FinalizarPedidoResult(
            sucesso: false,
            erro: 'Balcão requer conexão com o servidor. Verifique sua internet.',
          );
        }
        // Modo normal com requerConexao: fallback para Hive
        // Continua para salvar no Hive
      }
    }

    // 2. Tentar enviar direto para API se solicitado e online
    if (tentarEnviarDireto || modoBalcao) {
      try {
        final pedidoDto = await _converterParaDto(_pedidoAtual!);
        final response = await _pedidoService.createPedido(pedidoDto);
        
        if (response.success && response.data != null) {
          // Sucesso: pedido criado na API
          final pedidoId = _pedidoAtual!.id;
          final remoteId = response.data!['id'] as String?;
          
          // Se modo balcão, retornar vendaId também
          String? vendaId;
          if (modoBalcao && response.data!['vendaId'] != null) {
            vendaId = response.data!['vendaId'] as String?;
          }
          
          // Limpa pedido atual
          _inicializarPedido(
            mesaId: _pedidoAtual!.mesaId,
            comandaId: _pedidoAtual!.comandaId,
          );
          notifyListeners();
          
          return FinalizarPedidoResult(
            sucesso: true,
            pedidoId: pedidoId,
            pedidoRemoteId: remoteId,
            vendaId: vendaId,
            foiEnviadoDireto: true,
          );
        }
      } catch (e) {
        // Erro ao enviar: se modo balcão, falha
        if (modoBalcao) {
          return FinalizarPedidoResult(
            sucesso: false,
            erro: 'Erro ao enviar pedido: ${e.toString()}',
          );
        }
        // Modo normal: continua para salvar no Hive
      }
    }

    // 3. Fallback: salvar no Hive (comportamento atual)
    if (!modoBalcao) {
      _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
      _pedidoAtual!.syncAttempts = 0;
      _pedidoAtual!.dataAtualizacao = DateTime.now();
      
      await _pedidoRepo.upsert(_pedidoAtual!);
      
      final pedidoIdSalvo = _pedidoAtual!.id;
      final mesaId = _pedidoAtual!.mesaId;
      final comandaId = _pedidoAtual!.comandaId;
      
      _inicializarPedido(
        mesaId: mesaId,
        comandaId: comandaId,
      );
      notifyListeners();
      
      return FinalizarPedidoResult(
        sucesso: true,
        pedidoId: pedidoIdSalvo,
        foiSalvoNoHive: true,
      );
    }

    // Não deveria chegar aqui
    return FinalizarPedidoResult(
      sucesso: false,
      erro: 'Erro desconhecido',
    );
  } catch (e) {
    return FinalizarPedidoResult(
      sucesso: false,
      erro: e.toString(),
    );
  }
}
```

### Passo 3: Criar Widget na Home para Balcão

```dart
// lib/data/models/home/home_widget_type.dart
enum HomeWidgetType {
  // ... existentes
  balcao, // NOVO
}
```

### Passo 4: Modificar `NovoPedidoRestauranteScreen`

```dart
// No método _finalizarPedido
Future<void> _finalizarPedido(BuildContext context) async {
  final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
  
  if (pedidoProvider.isEmpty) {
    // ... erro
    return;
  }

  showDialog(/* loading */);

  try {
    if (widget.modoBalcao) {
      // MODO BALCÃO
      final resultado = await pedidoProvider.finalizarPedido(
        requerConexao: true,
        modoBalcao: true,
        tentarEnviarDireto: true,
      );

      Navigator.of(context, rootNavigator: true).pop(); // Fecha loading

      if (resultado.sucesso && resultado.vendaId != null) {
        // Buscar venda criada
        final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
        final vendaResponse = await servicesProvider.vendaService.getVendaById(resultado.vendaId!);
        
        if (vendaResponse.success && vendaResponse.data != null) {
          // Abre tela de pagamento
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => AdaptiveLayout(
                child: PagamentoScreen(
                  venda: vendaResponse.data!,
                  onPaymentSuccess: () async {
                    // Após pagamento, finalizar venda automaticamente
                    final vendaProvider = Provider.of<VendaProvider>(context, listen: false);
                    await vendaProvider.finalizarVenda(
                      vendaId: resultado.vendaId!,
                    );
                    
                    // Volta para home
                    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ),
          );
        }
      } else {
        // Mostra erro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado.erro ?? 'Erro ao finalizar pedido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // MODO NORMAL (comportamento atual)
      final resultado = await pedidoProvider.finalizarPedido();
      
      Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
      
      if (resultado.sucesso) {
        // Mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido finalizado! Sincronizando...'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Volta para tela anterior
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      }
    }
  } catch (e) {
    // ... tratamento de erro
  }
}
```

## ✅ Vantagens

1. **Zero duplicação**: Reutiliza a mesma tela
2. **Lógica unificada**: Um único método inteligente
3. **Compatibilidade**: Comportamento atual preservado
4. **Flexível**: Fácil adicionar novos modos no futuro
5. **Manutenível**: Mudanças em um lugar só

## 🎯 Fluxo Completo

### Modo Normal (Restaurante/Mesa)
1. Usuário seleciona produtos
2. Clica "Finalizar Pedido"
3. Salva no Hive
4. AutoSync sincroniza quando tiver conexão

### Modo Balcão
1. Usuário seleciona produtos
2. Clica "Finalizar e Pagar"
3. Verifica conexão (obrigatório)
4. Envia direto para API
5. Abre tela de pagamento automaticamente
6. Após pagamento, finaliza venda automaticamente
7. Volta para home

## 📝 Próximos Passos

1. ✅ Criar `FinalizarPedidoResult`
2. ✅ Modificar `PedidoProvider.finalizarPedido()`
3. ✅ Adicionar `modoBalcao` em `NovoPedidoRestauranteScreen`
4. ✅ Criar widget "Balcão" na home
5. ✅ Implementar fluxo de pagamento automático no modo balcão

