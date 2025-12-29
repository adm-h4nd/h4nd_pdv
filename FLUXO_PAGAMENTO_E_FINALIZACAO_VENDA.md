# Fluxo de Pagamento e Finalização de Venda Balcão

## 📋 Resumo Executivo

Este documento explica a diferença entre **processar pagamento** e **concluir venda**, e quando cada ação ocorre no sistema.

---

## 🔄 Fluxo Completo

### 1. **Processar Pagamento** (`registrarPagamento`)

**O que acontece:**
- Um pagamento é registrado na venda (dinheiro, cartão, etc.)
- O saldo restante da venda é reduzido
- O pagamento fica registrado no banco de dados
- A venda continua **ABERTA** (`StatusVenda.Aberta`)

**Quando ocorre:**
- A cada vez que o usuário processa um pagamento na tela de pagamento
- Pode ser pagamento parcial ou total
- Pode haver múltiplos pagamentos para uma mesma venda

**Evento disparado:**
- `TipoEvento.pagamentoProcessado` (via `AppEventBus`)
- Callback `onPagamentoProcessado` é chamado

**Código:**
```dart
// PagamentoRestauranteScreen._processarPagamento()
await _vendaService.registrarPagamento(...);
AppEventBus.instance.dispararPagamentoProcessado(...);
widget.onPagamentoProcessado?.call(); // ✅ Chamado a cada pagamento
```

---

### 2. **Saldo Zerado** (após pagamento)

**O que acontece:**
- Quando o saldo restante chega a ≤ 0.01 após um pagamento
- O sistema oferece ao usuário a opção de **concluir a venda**

**Dialog exibido:**
```
"O saldo foi totalmente pago. Deseja concluir a venda e emitir a nota fiscal final?"
- [Concluir] - Chama _concluirVenda()
- [Depois] - Fecha a tela de pagamento, venda continua aberta
```

**Código:**
```dart
// PagamentoRestauranteScreen._processarPagamento()
if (novoSaldo <= 0.01) {
  _oferecerConclusaoVenda(); // Mostra dialog
}
```

---

### 3. **Concluir Venda** (`concluirVenda`)

**O que acontece:**
- A venda muda de status: `StatusVenda.Aberta` → `StatusVenda.Finalizada`
- Se houver produtos restantes ou pagamentos de reserva, emite nota fiscal final
- Se não houver produtos/pagamentos restantes, apenas finaliza a venda
- Libera mesa/comanda vinculada (se houver)
- Define `DataPagamento` da venda

**Quando ocorre:**
- Apenas quando o usuário **explicitamente** escolhe "Concluir" no dialog
- **NÃO** acontece automaticamente após saldo zerar
- **NÃO** acontece a cada pagamento

**Evento disparado:**
- `TipoEvento.vendaFinalizada` (via `AppEventBus`)
- Callback `onVendaConcluida` é chamado

**Código:**
```dart
// PagamentoRestauranteScreen._concluirVenda()
await _vendaService.concluirVenda(vendaId);
AppEventBus.instance.dispararVendaFinalizada(...);
widget.onVendaConcluida?.call(); // ✅ Chamado apenas quando venda é concluída
```

**Backend:**
```csharp
// VendaService.ConcluirVendaAsync()
venda.Status = StatusVenda.Finalizada;
venda.DataPagamento = DateTime.UtcNow;
await LiberarMesaOuComandaAsync(venda);
// Emite nota fiscal se necessário
```

---

## 🎯 Diferenças Importantes

| Aspecto | Processar Pagamento | Concluir Venda |
|---------|-------------------|----------------|
| **Status da Venda** | Continua `Aberta` | Muda para `Finalizada` |
| **Frequência** | Múltiplas vezes | Uma única vez |
| **Quando ocorre** | A cada pagamento | Apenas quando usuário escolhe "Concluir" |
| **Nota Fiscal** | Pode emitir parcial (se selecionado) | Emite nota final (se necessário) |
| **Mesa/Comanda** | Não libera | Libera automaticamente |
| **Callback** | `onPagamentoProcessado` | `onVendaConcluida` |
| **Evento** | `pagamentoProcessado` | `vendaFinalizada` |

---

## 🔍 Fluxo Específico para Venda Balcão

### Cenário 1: Pagamento Único (Saldo Zerado)

1. Usuário finaliza pedido → `vendaBalcaoPendenteCriada` evento
2. `BalcaoScreen` abre pagamento automaticamente
3. Usuário processa pagamento → `onPagamentoProcessado` chamado
4. Saldo zera → Dialog "Concluir Venda?" aparece
5. Usuário escolhe "Concluir" → `_concluirVenda()` → `onVendaConcluida` chamado
6. `BalcaoScreen` limpa venda pendente e volta para tela de pedido

### Cenário 2: Pagamento Parcial (Saldo Restante)

1. Usuário finaliza pedido → `vendaBalcaoPendenteCriada` evento
2. `BalcaoScreen` abre pagamento automaticamente
3. Usuário processa pagamento parcial → `onPagamentoProcessado` chamado
4. Saldo ainda > 0 → Tela de pagamento fecha
5. `BalcaoPaymentHelper` detecta saldo > 0 → Reabre pagamento automaticamente
6. Usuário processa outro pagamento → Repete até saldo zerar
7. Quando saldo zera → Dialog "Concluir Venda?" → Usuário conclui → `onVendaConcluida` chamado

### Cenário 3: Usuário Escolhe "Depois" (Não Conclui)

1. Saldo zera → Dialog "Concluir Venda?" aparece
2. Usuário escolhe "Depois" → Tela de pagamento fecha
3. Venda continua **ABERTA** (não finalizada)
4. `BalcaoPaymentHelper` detecta saldo = 0 mas venda não concluída → Reabre pagamento
5. Usuário pode concluir depois ou continuar pagando

---

## ⚠️ Pontos de Atenção

### 1. **Venda Pode Ter Saldo Zero Mas Não Estar Finalizada**

- Saldo zerado ≠ Venda finalizada
- Venda só é finalizada quando `concluirVenda()` é chamado
- Uma venda pode ter saldo zero e ainda estar `Aberta`

### 2. **Eventos Diferentes**

- `pagamentoProcessado`: Disparado a cada pagamento (mesmo parcial)
- `vendaFinalizada`: Disparado apenas quando venda é concluída

### 3. **Callbacks Diferentes**

- `onPagamentoProcessado`: Chamado a cada pagamento processado
- `onVendaConcluida`: Chamado apenas quando venda é realmente concluída

### 4. **Para Venda Balcão**

- `BalcaoPaymentHelper` gerencia o loop de pagamento
- Reabre automaticamente se saldo > 0 após pagamento
- Só sai do loop quando:
  - Venda é concluída (`onVendaConcluida` chamado)
  - Usuário cancela a venda pendente

---

## 📝 Respostas às Perguntas

### ❓ Existe algum evento que ocorre quando finaliza todos os pagamentos?

**Sim**, mas há uma distinção:
- **Quando saldo zera**: Nenhum evento automático. Apenas um dialog é exibido.
- **Quando venda é concluída**: Evento `vendaFinalizada` é disparado.

### ❓ Isso está finalizando a venda balcão?

**Não automaticamente**. Apenas quando o usuário escolhe "Concluir" no dialog.

### ❓ Em que momento a venda balcão é finalizada?

**Apenas quando:**
1. Saldo está zerado (≤ 0.01)
2. Usuário escolhe "Concluir" no dialog
3. `_concluirVenda()` é chamado
4. Backend muda status para `Finalizada`

---

## 🔧 Recomendações

1. **Sempre verificar status da venda**, não apenas saldo
2. **Usar `onVendaConcluida`** para saber quando venda realmente foi finalizada
3. **Não assumir** que saldo zero = venda finalizada
4. **Para balcão**: Limpar venda pendente apenas quando `onVendaConcluida` for chamado

