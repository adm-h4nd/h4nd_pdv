# Resumo: Implementação do Modo Balcão

## ✅ O que foi feito

### 1. Remoção de Pagamento Pendente e Deeplink
- ✅ Removidos todos os arquivos relacionados
- ✅ Limpas todas as referências no código
- ✅ **Conclusão**: Pagamento sempre vai direto para API (não usa Hive)

### 2. Backend: Retorno de `vendaId` ✅ IMPLEMENTADO
- ✅ Adicionado `VendaId` ao `PedidoDto`
- ✅ Mapeado no `MapToDtoAsync`
- ✅ Agora quando criar pedido, retorna `vendaId` diretamente

## 📋 Próximos Passos

### Passo 1: Frontend - Criar `FinalizarPedidoResult` ✅ (Próximo)
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
}
```

### Passo 2: Frontend - Modificar `PedidoProvider.finalizarPedido()`
- Adicionar parâmetro `permiteHive: bool`
- Verificar conexão
- Se `permiteHive = false` e offline → ERRO
- Se `permiteHive = true` e offline → Hive
- Se online → API direto (retorna `vendaId`)

### Passo 3: Frontend - Modificar `NovoPedidoRestauranteScreen`
- Adicionar parâmetro `permiteHive: bool` (padrão: `true`)
- Modificar `_finalizarPedido()` para:
  - Se `permiteHive = false` (balcão):
    - Finalizar pedido → obter `vendaId`
    - Abrir `PagamentoScreen` automaticamente
    - Após pagamento, finalizar venda automaticamente
  - Se `permiteHive = true` (mesa):
    - Comportamento atual (salva no Hive se offline)

### Passo 4: Frontend - Criar Widget "Balcão" na Home
- Adicionar `HomeWidgetType.balcão`
- Ao clicar, abre `NovoPedidoRestauranteScreen` com `permiteHive: false`

### Passo 5: Frontend - Atualizar Model do Pedido
- Garantir que `PedidoDto` no frontend tenha campo `vendaId`
- Atualizar parsing do JSON

## 🎯 Fluxo Final

### Modo Balcão (`permiteHive = false`)
```
1. Criar Pedido → API (sempre exige conexão)
   └─ Retorna: pedidoId, vendaId
2. Abrir Pagamento → Automático
   └─ Busca venda: GET /api/vendas/{vendaId}
3. Processar Pagamento → API
   └─ POST /api/vendas/{vendaId}/pagamentos
4. Finalizar Venda → Automático
   └─ POST /api/vendas/{vendaId}/concluir
```

### Modo Mesa (`permiteHive = true`)
```
1. Criar Pedido
   └─ Se online: API (retorna vendaId)
   └─ Se offline: Hive
2. Pagamento → API (sempre)
3. Finalizar → API (sempre)
```

## 📝 Status Atual

- ✅ Backend retorna `vendaId` no `PedidoDto`
- ✅ Frontend: `PedidoDto` já possui `vendaId` (já estava implementado)
- ⏳ Frontend: Criar `FinalizarPedidoResult`
- ⏳ Frontend: Modificar `PedidoProvider`
- ⏳ Frontend: Modificar `NovoPedidoRestauranteScreen`
- ⏳ Frontend: Criar widget "Balcão"

## 🔍 Pontos Importantes

1. **Pagamento NÃO usa Hive**: Sempre vai para API
2. **Flag `permiteHive`**: Só afeta criação do pedido
3. **Backend já retorna `vendaId`**: Implementado ✅
4. **Próximo passo**: Criar `FinalizarPedidoResult` no frontend

