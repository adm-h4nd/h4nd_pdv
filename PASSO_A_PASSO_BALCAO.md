# Passo a Passo: Implementação do Modo Balcão

## 📌 Situação Atual

**O que já funciona:**
- ✅ Backend retorna `vendaId` quando cria um pedido
- ✅ Frontend tem `PedidoDto` com campo `vendaId`
- ✅ Tela de pedido (`NovoPedidoRestauranteScreen`) existe e funciona para mesas

**O que precisa fazer:**
- Criar modo "balcão" que funciona diferente do modo "mesa"

---

## 🎯 Objetivo Final

**Modo Balcão:**
- Abre direto na seleção de produtos
- Quando finalizar o pedido → vai direto para API (não salva no Hive)
- Depois do pedido → abre tela de pagamento automaticamente
- Depois do pagamento → finaliza a venda automaticamente
- **Sempre precisa de conexão** (não funciona offline)

**Modo Mesa (atual):**
- Continua funcionando como está
- Se tiver conexão → vai para API
- Se não tiver conexão → salva no Hive para sincronizar depois

---

## 📝 PASSO 1: Criar um Model para o Resultado da Finalização

### O que é?
Atualmente, `finalizarPedido()` retorna apenas `String?` (o ID do pedido). Precisamos retornar mais informações, como:
- Se deu certo ou não
- O ID do pedido
- O ID da venda (importante!)
- Se foi salvo no Hive ou enviado direto para API
- Mensagem de erro (se houver)

### Onde criar?
**Arquivo:** `lib/data/models/local/finalizar_pedido_result.dart`

### Como criar?
```dart
class FinalizarPedidoResult {
  final bool sucesso;              // true se deu certo, false se deu erro
  final String? pedidoId;          // ID do pedido (local ou remoto)
  final String? pedidoRemoteId;    // ID do pedido no servidor (se foi enviado)
  final String? vendaId;           // ID da venda (IMPORTANTE para balcão)
  final String? erro;              // Mensagem de erro (se houver)
  final bool foiSalvoNoHive;       // true se foi salvo no Hive
  final bool foiEnviadoDireto;     // true se foi enviado direto para API

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

### Por que fazer isso?
Para que a tela saiba:
- Se o pedido foi criado com sucesso
- Qual é o `vendaId` (para abrir a tela de pagamento)
- Se foi salvo no Hive ou enviado direto

---

## 📝 PASSO 2: Modificar o `PedidoProvider.finalizarPedido()`

### O que é?
O método `finalizarPedido()` atualmente:
- Sempre salva no Hive
- Retorna apenas o ID do pedido

Precisamos mudar para:
- Verificar se tem conexão
- Se tiver conexão → enviar direto para API
- Se não tiver conexão → salvar no Hive (mas só se permitir)
- Retornar `FinalizarPedidoResult` com todas as informações

### Onde modificar?
**Arquivo:** `lib/presentation/providers/pedido_provider.dart`
**Método:** `finalizarPedido()` (linha ~164)

### Como modificar?

**ANTES:**
```dart
Future<String?> finalizarPedido() async {
  // Sempre salva no Hive
  await _pedidoRepo.upsert(_pedidoAtual!);
  return _pedidoAtual!.id;
}
```

**DEPOIS:**
```dart
Future<FinalizarPedidoResult> finalizarPedido({
  bool permiteHive = true,  // NOVO: se false, não permite salvar no Hive
}) async {
  // 1. Verificar se tem conexão
  final config = Environment.config;
  final healthCheck = await HealthCheckService.checkHealth(config.apiBaseUrl);
  final temConexao = healthCheck.success;
  
  // 2. Se não tem conexão E não permite Hive → ERRO
  if (!temConexao && !permiteHive) {
    return FinalizarPedidoResult(
      sucesso: false,
      erro: 'Balcão requer conexão com o servidor. Verifique sua internet.',
    );
  }
  
  // 3. Se tem conexão → tentar enviar para API
  if (temConexao) {
    try {
      // Converter pedido local para DTO
      final pedidoDto = await _converterParaDto(_pedidoAtual!);
      
      // Enviar para API
      final response = await _pedidoService.createPedido(pedidoDto);
      
      if (response.success && response.data != null) {
        // Parsear resposta
        final pedidoData = response.data!;
        final pedidoId = pedidoData['id'] as String?;
        final vendaId = pedidoData['vendaId'] as String?; // IMPORTANTE!
        
        // Limpar pedido atual
        _inicializarPedido();
        notifyListeners();
        
        return FinalizarPedidoResult(
          sucesso: true,
          pedidoId: pedidoId,
          pedidoRemoteId: pedidoId,
          vendaId: vendaId,  // IMPORTANTE: retornar vendaId
          foiEnviadoDireto: true,
        );
      }
    } catch (e) {
      // Se falhar e permiteHive, pode tentar Hive
      if (permiteHive) {
        // Continua para salvar no Hive (código abaixo)
      } else {
        // Modo balcão: não permite fallback
        return FinalizarPedidoResult(
          sucesso: false,
          erro: 'Erro ao enviar pedido: ${e.toString()}',
        );
      }
    }
  }
  
  // 4. Fallback: Salvar no Hive (só se permiteHive = true)
  if (permiteHive) {
    _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
    await _pedidoRepo.upsert(_pedidoAtual!);
    
    final pedidoIdSalvo = _pedidoAtual!.id;
    _inicializarPedido();
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

### O que precisa fazer também?
- Criar método `_converterParaDto()` que converte `PedidoLocal` para `Map<String, dynamic>` (igual ao que já existe no `SyncService`)

---

## 📝 PASSO 3: Modificar a Tela `NovoPedidoRestauranteScreen`

### O que é?
A tela atual sempre salva no Hive. Precisamos:
- Adicionar um parâmetro `permiteHive`
- Se `permiteHive = false` (balcão):
  - Enviar para API
  - Pegar o `vendaId` do resultado
  - Abrir tela de pagamento automaticamente
  - Depois do pagamento, finalizar venda automaticamente

### Onde modificar?
**Arquivo:** `lib/screens/pedidos/restaurante/novo_pedido_restaurante_screen.dart`

### Como modificar?

**1. Adicionar parâmetro na classe:**
```dart
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId;
  final String? comandaId;
  final bool permiteHive;  // NOVO
  
  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.permiteHive = true,  // Padrão: true (comportamento atual)
  });
}
```

**2. Modificar o método `_finalizarPedido()`:**
```dart
Future<void> _finalizarPedido(BuildContext context) async {
  final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
  
  if (pedidoProvider.isEmpty) {
    // Mostrar erro
    return;
  }

  // Mostrar loading
  showDialog(...);

  try {
    // Finalizar pedido (agora retorna FinalizarPedidoResult)
    final resultado = await pedidoProvider.finalizarPedido(
      permiteHive: widget.permiteHive,  // Passar o parâmetro
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Fechar loading

    if (resultado.sucesso) {
      // Se for modo balcão (permiteHive = false) E tem vendaId
      if (!widget.permiteHive && resultado.vendaId != null) {
        // Abrir tela de pagamento automaticamente
        await _abrirPagamentoEfinalizar(context, resultado.vendaId!);
      } else {
        // Modo mesa: comportamento atual (mostrar mensagem e voltar)
        ScaffoldMessenger.of(context).showSnackBar(...);
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } else {
      // Mostrar erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado.erro ?? 'Erro desconhecido')),
      );
    }
  } catch (e) {
    // Tratar erro
  }
}

// NOVO método para abrir pagamento e finalizar
Future<void> _abrirPagamentoEfinalizar(BuildContext context, String vendaId) async {
  // 1. Buscar venda
  // 2. Abrir tela de pagamento
  // 3. Após pagamento, finalizar venda
  // 4. Voltar para home
}
```

---

## 📝 PASSO 4: Criar Widget "Balcão" na Tela Home

### O que é?
Adicionar um botão/card na tela inicial que abre o modo balcão.

### Onde modificar?
**Arquivo:** `lib/screens/home/home_unified_screen.dart`

### Como modificar?

**1. Adicionar tipo de widget (se não existir):**
```dart
enum HomeWidgetType {
  // ... existentes
  balcao,  // NOVO
}
```

**2. Adicionar case no switch:**
```dart
case HomeWidgetType.balcao:
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => NovoPedidoRestauranteScreen(
        permiteHive: false,  // IMPORTANTE: não permite Hive
      ),
    ),
  );
  break;
```

---

## 📋 Resumo dos Passos

1. **Criar `FinalizarPedidoResult`** → Model para retornar resultado completo
2. **Modificar `PedidoProvider.finalizarPedido()`** → Adicionar lógica de conexão e flag `permiteHive`
3. **Modificar `NovoPedidoRestauranteScreen`** → Adicionar parâmetro e lógica de pagamento automático
4. **Criar widget "Balcão" na home** → Botão que abre a tela com `permiteHive: false`

---

## ❓ Dúvidas Comuns

**P: Por que precisa do `vendaId`?**
R: Porque a tela de pagamento precisa saber qual venda está sendo paga.

**P: O que acontece se não tiver conexão no modo balcão?**
R: Mostra erro e não permite continuar (porque balcão sempre precisa de conexão).

**P: O modo mesa continua funcionando igual?**
R: Sim! Se `permiteHive = true` (padrão), funciona exatamente como antes.

**P: Como funciona o pagamento automático?**
R: Depois de criar o pedido, abre a tela de pagamento. Quando o pagamento é concluído, finaliza a venda automaticamente.

