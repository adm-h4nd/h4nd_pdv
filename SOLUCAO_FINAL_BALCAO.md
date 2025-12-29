# Solução Final: Modo Balcão + Unificação

## 🎯 Conceito Principal

**Uma única lógica inteligente** que se adapta baseado em uma **flag de configuração**.

## 📋 Estrutura da Solução

### ✅ IMPORTANTE: Pagamento NÃO usa Hive
- Pagamento sempre vai direto para API
- Não precisa de flag `permiteHive` para pagamento
- A flag `permiteHive` só afeta a **criação do pedido**

### 1. Backend: Retornar `vendaId` no PedidoDto ✅ (IMPLEMENTAR AGORA)

**Modificar**: `PedidoDto` para incluir `vendaId`

```csharp
public class PedidoDto : PedidoListItemDto
{
    // ... campos existentes ...
    
    public Guid? VendaId { get; set; } // NOVO
}
```

**Modificar**: `MapToDtoAsync` para mapear `vendaId`

```csharp
var dto = new PedidoDto
{
    // ... campos existentes ...
    VendaId = pedido.VendaId, // NOVO
};
```

**Status**: ⏳ Pendente - Vamos implementar agora

### 2. Frontend: Flag `permiteHive` na Tela

```dart
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId;
  final String? comandaId;
  final bool permiteHive; // NOVO: controla se pode usar Hive
  
  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.permiteHive = true, // Padrão: permite (comportamento atual)
  });
}
```

### 3. Lógica Unificada no `PedidoProvider`

```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool permiteHive = true, // NOVO: flag de controle
}) async {
  // 1. Verificar conexão
  final healthCheck = await HealthCheckService.checkHealth(/* ... */);
  final temConexao = healthCheck.success;
  
  // 2. Decisão baseada em permiteHive e conexão
  if (!temConexao && !permiteHive) {
    // Modo balcão sem conexão: ERRO
    return FinalizarPedidoResult(
      sucesso: false,
      erro: 'Balcão requer conexão com o servidor. Verifique sua internet.',
    );
  }
  
  if (temConexao) {
    // SEMPRE tenta API primeiro se tiver conexão
    try {
      final pedidoDto = await _converterParaDto(_pedidoAtual!);
      final response = await _pedidoService.createPedido(pedidoDto);
      
      if (response.success && response.data != null) {
        final pedidoData = response.data!;
        final pedidoId = pedidoData['id'] as String?;
        final vendaId = pedidoData['vendaId'] as String?; // Backend retorna agora
        
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
    } catch (e) {
      // Se falhar e permiteHive, fallback para Hive
      if (permiteHive) {
        // Continua para salvar no Hive
      } else {
        // Modo balcão: não permite fallback
        return FinalizarPedidoResult(
          sucesso: false,
          erro: 'Erro ao enviar pedido: ${e.toString()}',
        );
      }
    }
  }
  
  // 3. Fallback: Salvar no Hive (só se permiteHive = true)
  if (permiteHive) {
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
}
```

## 🔄 Fluxos por Modo

### Modo Balcão (`permiteHive = false`)

```
┌─────────────────────────────────────┐
│ 1. Verifica conexão                 │
│    └─ Se offline: ERRO (não permite)│
│    └─ Se online: Continua           │
└─────────────────────────────────────┘
           │ (online)
           ▼
┌─────────────────────────────────────┐
│ 2. Envia para API                   │
│    POST /api/pedidos                │
│    └─ Retorna: pedidoId, vendaId    │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ 3. Abre Pagamento                   │
│    └─ Busca venda: GET /api/vendas/{vendaId}
│    └─ Abre PagamentoScreen          │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ 4. Processa Pagamento               │
│    └─ POST /api/vendas/{vendaId}/pagamentos
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ 5. Finaliza Venda                   │
│    POST /api/vendas/{vendaId}/concluir
└─────────────────────────────────────┘
```

### Modo Mesa (`permiteHive = true`)

```
┌─────────────────────────────────────┐
│ 1. Verifica conexão                 │
└─────────────────────────────────────┘
           │
           ├─ Se online
           │   └─ Envia para API (comportamento novo)
           │
           └─ Se offline
               └─ Salva no Hive (comportamento atual)
```

## 📝 Matriz de Decisão

| Conexão | permiteHive | Ação |
|---------|-------------|------|
| ✅ Online | ✅ true | Envia para API |
| ✅ Online | ❌ false | Envia para API |
| ❌ Offline | ✅ true | Salva no Hive |
| ❌ Offline | ❌ false | **ERRO** (não permite) |

## 🎯 Vantagens

1. **Unificação**: Uma única lógica para ambos os modos
2. **Flexibilidade**: Controla comportamento por tela
3. **Compatibilidade**: Mantém comportamento atual (permiteHive = true por padrão)
4. **Segurança**: Modo balcão sempre exige conexão
5. **Manutenibilidade**: Mudanças em um lugar só

## 🔧 Implementação

### Passo 1: Backend - Adicionar `vendaId` ao `PedidoDto`

```csharp
// MXCloud.Application/DTOs/Core/Vendas/PedidoDtos.cs
public class PedidoDto : PedidoListItemDto
{
    // ... campos existentes ...
    public Guid? VendaId { get; set; } // NOVO
}

// MXCloud.Application/Services/Core/Vendas/PedidoService.cs
public Task<PedidoDto> MapToDtoAsync(Pedido pedido)
{
    var dto = new PedidoDto
    {
        // ... campos existentes ...
        VendaId = pedido.VendaId, // NOVO
    };
    // ...
}
```

### Passo 2: Frontend - Criar `FinalizarPedidoResult`

```dart
// lib/data/models/local/finalizar_pedido_result.dart
class FinalizarPedidoResult {
  final bool sucesso;
  final String? pedidoId;
  final String? pedidoRemoteId;
  final String? vendaId; // IMPORTANTE
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

### Passo 3: Frontend - Modificar `PedidoProvider`

```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool permiteHive = true, // NOVO
}) async {
  // Implementação conforme acima
}
```

### Passo 4: Frontend - Modificar `NovoPedidoRestauranteScreen`

```dart
// Adicionar parâmetro
final bool permiteHive;

// No _finalizarPedido
final resultado = await pedidoProvider.finalizarPedido(
  permiteHive: widget.permiteHive,
);
```

### Passo 5: Frontend - Criar Widget Balcão na Home

```dart
// lib/data/models/home/home_widget_type.dart
enum HomeWidgetType {
  // ... existentes
  balcao, // NOVO
}

// lib/screens/home/home_unified_screen.dart
case HomeWidgetType.balcao:
  await NovoPedidoRestauranteScreen.show(
    context,
    permiteHive: false, // IMPORTANTE: não permite Hive
  );
  break;
```

## ✅ Resumo

1. **Backend**: Retorna `vendaId` no `PedidoDto`
2. **Frontend**: Flag `permiteHive` controla comportamento
3. **Lógica unificada**: `finalizarPedido()` decide baseado em conexão + flag
4. **Modo Balcão**: `permiteHive = false` → sempre exige conexão
5. **Modo Mesa**: `permiteHive = true` → API se online, Hive se offline

**Resultado**: Uma única tela, uma única lógica, comportamento adaptativo! 🎯

