# 📱 Arquitetura de Sincronização Offline - MX Cloud PDV

## 🎯 Objetivo

Implementar sincronização offline para permitir que o PDV funcione sem conexão com a internet, armazenando produtos e vendas localmente e sincronizando quando houver conexão.

---

## 🗄️ 1. Banco de Dados Local

### Escolha: **Drift (SQLite)**

**Por quê?**
- ✅ Type-safe queries (menos erros)
- ✅ Migrations automáticas
- ✅ Performance excelente
- ✅ Suporte a relacionamentos complexos
- ✅ Integração fácil com Flutter

**Dependência:**
```yaml
dependencies:
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.1
  path: ^1.8.3
```

---

## 📊 2. Estrutura de Dados Locais

### 2.1. Produtos Completos

#### Tabela: `produtos_locais`
Armazena dados básicos dos produtos disponíveis para venda.

```dart
- id (TEXT PRIMARY KEY)
- nome (TEXT NOT NULL)
- descricao (TEXT)
- sku (TEXT)
- referencia (TEXT)
- tipo (TEXT) // TipoProduto enum
- precoVenda (REAL)
- precoCusto (REAL)
- isControlaEstoque (INTEGER) // BOOLEAN
- isControlaEstoquePorVariacao (INTEGER)
- unidadeBase (TEXT)
- temVariacoes (INTEGER)
- temComposicao (INTEGER)
- tipoRepresentacao (INTEGER) // TipoRepresentacaoVisual enum
- icone (TEXT)
- cor (TEXT)
- imagemFileName (TEXT)
- ultimaSincronizacao (INTEGER) // DateTime timestamp
- isAtivo (INTEGER)
```

#### Tabela: `produto_atributos_locais`
Armazena atributos de cada produto.

```dart
- id (TEXT PRIMARY KEY)
- produtoId (TEXT NOT NULL, FK)
- nome (TEXT NOT NULL)
- tipoSelecao (TEXT) // TipoSelecaoAtributo enum
- isObrigatorio (INTEGER)
- ordem (INTEGER)
- FOREIGN KEY(produtoId) REFERENCES produtos_locais(id) ON DELETE CASCADE
```

#### Tabela: `produto_atributo_valores_locais`
Armazena valores possíveis de cada atributo.

```dart
- id (TEXT PRIMARY KEY)
- produtoAtributoId (TEXT NOT NULL, FK)
- nome (TEXT NOT NULL)
- precoAdicional (REAL)
- ordem (INTEGER)
- FOREIGN KEY(produtoAtributoId) REFERENCES produto_atributos_locais(id) ON DELETE CASCADE
```

#### Tabela: `produto_variacoes_locais`
Armazena variações de produtos.

```dart
- id (TEXT PRIMARY KEY)
- produtoId (TEXT NOT NULL, FK)
- nome (TEXT NOT NULL)
- precoAdicional (REAL)
- sku (TEXT)
- ordem (INTEGER)
- FOREIGN KEY(produtoId) REFERENCES produtos_locais(id) ON DELETE CASCADE
```

#### Tabela: `produto_variacao_valores_locais`
Armazena valores de variações (ex: Tamanho P, M, G).

```dart
- id (TEXT PRIMARY KEY)
- produtoVariacaoId (TEXT NOT NULL, FK)
- atributoValorId (TEXT NOT NULL)
- FOREIGN KEY(produtoVariacaoId) REFERENCES produto_variacoes_locais(id) ON DELETE CASCADE
```

### 2.2. Vendas Locais (Pedidos Offline)

#### Tabela: `pedidos_locais`
Armazena pedidos criados offline.

```dart
- idLocal (TEXT PRIMARY KEY) // UUID gerado localmente
- idRemoto (TEXT) // ID retornado pelo servidor após sincronização (NULL até sincronizar)
- numero (TEXT) // Número do pedido (gerado localmente ou pelo servidor)
- tipo (TEXT) // TipoPedido enum: "Orcamento" ou "Venda"
- status (TEXT) // StatusPedido enum
- tipoContexto (TEXT) // TipoContextoPedido enum
- mesaId (TEXT)
- comandaId (TEXT)
- veiculoId (TEXT)
- clienteId (TEXT)
- clienteNome (TEXT NOT NULL)
- clienteCPF (TEXT)
- clienteCNPJ (TEXT)
- vendedorId (TEXT)
- vendedorNome (TEXT)
- dataPedido (INTEGER) // DateTime timestamp
- dataPrevisaoEntrega (INTEGER)
- subtotal (REAL)
- descontoTotal (REAL)
- percentualDesconto (REAL)
- acrescimoTotal (REAL)
- impostosTotal (REAL)
- freteTotal (REAL)
- valorTotal (REAL)
- observacoes (TEXT)
- isSincronizado (INTEGER) // BOOLEAN: false = pendente, true = sincronizado
- tentativasSincronizacao (INTEGER) // Contador de tentativas
- ultimaTentativaSincronizacao (INTEGER) // DateTime timestamp
- erroSincronizacao (TEXT) // Última mensagem de erro
- criadoEm (INTEGER) // DateTime timestamp local
- atualizadoEm (INTEGER) // DateTime timestamp local
```

#### Tabela: `pedido_itens_locais`
Armazena itens dos pedidos offline.

```dart
- idLocal (TEXT PRIMARY KEY) // UUID gerado localmente
- idRemoto (TEXT) // ID retornado pelo servidor
- pedidoIdLocal (TEXT NOT NULL, FK)
- produtoId (TEXT NOT NULL)
- produtoNome (TEXT NOT NULL) // Snapshot
- produtoSKU (TEXT) // Snapshot
- produtoVariacaoId (TEXT)
- produtoVariacaoNome (TEXT) // Snapshot
- quantidade (REAL NOT NULL)
- precoUnitario (REAL NOT NULL) // Snapshot do preço no momento da venda
- desconto (REAL)
- percentualDesconto (REAL)
- acrescimo (REAL)
- valorTotal (REAL NOT NULL)
- observacoes (TEXT)
- ordem (INTEGER)
- FOREIGN KEY(pedidoIdLocal) REFERENCES pedidos_locais(idLocal) ON DELETE CASCADE
```

#### Tabela: `pedido_item_atributos_locais`
Armazena atributos selecionados para cada item.

```dart
- idLocal (TEXT PRIMARY KEY)
- pedidoItemIdLocal (TEXT NOT NULL, FK)
- produtoAtributoId (TEXT NOT NULL)
- produtoAtributoNome (TEXT NOT NULL) // Snapshot
- produtoAtributoValorId (TEXT NOT NULL)
- produtoAtributoValorNome (TEXT NOT NULL) // Snapshot
- precoAdicional (REAL)
- proporcao (REAL) // Para atributos proporcionais (ex: 0.5 = 50%)
- FOREIGN KEY(pedidoItemIdLocal) REFERENCES pedido_itens_locais(idLocal) ON DELETE CASCADE
```

#### Tabela: `sincronizacao_metadados`
Armazena metadados de sincronização.

```dart
- chave (TEXT PRIMARY KEY)
- valor (TEXT)
- atualizadoEm (INTEGER)
```

**Chaves esperadas:**
- `ultima_sincronizacao_produtos` → DateTime timestamp
- `total_produtos_sincronizados` → número de produtos
- `total_pedidos_pendentes` → número de pedidos não sincronizados

---

## 🔄 3. Fluxo de Sincronização

### 3.1. Sincronização de Produtos

**Trigger:** Botão "Sincronizar" na tela inicial

**Fluxo:**
1. Usuário clica em "Sincronizar"
2. Mostrar loading/dialog de progresso
3. Buscar todos os produtos disponíveis para venda da API:
   - Endpoint: `GET /api/core/produtos/completos?isVendavel=true&isAtivo=true`
   - Ou endpoint específico para sincronização: `GET /api/core/produtos/sincronizacao`
4. Para cada produto:
   - Buscar dados completos (atributos, variações, valores)
   - Salvar/atualizar no banco local
5. Limpar produtos antigos que não estão mais disponíveis (opcional)
6. Atualizar `sincronizacao_metadados`
7. Mostrar mensagem de sucesso/erro

**Considerações:**
- ⚠️ **Tamanho dos dados**: Se houver muitos produtos, considerar paginação ou endpoint específico de sincronização
- ⚠️ **Tempo de sincronização**: Pode demorar alguns minutos se houver muitos produtos
- ✅ **Incremental**: Futuramente, implementar sincronização incremental (apenas produtos atualizados desde última sync)

### 3.2. Criação de Pedidos Offline

**Fluxo:**
1. Usuário cria pedido normalmente
2. Salvar no banco local (`pedidos_locais`) com `isSincronizado = false`
3. Gerar `idLocal` (UUID)
4. Gerar `numero` localmente (ex: "OFF-001", "OFF-002")
5. Continuar funcionamento normalmente

### 3.3. Sincronização de Pedidos

**Trigger:** 
- Automático: Ao voltar online (detectar conexão)
- Manual: Botão "Sincronizar Pedidos Pendentes"

**Fluxo:**
1. Buscar todos os pedidos com `isSincronizado = false`
2. Para cada pedido:
   - Enviar para API: `POST /api/core/pedidos`
   - Se sucesso:
     - Atualizar `idRemoto` com ID retornado
     - Atualizar `numero` se o servidor gerar um novo
     - Marcar `isSincronizado = true`
     - Limpar `erroSincronizacao`
   - Se erro:
     - Incrementar `tentativasSincronizacao`
     - Salvar `erroSincronizacao`
     - Atualizar `ultimaTentativaSincronizacao`
3. Mostrar resumo: "X pedidos sincronizados, Y com erro"

**Tratamento de Erros:**
- Erro de rede: Tentar novamente depois
- Erro de validação: Mostrar erro específico ao usuário
- Conflito (pedido já existe): Resolver conflito ou marcar como duplicado

---

## 🏗️ 4. Estrutura de Arquivos

```
lib/
├── data/
│   ├── database/
│   │   ├── app_database.dart          # Classe principal do Drift
│   │   ├── daos/
│   │   │   ├── produto_local_dao.dart
│   │   │   └── pedido_local_dao.dart
│   │   └── tables/
│   │       ├── produtos_locais.dart
│   │       ├── produto_atributos_locais.dart
│   │       ├── produto_atributo_valores_locais.dart
│   │       ├── produto_variacoes_locais.dart
│   │       ├── produto_variacao_valores_locais.dart
│   │       ├── pedidos_locais.dart
│   │       ├── pedido_itens_locais.dart
│   │       ├── pedido_item_atributos_locais.dart
│   │       └── sincronizacao_metadados.dart
│   ├── repositories/
│   │   ├── produto_local_repository.dart
│   │   └── pedido_local_repository.dart
│   └── services/
│       ├── sync/
│       │   ├── produto_sync_service.dart
│       │   └── pedido_sync_service.dart
│       └── local/
│           ├── produto_local_service.dart
│           └── pedido_local_service.dart
├── domain/
│   └── usecases/
│       ├── sync/
│       │   ├── sync_produtos_usecase.dart
│       │   └── sync_pedidos_usecase.dart
│       └── local/
│           ├── get_produtos_locais_usecase.dart
│           └── criar_pedido_local_usecase.dart
└── presentation/
    └── providers/
        └── sync_provider.dart          # Provider para gerenciar estado de sincronização
```

---

## 🎨 5. Interface do Usuário

### 5.1. Botão de Sincronizar na Home

**Localização:** Tela inicial (`home_screen.dart`)

**Design:**
- Botão destacado na seção "Ações Rápidas"
- Ícone: `Icons.sync` ou `Icons.cloud_download`
- Texto: "Sincronizar Produtos"
- Badge: Mostrar número de pedidos pendentes (se houver)

**Comportamento:**
- Ao clicar: Abrir dialog de sincronização
- Mostrar progresso: "Sincronizando produtos... (X/Y)"
- Ao concluir: Mostrar resumo e fechar

### 5.2. Indicador de Status

**Localização:** Header da home (onde está "Online")

**Estados:**
- 🟢 **Online**: Todos os pedidos sincronizados
- 🟡 **Online com Pendências**: Há pedidos não sincronizados
- 🔴 **Offline**: Sem conexão

### 5.3. Dialog de Sincronização

```
┌─────────────────────────────────┐
│  Sincronizar Produtos           │
├─────────────────────────────────┤
│  [████████░░] 80%               │
│                                 │
│  Sincronizando produtos...      │
│  80 de 100 produtos             │
│                                 │
│  [Cancelar]                     │
└─────────────────────────────────┘
```

---

## 📋 6. Checklist de Implementação

### Fase 1: Setup Inicial
- [ ] Adicionar dependências (Drift, path_provider)
- [ ] Criar estrutura de pastas
- [ ] Configurar AppDatabase

### Fase 2: Modelos de Dados Locais
- [ ] Criar tabelas do Drift para produtos
- [ ] Criar tabelas do Drift para pedidos
- [ ] Criar DAOs (Data Access Objects)
- [ ] Criar repositories

### Fase 3: Serviços Locais
- [ ] Implementar `ProdutoLocalService`
- [ ] Implementar `PedidoLocalService`
- [ ] Testes básicos de CRUD

### Fase 4: Sincronização de Produtos
- [ ] Criar endpoint na API (se necessário)
- [ ] Implementar `ProdutoSyncService`
- [ ] Implementar botão de sincronizar na home
- [ ] Dialog de progresso
- [ ] Tratamento de erros

### Fase 5: Vendas Offline
- [ ] Modificar criação de pedidos para salvar localmente
- [ ] Implementar `PedidoSyncService`
- [ ] Sincronização automática ao voltar online
- [ ] Tratamento de conflitos

### Fase 6: UI/UX
- [ ] Indicador de status na home
- [ ] Lista de pedidos pendentes
- [ ] Notificações de sincronização
- [ ] Feedback visual de operações offline

---

## 🤔 7. Decisões a Tomar

### 7.1. Endpoint de Sincronização de Produtos
**Opção A:** Usar endpoint existente com filtros
```
GET /api/core/produtos/completos?isVendavel=true&isAtivo=true
```

**Opção B:** Criar endpoint específico para sincronização
```
GET /api/core/produtos/sincronizacao
```
- Retorna apenas dados necessários
- Pode incluir metadados (total, versão, etc.)
- Mais eficiente

**Recomendação:** Opção B (endpoint específico)

### 7.2. Estratégia de Limpeza de Produtos Antigos
**Opção A:** Limpar todos e recriar (mais simples)
**Opção B:** Comparar e atualizar apenas mudanças (mais eficiente)

**Recomendação:** Opção A inicialmente, migrar para B depois

### 7.3. Sincronização Incremental de Produtos
**Implementar agora?** Não, deixar para depois
**Implementar depois?** Sim, quando houver muitos produtos

### 7.4. Tratamento de Conflitos em Pedidos
**Cenário:** Pedido criado offline, mas já existe no servidor
**Solução:** 
- Gerar número único localmente (UUID no número)
- Servidor valida e pode gerar novo número
- Ou: Detectar conflito e resolver manualmente

---

## 📝 8. Próximos Passos

1. **Revisar e aprovar esta arquitetura**
2. **Decidir sobre endpoints da API**
3. **Implementar Fase 1 e 2** (Setup + Modelos)
4. **Testar estrutura básica**
5. **Implementar sincronização de produtos**
6. **Implementar vendas offline**

---

## ❓ Perguntas para Discussão

1. **Quantos produtos esperamos ter?** (impacta estratégia de sincronização)
2. **Precisamos sincronizar imagens também?** (armazenar localmente ou sempre buscar da URL?)
3. **Como tratar produtos desativados?** (manter localmente ou remover?)
4. **Sincronização automática ao abrir o app?** (se última sync foi há mais de X horas)
5. **Precisamos de histórico de sincronizações?** (log de quando sincronizou, quantos produtos, etc.)

