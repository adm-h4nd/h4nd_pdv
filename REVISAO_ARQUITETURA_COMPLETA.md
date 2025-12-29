# Revisão Arquitetural Completa - Sistema de Vendas

## 📋 Visão Geral da Arquitetura

### Estrutura Atual

```
lib/
├── core/
│   ├── services/          # Services estáticos/helpers
│   │   └── venda_balcao_pendente_service.dart
│   └── ...
├── data/
│   ├── services/         # Services de API (com ApiClient)
│   │   ├── core/         # Services core (venda, pedido, produto)
│   │   └── modules/      # Services por módulo (restaurante)
│   └── ...
├── presentation/
│   └── providers/        # Providers (ChangeNotifier)
│       ├── pedido_provider.dart
│       ├── services_provider.dart
│       └── ...
└── screens/
    ├── balcao/
    │   └── balcao_screen.dart
    └── pedidos/
        └── restaurante/
            └── novo_pedido_restaurante_screen.dart
```

---

## 🔍 Análise de Providers

### Providers Existentes

1. **PedidoProvider** - Gerencia pedido em construção
2. **ServicesProvider** - Container de services (singleton-like)
3. **VendaProvider** - Gerencia vendas
4. **MesasProvider** - Gerencia lista de mesas
5. **MesaDetalhesProvider** - Gerencia detalhes de uma mesa
6. **SyncProvider** - Gerencia sincronização
7. **AuthProvider** - Gerencia autenticação

### Problemas Identificados

#### 1. **PedidoProvider com Responsabilidades Mistas** ⚠️ ALTA
**Problema:**
- Gerencia estado do pedido (responsabilidade correta)
- Mas também faz conversão para DTO (`_converterPedidoLocalParaDto`)
- E faz chamadas diretas à API (`finalizarPedidoBalcao`)

**Impacto:** Viola Single Responsibility Principle

**Solução:** 
- Manter apenas gerenciamento de estado no Provider
- Mover conversão para um `PedidoMapper` ou método no próprio `PedidoLocal`
- Mover lógica de API para um service específico

---

#### 2. **ServicesProvider como "God Object"** ⚠️ MÉDIA
**Problema:**
- Centraliza TODOS os services
- Mistura concerns (API services + repositories + sync)
- Difícil de testar e manter

**Impacto:** Alto acoplamento, difícil de testar

**Solução:** 
- Manter apenas como container de services de API
- Repositories e sync podem ser injetados diretamente onde necessário
- Ou criar providers específicos (ex: `SyncProvider` já existe)

---

#### 3. **Falta de Provider para Venda Balcão** ⚠️ MÉDIA
**Problema:**
- Lógica de venda balcão espalhada em:
  - `BalcaoScreen` (verificação, navegação)
  - `NovoPedidoRestauranteScreen` (finalização)
  - `BalcaoPaymentHelper` (pagamento)
  - `VendaBalcaoPendenteService` (persistência)

**Impacto:** Lógica fragmentada, difícil de manter

**Solução:** Criar `VendaBalcaoProvider` para centralizar:
- Estado da venda pendente
- Lógica de verificação
- Coordenação do fluxo

---

## 🔍 Análise de Services

### Services Existentes

#### Services de API (com ApiClient)
- `VendaService` - Operações de venda
- `PedidoService` - Operações de pedido
- `ProdutoService` - Operações de produto
- `MesaService` - Operações de mesa
- `ComandaService` - Operações de comanda
- `ConfiguracaoRestauranteService` - Configuração

#### Services Estáticos/Helpers
- `VendaBalcaoPendenteService` - Persistência de venda pendente

### Problemas Identificados

#### 1. **Inconsistência na Organização** ⚠️ MÉDIA
**Problema:**
- `VendaBalcaoPendenteService` está em `core/services/`
- Mas outros services estão em `data/services/`
- Não há padrão claro

**Solução:** 
- Services de API → `data/services/`
- Services de lógica de negócio/helpers → `core/services/`
- Ou criar `core/services/business/` para lógica de negócio

---

#### 2. **BalcaoPaymentHelper como Helper Estático** ⚠️ BAIXA
**Problema:**
- Helper estático com lógica complexa (160+ linhas)
- Não é testável facilmente
- Mistura concerns (UI + lógica de negócio)

**Solução:** 
- Manter como helper se for apenas orquestração de UI
- Ou mover lógica de negócio para um service/provider

---

## 🔍 Análise de Fluxos

### Fluxo: Venda Mesa (Normal)

```
1. Usuário seleciona mesa
   ↓
2. NovoPedidoRestauranteScreen (isVendaBalcao=false)
   ↓
3. Usuário seleciona produtos
   ↓
4. PedidoProvider gerencia estado local
   ↓
5. Usuário finaliza pedido
   ↓
6. PedidoProvider.finalizarPedido()
   - Salva no Hive (PedidoLocal)
   - Marca como pendente de sync
   ↓
7. AutoSyncManager detecta mudança
   ↓
8. SyncService sincroniza com API
   ↓
9. Tela fecha
```

**Observações:**
- ✅ Fluxo claro e bem definido
- ✅ Separação de responsabilidades (Provider → Repository → Sync)
- ⚠️ Dependência de AutoSyncManager (pode ser melhor documentada)

---

### Fluxo: Venda Balcão

```
1. Usuário clica em "Balcão"
   ↓
2. BalcaoScreen verifica venda pendente
   ↓
3a. Se tem pendente:
    - Busca venda
    - Abre PagamentoRestauranteScreen
    ↓
3b. Se não tem pendente:
    - Abre NovoPedidoRestauranteScreen (isVendaBalcao=true)
    ↓
4. Usuário seleciona produtos
   ↓
5. PedidoProvider gerencia estado local
   ↓
6. Usuário finaliza pedido
   ↓
7. NovoPedidoRestauranteScreen._finalizarPedidoBalcao()
   - Chama PedidoProvider.finalizarPedidoBalcao()
   - Envia direto para API
   - Salva vendaId pendente
   - Busca venda
   - Abre PagamentoRestauranteScreen
   ↓
8. PagamentoRestauranteScreen
   - Processa pagamentos (parciais ou completos)
   - onPagamentoProcessado (a cada pagamento)
   - onVendaConcluida (quando conclui)
   ↓
9. BalcaoPaymentHelper gerencia loop
   - Reabre pagamento se parcial
   - Mostra confirmação se fechar sem finalizar
   ↓
10. Quando venda concluída:
    - Limpa venda pendente
    - Fecha fluxo
```

**Observações:**
- ⚠️ Fluxo complexo com múltiplos pontos de entrada
- ⚠️ Lógica espalhada em vários lugares
- ⚠️ Dificulta manutenção e testes

---

## 🔍 Análise de Padrões

### Padrões Identificados

#### ✅ Padrões Consistentes

1. **Providers usam ChangeNotifier**
   - Todos os providers estendem `ChangeNotifier`
   - Usam `notifyListeners()` corretamente

2. **Services de API recebem ApiClient**
   - Todos os services de API recebem `ApiClient` no construtor
   - Usam o mesmo `ApiClient` do `AuthService` (via `ServicesProvider`)

3. **Repositories para dados locais**
   - Padrão Repository para Hive
   - Separação clara entre API e local

4. **Helpers estáticos para operações simples**
   - `VendaBalcaoPendenteService` (persistência simples)
   - `_LoadingOverlay` (UI helper)

---

#### ⚠️ Padrões Inconsistentes

1. **Verificação de `mounted`**
   - Alguns lugares usam `mounted`
   - Outros usam `context.mounted`
   - Alguns não verificam

2. **Tratamento de Erros**
   - Alguns mostram SnackBar
   - Outros apenas debugPrint
   - Não há padrão unificado

3. **Loading**
   - Alguns usam `showDialog` direto
   - Outros usam helpers
   - Não há padrão unificado

4. **Nomenclatura de Services**
   - `VendaBalcaoPendenteService` (estático)
   - `VendaService` (instância)
   - Inconsistência na organização

---

## 🔍 Análise de Duplicações

### Duplicações Encontradas

#### 1. **Busca de Venda** ⚠️ MÉDIA
**Localizações:**
- `BalcaoPaymentHelper._buscarVendaAtualizada()` (linha 41)
- `BalcaoScreen._abrirPagamentoPendente()` (linha 289)
- `NovoPedidoRestauranteScreen._finalizarPedidoBalcao()` (linha 962)

**Problema:** Mesma lógica em 3 lugares

**Solução:** 
- Mover para `VendaService` como método helper
- Ou criar `VendaHelper` estático

---

#### 2. **Construção de ProdutosAgrupados** ⚠️ BAIXA
**Localizações:**
- `NovoPedidoRestauranteScreen._construirProdutosAgrupadosDoPedidoLocal()` (linha 1012)
- `BalcaoScreen` usa lista vazia (linha 307)

**Problema:** Lógica de construção apenas em um lugar, mas poderia ser reutilizada

**Solução:** 
- Extrair para helper estático ou método no `PedidoLocal`

---

#### 3. **Verificação de Venda Pendente** ⚠️ BAIXA
**Localizações:**
- `BalcaoScreen._verificarVendaPendente()` (linha 246)
- `NovoPedidoRestauranteScreen._verificarVendaPendente()` (linha 109)

**Problema:** Lógica similar em 2 lugares

**Solução:** 
- Centralizar em `VendaBalcaoPendenteService` ou criar provider

---

## 🎯 Recomendações de Arquitetura

### 1. **Criar VendaBalcaoProvider** 🔴 ALTA PRIORIDADE

**Justificativa:**
- Centraliza lógica de venda balcão
- Facilita testes
- Reduz duplicação
- Prepara para outros segmentos

**Estrutura Proposta:**
```dart
class VendaBalcaoProvider extends ChangeNotifier {
  String? _vendaIdPendente;
  bool _isVerificando = false;
  
  // Getters
  String? get vendaIdPendente => _vendaIdPendente;
  bool get temVendaPendente => _vendaIdPendente != null;
  bool get isVerificando => _isVerificando;
  
  // Métodos
  Future<void> salvarVendaPendente(String vendaId);
  Future<void> limparVendaPendente();
  Future<VendaDto?> buscarVendaAtualizada(BuildContext context);
  Future<bool> verificarEVenderPendente(BuildContext context);
}
```

**Benefícios:**
- Lógica centralizada
- Estado reativo
- Fácil de testar
- Preparado para outros segmentos

---

### 2. **Refatorar PedidoProvider** 🟡 MÉDIA PRIORIDADE

**Problema:** Mistura responsabilidades

**Solução:**
- Manter apenas gerenciamento de estado
- Mover `_converterPedidoLocalParaDto` para:
  - Método `toCreateDto()` no `PedidoLocal`
  - Ou criar `PedidoMapper` helper
- Mover `finalizarPedidoBalcao` para:
  - `PedidoService` (já existe `createPedido`)
  - Ou criar `VendaBalcaoService`

---

### 3. **Padronizar Helpers e Services** 🟡 MÉDIA PRIORIDADE

**Estrutura Proposta:**
```
lib/core/services/
├── business/              # Lógica de negócio
│   ├── venda_balcao_service.dart
│   └── ...
├── ui/                    # Helpers de UI
│   ├── loading_helper.dart
│   └── ...
└── storage/               # Persistência simples
    └── venda_balcao_pendente_service.dart
```

**Benefícios:**
- Organização clara
- Fácil de encontrar
- Padrão consistente

---

### 4. **Criar Base Classes/Interfaces** 🟢 BAIXA PRIORIDADE

**Proposta:**
```dart
// Base para services de API
abstract class BaseApiService {
  final ApiClient apiClient;
  BaseApiService(this.apiClient);
}

// Base para providers
abstract class BaseProvider extends ChangeNotifier {
  // Helpers comuns (loading, error handling)
}
```

**Benefícios:**
- Código reutilizável
- Padrão consistente
- Facilita manutenção

---

## 🔍 Análise de Preparação para Outros Segmentos

### Segmentos Futuros Possíveis

1. **Delivery** - Entrega em domicílio
2. **Drive-Thru** - Retirada no balcão
3. **Balcão Físico** - Venda presencial (já implementado)
4. **E-commerce** - Venda online

### Pontos de Atenção

#### 1. **Flag `isVendaBalcao` é Específica** ⚠️
**Problema:**
- Flag booleana não escala para múltiplos segmentos
- `isVendaBalcao: true/false` não permite outros tipos

**Solução:**
```dart
enum TipoVenda {
  mesa,      // Venda em mesa
  balcao,    // Venda balcão
  delivery,  // Entrega
  driveThru, // Retirada
}

class NovoPedidoRestauranteScreen {
  final TipoVenda tipoVenda;
  // ...
}
```

---

#### 2. **Lógica de Finalização Específica** ⚠️
**Problema:**
- `_finalizarPedidoBalcao()` é específico para balcão
- Não há abstração para outros tipos

**Solução:**
```dart
abstract class FinalizacaoPedidoStrategy {
  Future<void> finalizar(PedidoLocal pedido, BuildContext context);
}

class FinalizacaoMesaStrategy implements FinalizacaoPedidoStrategy {
  // Salva no Hive
}

class FinalizacaoBalcaoStrategy implements FinalizacaoPedidoStrategy {
  // Envia para API
}

class FinalizacaoDeliveryStrategy implements FinalizacaoPedidoStrategy {
  // Lógica específica de delivery
}
```

---

#### 3. **Persistência de Estado Pendente** ⚠️
**Problema:**
- `VendaBalcaoPendenteService` é específico para balcão
- Não escala para outros segmentos

**Solução:**
```dart
class VendaPendenteService {
  static Future<void> salvarVendaPendente(
    String vendaId, 
    TipoVenda tipoVenda
  );
  
  static String? obterVendaPendente(TipoVenda tipoVenda);
  static Future<void> limparVendaPendente(TipoVenda tipoVenda);
}
```

---

## 📊 Checklist de Consistência

### Padrões de Código

- [ ] **Verificação de `mounted`**: Padronizar para `mounted` (mais simples)
- [ ] **Tratamento de Erros**: Criar helper unificado
- [ ] **Loading**: Criar helper unificado
- [ ] **Nomenclatura**: Padronizar (Service vs Provider vs Helper)
- [ ] **Organização de Arquivos**: Estrutura clara e consistente

### Arquitetura

- [ ] **Providers**: Apenas gerenciamento de estado
- [ ] **Services**: Apenas chamadas de API ou lógica de negócio pura
- [ ] **Helpers**: Apenas orquestração de UI ou operações simples
- [ ] **Repositories**: Apenas persistência local

### Preparação para Escala

- [ ] **Flags**: Usar enums ao invés de booleans para tipos
- [ ] **Estratégias**: Usar Strategy Pattern para comportamentos diferentes
- [ ] **Abstrações**: Criar interfaces/base classes quando apropriado

---

## 🎯 Plano de Ação Recomendado

### Fase 1: Consolidação (Alta Prioridade)
1. ✅ Criar `VendaBalcaoProvider` para centralizar lógica
2. ✅ Padronizar verificação de `mounted`
3. ✅ Criar helpers unificados (loading, erro)
4. ✅ Extrair busca de venda para método reutilizável

### Fase 2: Refatoração (Média Prioridade)
5. Refatorar `PedidoProvider` (separar responsabilidades)
6. Reorganizar services (estrutura clara)
7. Padronizar tratamento de erros

### Fase 3: Preparação para Escala (Baixa Prioridade)
8. Substituir `isVendaBalcao` por enum `TipoVenda`
9. Implementar Strategy Pattern para finalização
10. Generalizar persistência de vendas pendentes

---

## 📝 Conclusão

### Pontos Fortes
- ✅ Separação clara entre API e local (Repositories)
- ✅ Providers bem estruturados (ChangeNotifier)
- ✅ Services de API consistentes
- ✅ Fluxo de venda mesa bem definido

### Pontos de Melhoria
- ⚠️ Lógica de venda balcão fragmentada
- ⚠️ `PedidoProvider` com responsabilidades mistas
- ⚠️ Falta de padrões unificados (loading, erro, mounted)
- ⚠️ Preparação limitada para outros segmentos

### Recomendação Principal
**Criar `VendaBalcaoProvider`** para centralizar lógica e preparar o sistema para outros segmentos. Isso vai:
- Reduzir duplicação
- Facilitar manutenção
- Preparar para escala
- Manter padrão consistente

