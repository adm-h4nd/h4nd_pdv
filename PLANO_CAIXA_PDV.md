# Plano de Implementação - Módulo de Caixa no PDV

## 📋 Contexto e Requisitos

### Estrutura Backend
- **Caixa** (cadastro): Caixa físico que pode ter múltiplos ciclos
- **CicloCaixa**: Ciclo de abertura/fechamento (pode ter múltiplos abertos simultaneamente)
- **MovimentacaoCaixa**: Registra entradas/saídas, aponta para `CicloCaixa` e `PDV`

### Regras de Negócio
1. **Identificação obrigatória**: PDV e Caixa devem ser configurados após login
2. **Abertura obrigatória**: Não pode vender sem ciclo aberto
3. **Movimentações automáticas**: Cada pagamento registrado cria `MovimentacaoCaixa`
4. **Menu de caixa**: Opções para Crédito (reforço) e Débito (sangria)
5. **Fechamento**: Contar formas de pagamento recebidas (pode ser só no retaguarda)

---

## 🎯 FATIAS DE IMPLEMENTAÇÃO

### **FATIA 1: Configuração Inicial do PDV e Caixa**
**Objetivo**: Tela obrigatória após login para identificar PDV e Caixa

**Funcionalidades**:
- Tela modal/dialog que aparece após login se não houver configuração
- Buscar lista de PDVs da empresa (GET `/api/PDV/empresa/{empresaId}`)
- Buscar lista de Caixas da empresa (GET `/api/Caixa/empresa/{empresaId}` - precisa criar endpoint)
- Seleção de PDV (dropdown/lista)
- Seleção de Caixa (dropdown/lista)
- Salvar configuração localmente (SharedPreferences/Storage)
- Validação: ambos obrigatórios

**Arquivos a criar**:
- `lib/screens/configuracao/pdv_caixa_config_screen.dart`
- `lib/data/services/core/pdv_service.dart` (se não existir)
- `lib/data/services/core/caixa_service.dart` (se não existir)
- `lib/data/models/core/caixa/pdv_dto.dart`
- `lib/data/models/core/caixa/caixa_dto.dart`
- `lib/data/repositories/configuracao_pdv_caixa_repository.dart` (local storage)

**Endpoints necessários**:
- ✅ `GET /api/PDV/empresa/{empresaId}` (já existe)
- ✅ `POST /api/Caixa/search` com filtro `EmpresaId` (já existe - usar este)

---

### **FATIA 2: Tela de Configuração (Consultar/Alterar)**
**Objetivo**: Permitir alterar/consultar configuração de PDV e Caixa

**Funcionalidades**:
- Acessível via menu/configurações
- Exibir PDV e Caixa atuais
- Permitir alterar ambos
- Validação: se alterar caixa, verificar se há ciclo aberto no caixa antigo
- Salvar nova configuração

**Arquivos**:
- Reutilizar tela da FATIA 1 ou criar versão editável
- `lib/screens/configuracao/pdv_caixa_config_screen.dart` (reutilizar)

---

### **FATIA 3: Validação de Ciclo Aberto e Bloqueio de Vendas**
**Objetivo**: Impedir vendas se não houver ciclo aberto

**Funcionalidades**:
- Ao iniciar tela de vendas, verificar se há ciclo aberto
- Endpoint: `GET /api/CicloCaixa/caixa/{caixaId}` com filtro de status=Aberto
- Se não houver ciclo aberto:
  - Bloquear tela de vendas
  - Mostrar mensagem: "Caixa não está aberto. É necessário abrir o caixa antes de iniciar as vendas."
  - Botão para abrir caixa (leva para FATIA 4)

**Arquivos a criar/modificar**:
- `lib/data/services/core/ciclo_caixa_service.dart`
- `lib/data/models/core/caixa/ciclo_caixa_dto.dart`
- Modificar tela principal de vendas para validar antes de permitir vender

**Endpoints necessários**:
- ❓ `GET /api/CicloCaixa/caixa/{caixaId}` com filtro status=Aberto (verificar se existe ou usar search)

---

### **FATIA 4: Tela de Abertura de Caixa**
**Objetivo**: Permitir abrir ciclo de caixa (obrigatório antes de vender)

**Funcionalidades**:
- Tela modal/dialog para abrir caixa
- Campos:
  - Caixa (já selecionado da configuração, mas pode mostrar info)
  - Valor inicial (decimal, pode ser zero)
  - Conta origem (buscar contas internas - GET `/api/ContaBancaria/empresa/{empresaId}/internas`)
  - Observações (opcional)
- Validações:
  - Valor inicial >= 0
  - Conta origem obrigatória e deve ser conta interna
- Chamar endpoint: `POST /api/CicloCaixa/abrir?pdvId={pdvId}`
- Após sucesso, permitir vendas

**Arquivos a criar**:
- `lib/screens/caixa/abrir_caixa_screen.dart`
- `lib/data/models/core/caixa/abrir_ciclo_caixa_dto.dart`
- Adicionar método em `ciclo_caixa_service.dart`

**Endpoints necessários**:
- ✅ `POST /api/CicloCaixa/abrir?pdvId={pdvId}` (já existe)
- ✅ `POST /api/ContaBancaria/search` com filtro `Tipo=Interna` e `EmpresaId` (já existe - usar este)

---

### **FATIA 5: Criação Automática de MovimentacaoCaixa ao Registrar Pagamento**
**Objetivo**: Criar movimentação automaticamente quando pagamento é confirmado

**Funcionalidades**:
- Ao registrar pagamento com sucesso, criar `MovimentacaoCaixa`
- Dados necessários:
  - `CicloCaixaId`: ID do ciclo aberto atual
  - `PDVId`: ID do PDV configurado
  - `Tipo`: Entrada (TipoMovimentacao.Entrada)
  - `Valor`: Valor do pagamento
  - `FormaPagamentoId`: ID da forma de pagamento usada
  - `PagamentoVendaId`: ID do pagamento da venda (opcional, mas recomendado)
  - `UsuarioId`: ID do usuário logado
  - `DataHora`: Data/hora atual
- Endpoint: `POST /api/MovimentacaoCaixa` (precisa criar no backend)

**Arquivos a criar/modificar**:
- `lib/data/services/core/movimentacao_caixa_service.dart`
- `lib/data/models/core/caixa/movimentacao_caixa_dto.dart`
- Modificar `venda_service.dart` ou `payment_flow_provider.dart` para chamar após pagamento confirmado

**Endpoints necessários**:
- ❓ `POST /api/MovimentacaoCaixa` (precisa criar no backend OU criar automaticamente no backend ao registrar pagamento)

**Observação**: 
- **Decisão**: Criar movimentação automaticamente no backend quando `PagamentoVenda` é criado
- O backend já cria `MovimentacaoCaixa` automaticamente em:
  - Abertura de ciclo (valor inicial)
  - Reforço (entrada)
  - Sangria (saída)
- **Sugestão**: Criar automaticamente no backend ao registrar pagamento, passando `CicloCaixaId` e `PDVId` no payload
- Se não for automático, criar endpoint `POST /api/MovimentacaoCaixa` no backend

---

### **FATIA 6: Menu de Opções de Caixa (Crédito/Débito)**
**Objetivo**: Permitir fazer reforço (crédito) e sangria (débito)

**Funcionalidades**:
- Menu/opção acessível durante operação
- **Crédito (Reforço)**:
  - Tela modal para adicionar dinheiro ao caixa
  - Campos:
    - Valor (obrigatório, > 0)
    - Conta origem (obrigatória, conta interna)
    - Observações (opcional)
  - Endpoint: `POST /api/CicloCaixa/reforco?pdvId={pdvId}`
- **Débito (Sangria)**:
  - Tela modal para retirar dinheiro do caixa
  - Campos:
    - Valor (obrigatório, > 0)
    - Conta destino (obrigatória, conta bancária)
    - Observações (opcional)
  - Endpoint: `POST /api/CicloCaixa/sangria?pdvId={pdvId}`
- Validações:
  - Deve haver ciclo aberto
  - Valor deve ser > 0
  - Conta deve existir e estar ativa

**Arquivos a criar**:
- `lib/screens/caixa/reforco_caixa_screen.dart`
- `lib/screens/caixa/sangria_caixa_screen.dart`
- `lib/data/models/core/caixa/reforco_ciclo_caixa_dto.dart`
- `lib/data/models/core/caixa/sangria_ciclo_caixa_dto.dart`
- Adicionar métodos em `ciclo_caixa_service.dart`

**Endpoints necessários**:
- ✅ `POST /api/CicloCaixa/reforco?pdvId={pdvId}` (já existe)
- ✅ `POST /api/CicloCaixa/sangria?pdvId={pdvId}` (já existe)

---

### **FATIA 7: Tela de Fechamento de Caixa (Opcional - Pode ser só no retaguarda)**
**Objetivo**: Permitir fechar ciclo de caixa no PDV (se necessário)

**Funcionalidades**:
- Tela para contar valores por forma de pagamento
- Campos:
  - Valor Dinheiro Contado
  - Valor Cartão Crédito Contado
  - Valor Cartão Débito Contado
  - Valor PIX Contado
  - Valor Outros Contado
  - Observações
- Endpoint: `POST /api/CicloCaixa/{cicloCaixaId}/fechar`
- Após fechamento, bloquear vendas novamente

**Arquivos a criar**:
- `lib/screens/caixa/fechar_caixa_screen.dart`
- `lib/data/models/core/caixa/fechar_ciclo_caixa_dto.dart`
- Adicionar método em `ciclo_caixa_service.dart`

**Endpoints necessários**:
- ✅ `POST /api/CicloCaixa/{cicloCaixaId}/fechar` (já existe)

**Observação**: Esta fatia pode ser opcional se o fechamento for feito apenas no retaguarda.

---

## 📝 Endpoints do Backend - Status

### ✅ Já Existem
- `GET /api/PDV/empresa/{empresaId}` - Lista PDVs da empresa
- `POST /api/CicloCaixa/abrir?pdvId={pdvId}` - Abre ciclo
- `POST /api/CicloCaixa/reforco?pdvId={pdvId}` - Reforço
- `POST /api/CicloCaixa/sangria?pdvId={pdvId}` - Sangria
- `POST /api/CicloCaixa/{cicloCaixaId}/fechar` - Fecha ciclo
- `GET /api/CicloCaixa/caixa/{caixaId}` - Lista ciclos de um caixa

### ❓ Precisam Verificar/Criar
- ✅ `POST /api/Caixa/search` com filtro `EmpresaId` - Lista caixas da empresa (já existe)
- ✅ `POST /api/ContaBancaria/search` com filtro `Tipo=Interna` e `EmpresaId` - Lista contas internas (já existe)
- ❓ `POST /api/MovimentacaoCaixa` - Cria movimentação manualmente OU criar automaticamente no backend ao registrar pagamento
  - **Recomendação**: Criar automaticamente no backend quando `PagamentoVenda` é registrado, passando `CicloCaixaId` e `PDVId` no payload do pagamento

---

## 🔄 Fluxo Completo

1. **Login** → Verifica configuração → Se não houver, mostra FATIA 1
2. **Configuração salva** → Verifica ciclo aberto → Se não houver, mostra FATIA 4
3. **Ciclo aberto** → Permite vendas
4. **Venda processada** → Pagamento confirmado → Cria MovimentacaoCaixa (FATIA 5)
5. **Menu Caixa** → Opções de Crédito/Débito (FATIA 6)
6. **Fechamento** → (Opcional - FATIA 7 ou só no retaguarda)

---

## 🎨 Considerações de UI/UX

- Todas as telas devem seguir o padrão visual do PDV
- Usar componentes reutilizáveis (dialogs, forms, etc.)
- Feedback visual claro (loading, sucesso, erro)
- Validações em tempo real
- Mensagens de erro claras e objetivas

---

## 📦 Estrutura de Pastas Sugerida

```
lib/
├── data/
│   ├── models/
│   │   └── core/
│   │       └── caixa/
│   │           ├── pdv_dto.dart
│   │           ├── caixa_dto.dart
│   │           ├── ciclo_caixa_dto.dart
│   │           ├── movimentacao_caixa_dto.dart
│   │           ├── abrir_ciclo_caixa_dto.dart
│   │           ├── reforco_ciclo_caixa_dto.dart
│   │           ├── sangria_ciclo_caixa_dto.dart
│   │           └── fechar_ciclo_caixa_dto.dart
│   ├── services/
│   │   └── core/
│   │       ├── pdv_service.dart
│   │       ├── caixa_service.dart
│   │       ├── ciclo_caixa_service.dart
│   │       └── movimentacao_caixa_service.dart
│   └── repositories/
│       └── configuracao_pdv_caixa_repository.dart
└── screens/
    ├── configuracao/
    │   └── pdv_caixa_config_screen.dart
    └── caixa/
        ├── abrir_caixa_screen.dart
        ├── reforco_caixa_screen.dart
        ├── sangria_caixa_screen.dart
        └── fechar_caixa_screen.dart
```

---

## ✅ Checklist de Validação

- [ ] Configuração de PDV e Caixa salva localmente
- [ ] Validação de ciclo aberto antes de permitir vendas
- [ ] Abertura de caixa funcional
- [ ] Movimentações criadas automaticamente ao pagar
- [ ] Reforço e sangria funcionais
- [ ] Fechamento funcional (se implementado)
- [ ] Tratamento de erros adequado
- [ ] Feedback visual em todas as operações
- [ ] Validações de negócio implementadas

