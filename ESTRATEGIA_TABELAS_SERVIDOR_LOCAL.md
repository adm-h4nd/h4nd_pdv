# 📊 Estratégia: Tabelas no Servidor Local

## 🎯 Princípio Fundamental

**NÃO precisamos copiar todas as tabelas!**

O servidor local precisa apenas de:
1. **Dados de leitura** necessários para o PDV funcionar no dia
2. **Dados de escrita** criados durante o dia (para sincronizar depois)

---

## 📋 Categorização das Tabelas

### 🟢 **CATEGORIA 1: Cache de Leitura (Sincronizar no início do dia)**

Dados que o PDV precisa **ler** mas não modifica. Carregados uma vez no início do dia.

#### 1.1. Produtos e Catálogo
- ✅ `Produto` (apenas produtos ativos e vendáveis)
- ✅ `ProdutoVariacao`
- ✅ `ProdutoVariacaoValor`
- ✅ `ProdutoAtributo`
- ✅ `ProdutoComposicao`
- ✅ `ExibicaoProduto` (categorias/grupos)
- ✅ `ProdutoExibicao` (relacionamento produto-categoria)
- ✅ `Atributo` (atributos globais)
- ✅ `AtributoValor` (valores dos atributos)
- ✅ `GrupoProduto`
- ✅ `SubgrupoProduto`
- ✅ `UnidadeMedida`
- ✅ `UnidadeMedidaConversao`
- ✅ `ProdutoUnidadeConversao`
- ✅ `ComboRegra` (se usar combos)
- ✅ `ComboRegraOpcoes`
- ✅ `ComboRegraOpcoesVariacoes`

**Estratégia:**
- Sincronizar apenas produtos `isAtivo = true` e `isVendavel = true`
- Incluir todas as variações, atributos e composições relacionadas
- Atualizar cache quando produtos mudarem na nuvem

#### 1.2. Configurações e Estrutura
- ✅ `Empresa` (dados básicos da empresa)
- ✅ `ConfiguracaoRestaurante` (se módulo restaurante)
- ✅ `Mesa` (mesas disponíveis)
- ✅ `Comanda` (comandas disponíveis)
- ✅ `LayoutMapaMesas` (layout visual das mesas)
- ✅ `Usuario` (usuários que podem usar o PDV)
- ✅ `Perfil` (perfis de acesso)
- ✅ `PermissaoPerfil` (permissões)

**Estratégia:**
- Sincronizar apenas dados necessários para operação
- Não precisa de histórico completo

#### 1.3. Estoque (Snapshot do dia)
- ✅ `ProdutoEstoque` (estoque atual de cada produto)
- ✅ `SnapshotEstoque` (foto do estoque no início do dia)

**Estratégia:**
- Carregar snapshot do estoque no início do dia
- Atualizar conforme vendas acontecem (localmente)
- Sincronizar movimentações quando voltar online

#### 1.4. Precificação
- ✅ `ProdutoPrecificacao` (regras de preço)
- ⚠️ `ProdutoPrecoHistorico` (opcional, apenas se necessário)

**Estratégia:**
- Carregar regras de precificação ativas
- Calcular preços localmente quando necessário

---

### 🟡 **CATEGORIA 2: Dados de Escrita (Criar localmente, sincronizar depois)**

Dados que o PDV **cria/modifica** durante o dia. Salvos localmente primeiro, sincronizados depois.

#### 2.1. Pedidos e Vendas
- ✅ `Pedido` (pedidos criados no dia)
- ✅ `ItemPedido` (itens dos pedidos)
- ✅ `ItemPedidoComponenteRemovido` (componentes removidos)
- ✅ `Venda` (vendas finalizadas)
- ✅ `PagamentoPedido` (pagamentos de pedidos)
- ✅ `PagamentoVenda` (pagamentos de vendas)

**Estratégia:**
- Criar localmente com ID temporário (UUID)
- Marcar como `sincronizado = false`
- Enviar para nuvem quando tiver internet
- Atualizar com ID real após sincronização

#### 2.2. Movimentações de Estoque
- ✅ `MovimentacaoEstoque` (movimentações do dia)
- ✅ `TransacaoEstoque` (transações)
- ✅ `ItemTransacaoEstoque` (itens das transações)

**Estratégia:**
- Registrar movimentações localmente
- Atualizar `ProdutoEstoque` localmente (cache)
- Sincronizar com nuvem quando tiver internet

#### 2.3. Notas Fiscais (se gerar localmente)
- ✅ `NotaFiscal` (notas geradas)
- ✅ `NotaFiscalItem` (itens das notas)
- ⚠️ `NotaFiscalHistorico` (opcional)

**Estratégia:**
- Gerar notas localmente se possível
- Sincronizar com nuvem para validação/emissão

---

### 🔴 **CATEGORIA 3: NÃO Precisa no Servidor Local**

Dados que o PDV **não precisa** para funcionar no dia.

#### 3.1. Dados Históricos
- ❌ `ProdutoPrecoHistorico` (histórico completo)
- ❌ `NotaFiscalHistorico` (histórico completo)
- ❌ Vendas de dias anteriores (apenas do dia atual)

#### 3.2. Dados Administrativos
- ❌ `Organizacao` (dados completos)
- ❌ `Pessoa` (clientes completos, apenas IDs necessários)
- ❌ `Contato` (contatos completos)
- ❌ `Endereco` (endereços completos)
- ❌ `Recurso` (recursos do sistema)
- ❌ `GrupoRecurso` (grupos de recursos)
- ❌ `RefreshToken` (tokens de autenticação)

#### 3.3. Módulos Não Usados no PDV
- ❌ `OrdemProducao` (se PDV não gerencia produção)
- ❌ `EtapaProducao`
- ❌ `EtapaOrdemProducao`
- ❌ `ItemConsumoProducao`
- ❌ `ItemProducaoGerado`
- ❌ `FiguraFiscal` (se não gerar notas no PDV)
- ❌ `ProdutoImpactoCascata` (cálculos complexos)
- ❌ `ProdutoAlerta` (alertas administrativos)
- ❌ `ConfiguracaoAlerta`

#### 3.4. Dados de Relatórios
- ❌ Tabelas de relatórios (são consultas, não dados)

---

## 🏗️ Estrutura do Banco Local

### Tabelas de Cache (Leitura)

```sql
-- Produtos (simplificado, apenas campos necessários)
CREATE TABLE produtos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  sku TEXT,
  tipo TEXT,
  preco_venda REAL,
  preco_custo REAL,
  is_controla_estoque INTEGER,
  unidade_base TEXT,
  tem_variacoes INTEGER,
  tem_composicao INTEGER,
  -- ... campos essenciais apenas
  sincronizado_em DATETIME,
  versao INTEGER
);

-- Variações de produtos
CREATE TABLE produto_variacoes_cache (
  id TEXT PRIMARY KEY,
  produto_id TEXT NOT NULL,
  nome TEXT NOT NULL,
  preco_adicional REAL,
  FOREIGN KEY(produto_id) REFERENCES produtos_cache(id)
);

-- Atributos e valores (cache)
CREATE TABLE atributos_cache (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  tipo_selecao TEXT
);

CREATE TABLE atributo_valores_cache (
  id TEXT PRIMARY KEY,
  atributo_id TEXT NOT NULL,
  nome TEXT NOT NULL,
  FOREIGN KEY(atributo_id) REFERENCES atributos_cache(id)
);

-- Estoque (snapshot do dia)
CREATE TABLE estoque_cache (
  produto_id TEXT PRIMARY KEY,
  quantidade REAL NOT NULL,
  atualizado_em DATETIME,
  FOREIGN KEY(produto_id) REFERENCES produtos_cache(id)
);

-- Mesas/Comandas (cache)
CREATE TABLE mesas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  -- ... campos essenciais
);

CREATE TABLE comandas_cache (
  id TEXT PRIMARY KEY,
  numero TEXT NOT NULL,
  status TEXT,
  -- ... campos essenciais
);
```

### Tabelas de Escrita (Pendentes de Sync)

```sql
-- Pedidos criados localmente
CREATE TABLE pedidos_local (
  id_local TEXT PRIMARY KEY,  -- UUID gerado localmente
  id_remoto TEXT,              -- Preenchido após sync
  numero TEXT,
  tipo TEXT,
  status TEXT,
  mesa_id TEXT,
  comanda_id TEXT,
  cliente_id TEXT,
  total REAL,
  criado_em DATETIME,
  sincronizado INTEGER DEFAULT 0,
  tentativas_sync INTEGER DEFAULT 0,
  ultimo_erro TEXT,
  dados_json TEXT  -- JSON completo do pedido (backup)
);

-- Itens de pedidos
CREATE TABLE pedido_itens_local (
  id TEXT PRIMARY KEY,
  pedido_id_local TEXT NOT NULL,
  produto_id TEXT NOT NULL,
  produto_variacao_id TEXT,
  quantidade REAL NOT NULL,
  preco_unitario REAL NOT NULL,
  total REAL NOT NULL,
  FOREIGN KEY(pedido_id_local) REFERENCES pedidos_local(id_local)
);

-- Movimentações de estoque (pendentes)
CREATE TABLE movimentacoes_estoque_local (
  id_local TEXT PRIMARY KEY,
  id_remoto TEXT,
  produto_id TEXT NOT NULL,
  tipo TEXT,
  quantidade REAL NOT NULL,
  criado_em DATETIME,
  sincronizado INTEGER DEFAULT 0
);
```

---

## 🔄 Estratégia de Sincronização

### 1. **Sincronização Inicial (Início do Dia)**

**Quando:** Servidor local inicia ou botão "Carregar Dados do Dia"

**O que sincroniza:**
```javascript
async function sincronizarInicial() {
  // 1. Limpar cache antigo
  await db.produtos_cache.deleteAll();
  
  // 2. Buscar produtos ativos da nuvem
  const produtos = await apiNuvem.get('/produtos', {
    params: {
      isAtivo: true,
      isVendavel: true,
      incluirVariacoes: true,
      incluirAtributos: true,
      incluirComposicao: true
    }
  });
  
  // 3. Salvar no cache local
  await db.produtos_cache.bulkInsert(produtos);
  
  // 4. Buscar estoque atual
  const estoque = await apiNuvem.get('/estoque/snapshot');
  await db.estoque_cache.bulkInsert(estoque);
  
  // 5. Buscar mesas/comandas
  const mesas = await apiNuvem.get('/mesas');
  await db.mesas_cache.bulkInsert(mesas);
  
  // 6. Marcar timestamp de sincronização
  await db.setUltimaSync(new Date());
}
```

### 2. **Sincronização Incremental (Durante o Dia)**

**Quando:** A cada X minutos ou quando volta internet

**O que sincroniza:**
```javascript
async function sincronizarIncremental() {
  const ultimaSync = await db.getUltimaSync();
  
  // 1. Buscar produtos atualizados
  const produtosAtualizados = await apiNuvem.get('/produtos/atualizados', {
    params: { desde: ultimaSync }
  });
  await db.produtos_cache.bulkUpdate(produtosAtualizados);
  
  // 2. Buscar estoque atualizado
  const estoqueAtualizado = await apiNuvem.get('/estoque/atualizado', {
    params: { desde: ultimaSync }
  });
  await db.estoque_cache.bulkUpdate(estoqueAtualizado);
}
```

### 3. **Sincronização de Escrita (Enviar para Nuvem)**

**Quando:** Manual ou automático quando volta internet

**O que sincroniza:**
```javascript
async function sincronizarEscrita() {
  // 1. Enviar pedidos pendentes
  const pedidosPendentes = await db.pedidos_local.findAll({
    where: { sincronizado: false }
  });
  
  for (const pedido of pedidosPendentes) {
    try {
      const response = await apiNuvem.post('/pedidos', pedido);
      await db.pedidos_local.update({
        id_remoto: response.data.id,
        sincronizado: true
      }, { where: { id_local: pedido.id_local } });
    } catch (error) {
      // Log erro, incrementa tentativas
    }
  }
  
  // 2. Enviar movimentações de estoque
  const movimentacoesPendentes = await db.movimentacoes_estoque_local.findAll({
    where: { sincronizado: false }
  });
  
  for (const mov of movimentacoesPendentes) {
    try {
      await apiNuvem.post('/estoque/movimentacoes', mov);
      await db.movimentacoes_estoque_local.update({
        sincronizado: true
      }, { where: { id_local: mov.id_local } });
    } catch (error) {
      // Log erro
    }
  }
}
```

---

## 📊 Resumo: O que Vai no Servidor Local

### ✅ **SIM - Precisa no Servidor Local**

**Cache de Leitura (sincronizar no início do dia):**
- Produtos ativos e vendáveis (com variações, atributos, composições)
- Estoque atual (snapshot)
- Mesas e comandas disponíveis
- Configurações do restaurante
- Usuários e permissões básicas
- Unidades de medida
- Grupos/categorias de produtos

**Dados de Escrita (criar localmente):**
- Pedidos criados no dia
- Itens de pedidos
- Movimentações de estoque
- Pagamentos (se processar localmente)

### ❌ **NÃO - Não Precisa no Servidor Local**

- Dados históricos completos
- Dados administrativos completos
- Módulos não usados no PDV (produção, etc.)
- Relatórios
- Dados de clientes completos (apenas IDs)
- Tokens e autenticação (gerenciado pelo PDV)

---

## 🎯 Vantagens desta Estratégia

### ✅ **Simplicidade**
- Apenas ~15-20 tabelas no servidor local (vs 50+ na nuvem)
- Estrutura simplificada (apenas campos necessários)
- Fácil de manter e debugar

### ✅ **Performance**
- Banco local pequeno e rápido
- Queries simples e rápidas
- Cache otimizado para leitura

### ✅ **Manutenibilidade**
- Estrutura clara: cache vs escrita
- Fácil adicionar/remover tabelas conforme necessidade
- Backup simples (arquivo SQLite pequeno)

### ✅ **Escalabilidade**
- Pode adicionar mais tabelas conforme necessário
- Estrutura flexível para diferentes módulos

---

## 🔧 Implementação Prática

### Estrutura de Pastas do Servidor Local

```
servidor-local/
├── src/
│   ├── models/
│   │   ├── cache/          # Modelos de cache (leitura)
│   │   │   ├── produto_cache.js
│   │   │   ├── estoque_cache.js
│   │   │   └── mesa_cache.js
│   │   └── local/          # Modelos locais (escrita)
│   │       ├── pedido_local.js
│   │       └── movimentacao_local.js
│   ├── sync/
│   │   ├── sync_reader.js  # Sincronização de leitura
│   │   └── sync_writer.js  # Sincronização de escrita
│   └── api/
│       └── routes/         # Rotas da API
└── database/
    └── schema.sql          # Schema do banco local
```

---

## 📋 Checklist de Implementação

### Fase 1: Estrutura Base
- [ ] Criar schema do banco local (apenas tabelas necessárias)
- [ ] Definir quais campos de cada tabela são necessários
- [ ] Criar modelos de dados simplificados

### Fase 2: Sincronização de Leitura
- [ ] Endpoint para sincronização inicial
- [ ] Endpoint para sincronização incremental
- [ ] Lógica de cache de produtos
- [ ] Lógica de cache de estoque
- [ ] Lógica de cache de mesas/comandas

### Fase 3: Operações de Escrita
- [ ] Criar pedidos localmente
- [ ] Registrar movimentações localmente
- [ ] Marcar como pendente de sincronização

### Fase 4: Sincronização de Escrita
- [ ] Enviar pedidos pendentes
- [ ] Enviar movimentações pendentes
- [ ] Tratamento de erros e retry
- [ ] Resolução de conflitos

---

## ❓ Perguntas para Decidir

1. **Quais módulos o PDV realmente usa?**
   - Apenas vendas?
   - Restaurante (mesas/comandas)?
   - Produção?
   - Fiscal?

2. **Precisa de histórico no PDV?**
   - Apenas do dia atual?
   - Últimos X dias?

3. **Como lidar com produtos desativados?**
   - Remover do cache imediatamente?
   - Manter até fim do dia?

4. **E se produto mudar de preço durante o dia?**
   - Atualizar cache automaticamente?
   - Usar preço do momento da venda (snapshot)?

---

## 🎯 Conclusão

**Não precisa copiar todas as tabelas!**

Apenas:
- ✅ **Cache de leitura**: Produtos, estoque, configurações (sincronizar no início do dia)
- ✅ **Dados de escrita**: Pedidos, movimentações (criar localmente, sincronizar depois)

**Resultado:** Servidor local simples, rápido e fácil de manter! 🚀
