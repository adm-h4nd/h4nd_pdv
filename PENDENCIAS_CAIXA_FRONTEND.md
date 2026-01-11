# Pendências - Módulo de Caixa (Frontend PDV)

## 📋 Status Atual

### ✅ O que já foi implementado no Backend

- Remoção da necessidade de informar conta de origem na abertura de caixa
- Configuração `ExibirValoresFechamentoCaixa` na `ConfiguracaoRestaurante`
- Validação para garantir apenas uma conta interna ativa por empresa

### ⚠️ O que falta fazer no Frontend

---

## 🔴 PRIORIDADE ALTA

### 1. Atualizar `AbrirCaixaScreen` - Remover Seleção de Conta

**Arquivo:** `lib/screens/caixa/abrir_caixa_screen.dart`

**Mudanças necessárias:**

#### 1.1. Remover variáveis de estado relacionadas à conta
```dart
// ❌ REMOVER estas variáveis:
ContaBancariaListItemDto? _contaSelecionada;
List<ContaBancariaListItemDto> _contas = [];
bool _isLoadingContas = false;
```

#### 1.2. Remover método de carregamento de contas
```dart
// ❌ REMOVER este método:
Future<void> _carregarContas() async {
  setState(() {
    _isLoadingContas = true;
  });

  try {
    final empresaId = await _authService.getSelectedEmpresa();
    if (empresaId == null) {
      setState(() {
        _isLoadingContas = false;
      });
      return;
    }

    final response = await _servicesProvider.contaBancariaService
        .getContasPorEmpresaAsync(empresaId);

    if (response.success && response.data != null) {
      setState(() {
        _contas = response.data!
            .where((conta) => conta.tipo == TipoConta.interna && conta.isActive)
            .toList();
        _isLoadingContas = false;
      });
    } else {
      setState(() {
        _isLoadingContas = false;
      });
    }
  } catch (e) {
    setState(() {
      _isLoadingContas = false;
    });
  }
}
```

#### 1.3. Remover chamada no `initState`
```dart
@override
void initState() {
  super.initState();
  // ❌ REMOVER esta linha:
  // _carregarContas();
  _carregarCaixas();
}
```

#### 1.4. Remover o campo de seleção de conta do formulário
```dart
// ❌ REMOVER todo este bloco do formulário:
if (_isLoadingContas) ...[
  const Center(child: CircularProgressIndicator()),
  const SizedBox(height: 16),
  Text('Carregando contas...'),
] else if (_contas.isEmpty) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.warningColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('Nenhuma conta interna encontrada.'),
  ),
] else ...[
  Text('Conta de Origem *'),
  const SizedBox(height: 8),
  DropdownButtonFormField<ContaBancariaListItemDto>(
    value: _contaSelecionada,
    decoration: InputDecoration(...),
    items: _contas.map((conta) {
      return DropdownMenuItem<ContaBancariaListItemDto>(
        value: conta,
        child: Text('${conta.nome} - R\$ ${conta.saldoAtual.toStringAsFixed(2)}'),
      );
    }).toList(),
    onChanged: (conta) {
      setState(() {
        _contaSelecionada = conta;
        _errorMessage = null;
      });
    },
    validator: (value) {
      if (value == null) {
        return 'Por favor, selecione uma conta de origem';
      }
      return null;
    },
  ),
],
```

#### 1.5. Atualizar método `_abrirCaixa` para não enviar `contaOrigemId`
```dart
// ✅ ANTES:
final dto = AbrirCicloCaixaDto(
  caixaId: _caixaSelecionado!.id,
  valorInicial: _valorInicial,
  contaOrigemId: _contaSelecionada!.id, // ❌ REMOVER
);

// ✅ DEPOIS:
final dto = AbrirCicloCaixaDto(
  caixaId: _caixaSelecionado!.id,
  valorInicial: _valorInicial,
  // contaOrigemId removido - será buscado automaticamente pelo backend
);
```

---

### 2. Atualizar `AbrirCicloCaixaDto` no Flutter

**Arquivo:** `lib/data/models/core/caixa/ciclo_caixa_dto.dart`

**Mudanças necessárias:**

```dart
// ❌ ANTES:
class AbrirCicloCaixaDto {
  final String caixaId;
  final double valorInicial;
  final String contaOrigemId; // ❌ REMOVER

  AbrirCicloCaixaDto({
    required this.caixaId,
    required this.valorInicial,
    required this.contaOrigemId, // ❌ REMOVER
  });

  Map<String, dynamic> toJson() {
    return {
      'caixaId': caixaId,
      'valorInicial': valorInicial,
      'contaOrigemId': contaOrigemId, // ❌ REMOVER
    };
  }
}

// ✅ DEPOIS:
class AbrirCicloCaixaDto {
  final String caixaId;
  final double valorInicial;

  AbrirCicloCaixaDto({
    required this.caixaId,
    required this.valorInicial,
  });

  Map<String, dynamic> toJson() {
    return {
      'caixaId': caixaId,
      'valorInicial': valorInicial,
    };
  }
}
```

---

### 3. Atualizar `FecharCaixaScreen` - Exibição Condicional de Valores

**Arquivo:** `lib/screens/caixa/fechar_caixa_screen.dart`

**Mudanças necessárias:**

#### 3.1. Adicionar variáveis de estado
```dart
// ✅ ADICIONAR:
bool _exibirValoresEsperados = true;
bool _isLoadingConfiguracao = false;
```

#### 3.2. Adicionar método para carregar configuração
```dart
// ✅ ADICIONAR este método:
Future<void> _carregarConfiguracaoRestaurante() async {
  setState(() {
    _isLoadingConfiguracao = true;
  });

  try {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    final authService = servicesProvider.authService;
    
    final empresaId = await authService.getSelectedEmpresa();
    if (empresaId == null) {
      setState(() {
        _isLoadingConfiguracao = false;
      });
      return;
    }

    final response = await servicesProvider.configuracaoRestauranteService
        .getByEmpresaIdAsync(empresaId);

    if (response.success && response.data != null) {
      setState(() {
        _exibirValoresEsperados = response.data!.exibirValoresFechamentoCaixa;
        _isLoadingConfiguracao = false;
      });
    } else {
      // Se não houver configuração, usar padrão (true)
      setState(() {
        _exibirValoresEsperados = true;
        _isLoadingConfiguracao = false;
      });
    }
  } catch (e) {
    debugPrint('Erro ao carregar configuração do restaurante: $e');
    // Em caso de erro, usar padrão (true)
    setState(() {
      _exibirValoresEsperados = true;
      _isLoadingConfiguracao = false;
    });
  }
}
```

#### 3.3. Chamar método no `initState`
```dart
@override
void initState() {
  super.initState();
  _carregarConfiguracaoRestaurante(); // ✅ ADICIONAR
  // ... outros métodos de inicialização
}
```

#### 3.4. Atualizar UI para exibição condicional
```dart
// ✅ MODIFICAR a seção de valores no formulário:

// Seção de Valores Esperados (condicional)
if (_exibirValoresEsperados) ...[
  Text(
    'Valores Esperados',
    style: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
  ),
  const SizedBox(height: 16),
  
  // Dinheiro Esperado
  if (widget.cicloCaixa.valorDinheiroEsperado != null) ...[
    Text('Dinheiro Esperado'),
    Text('R\$ ${widget.cicloCaixa.valorDinheiroEsperado!.toStringAsFixed(2)}'),
  ],
  
  // Cartão Crédito Esperado
  if (widget.cicloCaixa.valorCartaoCreditoEsperado != null) ...[
    Text('Cartão Crédito Esperado'),
    Text('R\$ ${widget.cicloCaixa.valorCartaoCreditoEsperado!.toStringAsFixed(2)}'),
  ],
  
  // Cartão Débito Esperado
  if (widget.cicloCaixa.valorCartaoDebitoEsperado != null) ...[
    Text('Cartão Débito Esperado'),
    Text('R\$ ${widget.cicloCaixa.valorCartaoDebitoEsperado!.toStringAsFixed(2)}'),
  ],
  
  // PIX Esperado
  if (widget.cicloCaixa.valorPIXEsperado != null) ...[
    Text('PIX Esperado'),
    Text('R\$ ${widget.cicloCaixa.valorPIXEsperado!.toStringAsFixed(2)}'),
  ],
  
  // Outros Esperado
  if (widget.cicloCaixa.valorOutrosEsperado != null) ...[
    Text('Outros Esperado'),
    Text('R\$ ${widget.cicloCaixa.valorOutrosEsperado!.toStringAsFixed(2)}'),
  ],
  
  const SizedBox(height: 24),
],

// Seção de Valores Contados (sempre visível)
Text(
  'Valores Contados',
  style: GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  ),
),
const SizedBox(height: 16),

// Campos de valores contados (já existem, manter como estão)
// ...
```

---

## 🟡 PRIORIDADE MÉDIA

### 4. Verificar e atualizar `ConfiguracaoRestauranteDto` no Flutter

**Arquivo:** `lib/data/models/modules/restaurante/configuracao_restaurante_dto.dart`

**Verificar se o campo existe:**
```dart
class ConfiguracaoRestauranteDto {
  // ... outros campos
  
  // ✅ VERIFICAR se este campo existe:
  final bool exibirValoresFechamentoCaixa;
  
  ConfiguracaoRestauranteDto({
    // ... outros parâmetros
    required this.exibirValoresFechamentoCaixa, // ✅ ADICIONAR se não existir
  });
  
  factory ConfiguracaoRestauranteDto.fromJson(Map<String, dynamic> json) {
    return ConfiguracaoRestauranteDto(
      // ... outros campos
      exibirValoresFechamentoCaixa: json['exibirValoresFechamentoCaixa'] as bool? ?? true, // ✅ ADICIONAR se não existir
    );
  }
}
```

---

### 5. Verificar `ConfiguracaoRestauranteService` no Flutter

**Arquivo:** `lib/data/services/modules/restaurante/configuracao_restaurante_service.dart`

**Verificar se o método existe:**
```dart
// ✅ VERIFICAR se este método existe:
Future<ApiResponse<ConfiguracaoRestauranteDto?>> getByEmpresaIdAsync(String empresaId) async {
  try {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/ConfiguracaoRestaurante/empresa/$empresaId',
    );
    
    if (response.data == null || response.data!['data'] == null) {
      return ApiResponse<ConfiguracaoRestauranteDto?>.success(
        data: null,
        message: response.message,
      );
    }
    
    final data = response.data!['data'] as Map<String, dynamic>;
    final config = ConfiguracaoRestauranteDto.fromJson(data);
    
    return ApiResponse<ConfiguracaoRestauranteDto?>.success(
      data: config,
      message: response.message,
    );
  } catch (e) {
    return ApiResponse<ConfiguracaoRestauranteDto?>.error(
      message: ErrorMessageHelper.getErrorMessageFromException(e),
    );
  }
}
```

**Se não existir, adicionar o método acima.**

---

## 🟢 PRIORIDADE BAIXA (Opcional)

### 6. Adicionar validação de conta interna antes de abrir caixa

**Arquivo:** `lib/core/validators/caixa_validator.dart`

**Adicionar método:**
```dart
/// Verifica se existe uma conta interna ativa para a empresa
static Future<CaixaValidationResult> verificarContaInterna({
  required String empresaId,
  required ServicesProvider servicesProvider,
}) async {
  try {
    final response = await servicesProvider.contaBancariaService
        .getContasPorEmpresaAsync(empresaId);

    if (!response.success || response.data == null) {
      return CaixaValidationResult(
        isValid: false,
        message: 'Erro ao verificar contas bancárias',
      );
    }

    final contaInterna = response.data!.firstWhere(
      (conta) => conta.tipo == TipoConta.interna && conta.isActive,
      orElse: () => null,
    );

    if (contaInterna == null) {
      return CaixaValidationResult(
        isValid: false,
        message: 'Não foi encontrada uma conta interna (cofre) ativa para esta empresa. É necessário criar uma conta interna antes de abrir o caixa.',
      );
    }

    return CaixaValidationResult(
      isValid: true,
      message: null,
    );
  } catch (e) {
    return CaixaValidationResult(
      isValid: false,
      message: 'Erro ao verificar conta interna: ${e.toString()}',
    );
  }
}
```

**Usar no `AbrirCaixaScreen`:**
```dart
Future<void> _abrirCaixa() async {
  // ... validações existentes
  
  // ✅ ADICIONAR validação de conta interna:
  final empresaId = await _authService.getSelectedEmpresa();
  if (empresaId != null) {
    final validacaoConta = await CaixaValidator.verificarContaInterna(
      empresaId: empresaId,
      servicesProvider: _servicesProvider,
    );
    
    if (!validacaoConta.isValid) {
      setState(() {
        _errorMessage = validacaoConta.message;
      });
      return;
    }
  }
  
  // ... continuar com abertura
}
```

---

## 📝 Checklist de Implementação

### AbrirCaixaScreen
- [ ] Remover variáveis de estado relacionadas à conta
- [ ] Remover método `_carregarContas`
- [ ] Remover chamada no `initState`
- [ ] Remover campo de seleção de conta do formulário
- [ ] Atualizar método `_abrirCaixa` para não enviar `contaOrigemId`
- [ ] Testar abertura de caixa

### AbrirCicloCaixaDto
- [ ] Remover campo `contaOrigemId`
- [ ] Atualizar construtor
- [ ] Atualizar método `toJson`

### FecharCaixaScreen
- [ ] Adicionar variáveis de estado para configuração
- [ ] Adicionar método `_carregarConfiguracaoRestaurante`
- [ ] Chamar método no `initState`
- [ ] Atualizar UI para exibição condicional de valores esperados
- [ ] Testar fechamento com valores visíveis
- [ ] Testar fechamento com valores ocultos

### ConfiguracaoRestauranteDto
- [ ] Verificar se campo `exibirValoresFechamentoCaixa` existe
- [ ] Adicionar campo se não existir
- [ ] Atualizar `fromJson` se necessário

### ConfiguracaoRestauranteService
- [ ] Verificar se método `getByEmpresaIdAsync` existe
- [ ] Adicionar método se não existir

### Validações (Opcional)
- [ ] Adicionar método de validação de conta interna
- [ ] Integrar validação no `AbrirCaixaScreen`

---

## 🐛 Problemas Comuns e Soluções

### Problema 1: Erro ao abrir caixa - "Conta não encontrada"
**Causa:** Backend não encontrou conta interna
**Solução:** Verificar se existe uma conta interna ativa para a empresa. Se não existir, criar uma.

### Problema 2: Valores esperados sempre aparecem
**Causa:** Campo `exibirValoresFechamentoCaixa` não está sendo lido corretamente
**Solução:** Verificar se o DTO está atualizado e se o método de busca está retornando o campo.

### Problema 3: Erro de compilação - campo não encontrado
**Causa:** DTO não foi atualizado
**Solução:** Adicionar o campo `exibirValoresFechamentoCaixa` no `ConfiguracaoRestauranteDto`.

---

## 📚 Referências

### Arquivos Relacionados
- `lib/screens/caixa/abrir_caixa_screen.dart`
- `lib/screens/caixa/fechar_caixa_screen.dart`
- `lib/data/models/core/caixa/ciclo_caixa_dto.dart`
- `lib/data/models/modules/restaurante/configuracao_restaurante_dto.dart`
- `lib/data/services/modules/restaurante/configuracao_restaurante_service.dart`
- `lib/core/validators/caixa_validator.dart`

### Serviços Utilizados
- `ContaBancariaService` - Para buscar contas (não mais necessário na abertura)
- `CicloCaixaService` - Para abrir/fechar caixa
- `ConfiguracaoRestauranteService` - Para buscar configuração de exibição

---

**Última atualização:** Data da criação deste documento
**Status:** Aguardando implementação no frontend

