# Documentação Completa - MesaDetalhesProvider

## Visão Geral

O `MesaDetalhesProvider` gerencia o estado da tela de detalhes de produtos de uma mesa ou comanda. Ele é responsável por:
- Carregar e agrupar produtos de pedidos (servidor + local)
- Gerenciar comandas quando há controle por comanda
- Atualizar vendas e pagamentos localmente
- Escutar eventos de negócio e atualizar estado em tempo real
- Evitar chamadas desnecessárias ao servidor

---

## Métodos Públicos (Getters e Setters)

### `statusVisual` (Getter)
**Linha:** 112-127

**O que faz:**
Retorna o status visual da mesa/comanda calculado dinamicamente.

**Lógica:**
1. Se há pedidos locais pendentes/sincronizando/com erro → retorna `"ocupada"`
2. Se há produtos na mesa (pedidos do servidor) → retorna `"ocupada"`
3. Caso contrário → retorna o status do servidor (`_statusMesa` ou `entidade.status`)

**Quando usar:**
Usado pela UI para exibir o status correto da mesa, considerando tanto pedidos locais quanto do servidor.

---

### `getProdutosParaAcao()`
**Linha:** 130-135

**O que faz:**
Retorna os produtos que devem ser exibidos na tela, considerando a aba selecionada.

**Lógica:**
- Se nenhuma aba está selecionada (`_abaSelecionada == null`) → retorna produtos da visão geral (`_produtosAgrupados`)
- Se há aba selecionada → retorna produtos daquela comanda específica (`_produtosPorComanda[_abaSelecionada]`)

**Quando usar:**
Usado pela UI para exibir os produtos corretos dependendo da aba selecionada (visão geral ou comanda específica).

---

### `getVendaParaAcao()`
**Linha:** 138-143

**O que faz:**
Retorna a venda que deve ser exibida na tela, considerando a aba selecionada.

**Lógica:**
- Se nenhuma aba está selecionada → retorna venda geral (`_vendaAtual`)
- Se há aba selecionada → retorna venda daquela comanda (`_vendasPorComanda[_abaSelecionada]`)

**Quando usar:**
Usado pela UI para exibir a venda correta dependendo da aba selecionada.

---

### `setAbaSelecionada(String? comandaId)`
**Linha:** 147-152

**O que faz:**
Define qual aba está selecionada (visão geral ou comanda específica).

**Parâmetros:**
- `comandaId`: ID da comanda ou `null` para visão geral

**Quando usar:**
Chamado pela UI quando o usuário seleciona uma aba diferente.

---

### `toggleHistoricoPagamentos()`
**Linha:** 155-158

**O que faz:**
Alterna o estado de expansão do histórico de pagamentos.

**Quando usar:**
Chamado pela UI quando o usuário clica para expandir/recolher o histórico de pagamentos.

---

### `loadProdutos({bool refresh = false})`
**Linha:** 873-1030

**O que faz:**
Método principal para carregar produtos agrupados da mesa/comanda. Busca pedidos do servidor e do Hive local, agrupa produtos e atualiza o estado.

**Parâmetros:**
- `refresh`: Se `true`, força recarregamento mesmo se já estiver carregando

**Lógica:**
1. **Verificações iniciais:**
   - Se já está carregando e não é refresh → retorna (evita duplicação)
   - Se venda foi finalizada → retorna sem buscar (evita chamadas desnecessárias)
   - Se entidade está livre e sem produtos → retorna sem buscar
   - Se mesa está limpa → retorna sem buscar

2. **Se é refresh:**
   - Limpa rastreamento de pedidos processados
   - Reseta flag `_vendaFinalizada`

3. **Busca dados:**
   - Busca pedidos do servidor via `_buscarPedidosServidor()`
   - Busca venda aberta se necessário
   - Processa comandas se controle é por comanda
   - Busca pedidos locais pendentes/sincronizando

4. **Agrupa produtos:**
   - Processa pedidos do servidor
   - Processa pedidos locais
   - Converte mapa para lista ordenada

5. **Atualiza estado:**
   - Atualiza `_produtosAgrupados`
   - Notifica listeners

**Quando usar:**
Chamado pela UI quando precisa carregar/recarregar produtos da mesa/comanda.

---

### `loadVendaAtual()`
**Linha:** 1214-1261

**O que faz:**
Carrega a venda atual da mesa/comanda do servidor.

**Lógica:**
1. **Verificações:**
   - Se venda foi finalizada → retorna sem buscar
   - Se mesa está limpa → retorna sem buscar

2. **Busca venda:**
   - Se é mesa → busca via `mesaService.getMesaById()` e pega `vendaAtual`
   - Se é comanda → busca via `comandaService.getComandaById()` ou `vendaService.getVendaAbertaPorComanda()`

3. **Atualiza estado:**
   - Atualiza `_vendaAtual`
   - Notifica listeners

**Quando usar:**
Chamado pela UI quando precisa carregar/recarregar a venda atual.

---

### `buscarVendaAberta()`
**Linha:** 1265-1299

**O que faz:**
Busca venda aberta para a comanda atual ou da aba selecionada.

**Lógica:**
1. **Determina comanda:**
   - Se entidade é comanda → usa `entidade.id`
   - Se há aba selecionada → usa `_abaSelecionada`
   - Caso contrário → retorna `null`

2. **Busca venda:**
   - Busca via `vendaService.getVendaAbertaPorComanda()`

3. **Atualiza estado apropriado:**
   - Se nenhuma aba selecionada → atualiza `_vendaAtual`
   - Se há aba selecionada → atualiza `_vendasPorComanda[_abaSelecionada]`

**Retorna:**
`VendaDto?` - A venda encontrada ou `null` se não encontrada

**Quando usar:**
Chamado pela UI quando precisa buscar uma venda aberta manualmente.

---

### `marcarVendaFinalizada({String? comandaId, String? mesaId})`
**Linha:** 1496-1570

**O que faz:**
Método centralizado para marcar venda como finalizada. Remove comanda específica ou limpa tudo, e dispara evento `mesaLiberada` quando apropriado.

**Parâmetros:**
- `comandaId`: ID da comanda a ser removida (opcional)
- `mesaId`: ID da mesa para disparar evento `mesaLiberada` (opcional, tenta determinar automaticamente)

**Lógica:**
1. **Determina `mesaId` se não fornecido:**
   - Se entidade é mesa → usa `entidade.id`
   - Se entidade é comanda → busca de `_vendaAtual`, `_vendasPorComanda` ou `_comandasDaMesa`

2. **Se tem `comandaId`:**
   - Remove apenas aquela comanda via `_removerComandaDaListagem()`
   - Verifica se ainda há comandas/pedidos restantes
   - Se não há mais nada → marca como finalizada, limpa tudo e dispara `mesaLiberada`

3. **Se não tem `comandaId`:**
   - Marca como finalizada
   - Limpa tudo via `_limparDadosMesa()`
   - Dispara `mesaLiberada` se tiver `mesaId`

**Quando usar:**
Chamado pela tela ANTES de disparar evento `vendaFinalizada` para evitar race conditions. Também é chamado pelos listeners de eventos.

---

## Métodos Privados - Eventos

### `_setupEventBusListener()`
**Linha:** 173-353

**O que faz:**
Configura todos os listeners de eventos do `AppEventBus`. Este método é chamado no construtor.

**Eventos escutados:**
1. **`pedidoCriado`**: Adiciona pedido local à listagem
2. **`pedidoSincronizando`**: Atualiza contadores
3. **`pedidoSincronizado`**: Atualiza contadores
4. **`pedidoErro`**: Atualiza contadores
5. **`pedidoRemovido`**: Remove pedido e recarrega do servidor
6. **`pedidoFinalizado`**: Recalcula contadores
7. **`pagamentoProcessado`**: Adiciona pagamento à venda local
8. **`vendaFinalizada`**: Chama `marcarVendaFinalizada()`
9. **`comandaPaga`**: Chama `marcarVendaFinalizada()`
10. **`mesaLiberada`**: Limpa todos os dados
11. **`statusMesaMudou`**: Atualiza status da mesa

**Quando usar:**
Chamado automaticamente no construtor. Não deve ser chamado manualmente.

---

### `_eventoPertenceAEstaEntidade(AppEvent evento)`
**Linha:** 161-169

**O que faz:**
Verifica se um evento pertence à entidade (mesa ou comanda) que este provider controla.

**Lógica:**
- Se entidade é mesa → verifica se `evento.mesaId == entidade.id`
- Se entidade é comanda → verifica se `evento.comandaId == entidade.id`

**Retorna:**
`bool` - `true` se o evento pertence a esta entidade

**Quando usar:**
Usado pelos listeners de eventos para filtrar eventos que não pertencem a esta entidade.

---

## Métodos Privados - Pedidos Locais

### `_adicionarPedidoLocalAListagem(String pedidoId)`
**Linha:** 358-419

**O que faz:**
Adiciona um pedido local (do Hive) à listagem de produtos/comandas sem buscar no servidor.

**Parâmetros:**
- `pedidoId`: ID do pedido a ser adicionado

**Lógica:**
1. **Verificações:**
   - Se pedido já foi processado → retorna (evita duplicação)
   - Se Hive não está aberto → retorna
   - Se pedido não existe no Hive → retorna
   - Se pedido não pertence a esta entidade → retorna
   - Se pedido já está sincronizado → marca como processado e retorna

2. **Adiciona pedido:**
   - Marca como processado ANTES de adicionar
   - Recalcula contadores
   - Se controle é por comanda → adiciona à comanda específica
   - Caso contrário → adiciona à visão geral

**Quando usar:**
Chamado pelo listener de `pedidoCriado` quando um novo pedido é criado localmente.

---

### `_adicionarPedidoLocalAVisaoGeral(PedidoLocal pedido)`
**Linha:** 422-431

**O que faz:**
Adiciona produtos de um pedido local à visão geral (quando não há controle por comanda).

**Parâmetros:**
- `pedido`: Pedido local a ser processado

**Lógica:**
1. Converte produtos existentes para mapa
2. Processa itens do pedido local
3. Atualiza lista de produtos ordenada

**Quando usar:**
Chamado por `_adicionarPedidoLocalAListagem()` quando não há controle por comanda.

---

### `_adicionarPedidoLocalAComanda(PedidoLocal pedido)`
**Linha:** 434-471

**O que faz:**
Adiciona produtos de um pedido local a uma comanda específica.

**Parâmetros:**
- `pedido`: Pedido local a ser processado (deve ter `comandaId`)

**Lógica:**
1. **Se comanda já existe:**
   - Converte produtos existentes para mapa
   - Processa itens do pedido local
   - Atualiza produtos da comanda
   - Atualiza comanda na listagem usando índice otimizado

2. **Se comanda não existe:**
   - Cria comanda virtual com número real do servidor

**Quando usar:**
Chamado por `_adicionarPedidoLocalAListagem()` quando há controle por comanda.

---

### `_removerPedidoLocalDaListagem(String pedidoId)`
**Linha:** 580-597

**O que faz:**
Remove um pedido local da listagem quando ele é removido do Hive.

**Parâmetros:**
- `pedidoId`: ID do pedido a ser removido

**Lógica:**
1. Remove do rastreamento (`_pedidosProcessados`)
2. Recalcula contadores
3. Recarrega produtos do servidor via `loadProdutos(refresh: true)`

**Por que recarrega do servidor:**
Não sabemos quais produtos eram desse pedido específico, então precisa recarregar para manter produtos do servidor.

**Quando usar:**
Chamado pelo listener de `pedidoRemovido` quando um pedido é removido do Hive.

---

### `_recalcularContadoresPedidos()`
**Linha:** 600-622

**O que faz:**
Recalcula contadores de pedidos locais (pendentes, sincronizando, com erro).

**Lógica:**
1. Busca todos os pedidos locais desta entidade do Hive
2. Conta pedidos por status:
   - `_pedidosPendentes`: pedidos com status `pendente`
   - `_pedidosSincronizando`: pedidos com status `sincronizando`
   - `_pedidosComErro`: pedidos com status `erro`
3. Atualiza status de sincronização

**Quando usar:**
Chamado sempre que precisa atualizar os contadores (após eventos de pedidos, ao carregar produtos, etc).

---

### `_atualizarStatusSincronizacao()`
**Linha:** 625-628

**O que faz:**
Atualiza status de sincronização e notifica listeners.

**Lógica:**
- Chama `notifyListeners()`
- Loga status atual

**Quando usar:**
Chamado após atualizar contadores de pedidos locais.

---

### `_buscarPedidosLocaisFiltrados()`
**Linha:** 841-869

**O que faz:**
Busca pedidos locais pendentes/sincronizando que ainda não foram processados via evento `pedidoCriado`.

**Lógica:**
1. Busca todos os pedidos locais desta entidade
2. Filtra apenas:
   - Pedidos pendentes ou sincronizando
   - Que ainda NÃO foram processados (`!jaFoiProcessado`)
3. Marca como processados para evitar duplicação

**Retorna:**
`List<PedidoLocal>` - Lista de pedidos locais filtrados

**Quando usar:**
Chamado por `loadProdutos()` para incluir pedidos locais que ainda não foram adicionados via eventos.

---

### `_getPedidosLocais(Box<PedidoLocal>? box)`
**Linha:** 723-741

**O que faz:**
Busca pedidos locais desta entidade que não estão sincronizados.

**Parâmetros:**
- `box`: Box do Hive com pedidos locais

**Lógica:**
- Filtra pedidos por `mesaId` ou `comandaId` conforme tipo da entidade
- Exclui pedidos já sincronizados

**Retorna:**
`List<PedidoLocal>` - Lista de pedidos locais não sincronizados

**Quando usar:**
Método auxiliar usado por `_buscarPedidosLocaisFiltrados()` e `_recalcularContadoresPedidos()`.

---

## Métodos Privados - Processamento de Produtos

### `_agruparProdutoNoMapa(...)`
**Linha:** 659-692

**O que faz:**
Agrupa um produto no mapa de produtos agrupados. Se o produto já existe, adiciona quantidade. Se não existe, cria novo.

**Parâmetros:**
- `produtosMap`: Mapa onde produtos são agrupados
- `produtoId`: ID do produto
- `produtoNome`: Nome do produto
- `produtoVariacaoId`: ID da variação (opcional)
- `produtoVariacaoNome`: Nome da variação (opcional)
- `precoUnitario`: Preço unitário
- `quantidade`: Quantidade a adicionar
- `variacaoAtributosValores`: Atributos da variação (opcional)

**Lógica:**
1. Validações básicas (produtoId não vazio, quantidade > 0)
2. Cria chave de agrupamento: `produtoId|variacaoId` ou apenas `produtoId`
3. Se produto já existe no mapa → adiciona quantidade
4. Se não existe → cria novo `ProdutoAgrupado`

**Quando usar:**
Usado por todos os métodos que processam itens de pedidos (servidor e local).

---

### `_produtosParaMapa(List<ProdutoAgrupado> produtos)`
**Linha:** 695-704

**O que faz:**
Converte lista de produtos agrupados para mapa (para facilitar atualizações).

**Parâmetros:**
- `produtos`: Lista de produtos agrupados

**Lógica:**
- Cria mapa usando chave `produtoId|variacaoId` ou apenas `produtoId`

**Retorna:**
`Map<String, ProdutoAgrupado>` - Mapa de produtos

**Quando usar:**
Usado quando precisa atualizar produtos existentes (adicionar mais quantidade, etc).

---

### `_mapaParaProdutosOrdenados(Map<String, ProdutoAgrupado> produtosMap)`
**Linha:** 707-710

**O que faz:**
Converte mapa de produtos agrupados para lista ordenada alfabeticamente por nome.

**Parâmetros:**
- `produtosMap`: Mapa de produtos agrupados

**Lógica:**
- Converte valores do mapa para lista
- Ordena alfabeticamente por `produtoNome`

**Retorna:**
`List<ProdutoAgrupado>` - Lista ordenada de produtos

**Quando usar:**
Usado após processar todos os produtos para retornar lista final ordenada.

---

### `_processarItensPedidoServidorCompleto(PedidoComItensPdvDto pedido, Map<String, ProdutoAgrupado> produtosMap)`
**Linha:** 744-767

**O que faz:**
Processa itens de um pedido completo do servidor (que já vem com itens na resposta da API).

**Parâmetros:**
- `pedido`: Pedido completo com itens
- `produtosMap`: Mapa onde produtos serão agrupados

**Lógica:**
- Itera sobre `pedido.itens`
- Para cada item, chama `_agruparProdutoNoMapa()` incluindo atributos de variação

**Quando usar:**
Chamado por `loadProdutos()` ao processar pedidos do servidor.

---

### `_processarItensPedidoLocal(PedidoLocal pedido, Map<String, ProdutoAgrupado> produtosMap)`
**Linha:** 770-785

**O que faz:**
Processa itens de um pedido local (do Hive).

**Parâmetros:**
- `pedido`: Pedido local
- `produtosMap`: Mapa onde produtos serão agrupados

**Lógica:**
- Itera sobre `pedido.itens`
- Para cada item, chama `_agruparProdutoNoMapa()` (sem atributos de variação, pois pedidos locais não têm)

**Quando usar:**
Chamado ao processar pedidos locais (tanto em `loadProdutos()` quanto ao adicionar pedido via evento).

---

## Métodos Privados - Busca de Dados

### `_buscarPedidosServidor()`
**Linha:** 789-823

**O que faz:**
Busca pedidos do servidor para mesa ou comanda.

**Lógica:**
1. **Verificação:**
   - Se venda foi finalizada → retorna `null` (não busca)

2. **Busca pedidos:**
   - Se entidade é mesa → busca via `pedidoService.getPedidosPorMesaCompleto()`
   - Se entidade é comanda → busca via `pedidoService.getPedidosPorComandaCompleto()`

**Retorna:**
`Future<PedidosComVendaComandasDto?>` - Resultado com pedidos, venda e comandas, ou `null` se erro

**Quando usar:**
Chamado por `loadProdutos()` para buscar pedidos do servidor.

---

### `_buscarVendaAbertaSeNecessario()`
**Linha:** 826-838

**O que faz:**
Busca venda aberta para comanda quando não vem no retorno de pedidos.

**Lógica:**
- Apenas para comandas (`entidade.tipo == TipoEntidade.comanda`)
- Apenas se `_vendaAtual == null`
- Busca via `vendaService.getVendaAbertaPorComanda()`

**Quando usar:**
Chamado por `loadProdutos()` após buscar pedidos, caso venda não tenha vindo no retorno.

---

### `_atualizarStatusMesa()`
**Linha:** 632-655

**O que faz:**
Atualiza status da mesa buscando do servidor.

**Lógica:**
1. **Verificações:**
   - Apenas para mesas (`entidade.tipo == TipoEntidade.mesa`)
   - Se mesa está vazia → retorna sem buscar

2. **Busca status:**
   - Busca mesa via `mesaService.getMesaById()`
   - Atualiza `_statusMesa` se mudou

**Quando usar:**
Chamado pelo listener de `statusMesaMudou` quando status da mesa muda no servidor.

---

## Métodos Privados - Comandas

### `_processarComandasDoRetorno(...)`
**Linha:** 1034-1210

**O que faz:**
Processa comandas usando dados já retornados do servidor. Inclui comandas de pedidos locais pendentes.

**Parâmetros:**
- `comandasRetorno`: Lista de comandas do servidor
- `pedidos`: Lista de pedidos do servidor
- `pedidosLocais`: Lista de pedidos locais pendentes (opcional)

**Lógica:**
1. **Preserva comandas virtuais:**
   - Cria mapa de comandas
   - Preserva comandas virtuais existentes (criadas por pedidos locais) que não vieram do servidor

2. **Processa comandas do servidor:**
   - Para cada comanda, agrupa produtos dos pedidos dessa comanda
   - Cria `ComandaComProdutos` com produtos e venda

3. **Processa pedidos locais:**
   - Agrupa pedidos locais por comanda
   - Se comanda já existe → adiciona produtos locais aos existentes
   - Se comanda não existe → cria comanda virtual

4. **Atualiza estado:**
   - Atualiza `_comandasDaMesa`
   - Atualiza `_produtosPorComanda` e `_vendasPorComanda`

**Quando usar:**
Chamado por `loadProdutos()` quando há controle por comanda e é mesa.

---

### `_criarOuAtualizarComandaVirtual(...)`
**Linha:** 475-543

**O que faz:**
Cria ou atualiza uma comanda virtual com número real do servidor.

**Parâmetros:**
- `comandaId`: ID da comanda
- `produtos`: Lista de produtos da comanda
- `totalPedidos`: Total dos pedidos locais

**Lógica:**
1. **Busca número real:**
   - Busca comanda do servidor via `comandaService.getComandaById()`
   - Se conseguir → usa número real
   - Se não conseguir → usa ID como número temporário

2. **Atualiza ou cria:**
   - Se comanda já existe → atualiza com número real
   - Se não existe → cria nova via `_criarComandaVirtualInterna()`

**Quando usar:**
Chamado ao criar comanda virtual para pedidos locais pendentes.

---

### `_criarComandaVirtualInterna(...)`
**Linha:** 546-575

**O que faz:**
Método auxiliar para criar comanda virtual internamente.

**Parâmetros:**
- `comandaId`: ID da comanda
- `numeroComanda`: Número da comanda
- `codigoBarras`: Código de barras (opcional)
- `descricao`: Descrição (opcional)
- `produtos`: Lista de produtos
- `totalPedidos`: Total dos pedidos

**Lógica:**
- Cria `ComandaListItemDto` com dados fornecidos
- Adiciona aos mapas `_produtosPorComanda` e `_vendasPorComanda`
- Adiciona à lista `_comandasDaMesa`

**Quando usar:**
Chamado por `_criarOuAtualizarComandaVirtual()` para criar comanda virtual.

---

### `_criarIndiceComandas()`
**Linha:** 714-720

**O que faz:**
Cria índice de comandas para busca O(1) em vez de O(n).

**Lógica:**
- Cria mapa `comandaId -> index` da lista `_comandasDaMesa`

**Retorna:**
`Map<String, int>` - Índice de comandas

**Quando usar:**
Usado para buscar comanda na lista sem fazer `indexWhere()` (mais eficiente).

---

### `_removerComandaDaListagem(String comandaId)`
**Linha:** 1419-1452

**O que faz:**
Remove uma comanda específica da listagem quando ela é finalizada.

**Parâmetros:**
- `comandaId`: ID da comanda a ser removida

**Lógica:**
1. Remove comanda de `_comandasDaMesa`
2. Remove produtos de `_produtosPorComanda`
3. Remove venda de `_vendasPorComanda`
4. Se aba selecionada era essa comanda → reseta para visão geral
5. Recalcula produtos agrupados da visão geral

**Quando usar:**
Chamado por `marcarVendaFinalizada()` quando uma comanda específica é finalizada.

---

### `_recalcularProdutosAgrupadosVisaoGeral()`
**Linha:** 1455-1485

**O que faz:**
Recalcula produtos agrupados da visão geral após remover uma comanda.

**Lógica:**
1. Agrupa produtos de todas as comandas restantes
2. Adiciona produtos de pedidos locais pendentes/sincronizando
3. Atualiza `_produtosAgrupados`

**Quando usar:**
Chamado por `_removerComandaDaListagem()` após remover uma comanda.

---

## Métodos Privados - Vendas e Pagamentos

### `_adicionarPagamentoAVendaLocal({required String vendaId, required double valor})`
**Linha:** 1340-1414

**O que faz:**
Adiciona um pagamento à venda local sem ir no servidor. Atualiza venda em memória e recalcula saldo.

**Parâmetros:**
- `vendaId`: ID da venda
- `valor`: Valor do pagamento

**Lógica:**
1. **Cria pagamento temporário:**
   - Cria `PagamentoVendaDto` com dados mínimos
   - ID temporário, status confirmado, data atual

2. **Atualiza venda atual:**
   - Se `_vendaAtual.id == vendaId` → adiciona pagamento e atualiza

3. **Atualiza vendas por comanda:**
   - Itera sobre `_vendasPorComanda`
   - Se encontra venda → adiciona pagamento e atualiza
   - **IMPORTANTE:** Também atualiza campo `venda` dentro de `ComandaComProdutos` para UI refletir mudança

4. **Notifica listeners:**
   - Chama `notifyListeners()` para atualizar UI

**Quando usar:**
Chamado pelo listener de `pagamentoProcessado` quando um pagamento é processado.

---

### `_criarVendaComPagamentoAtualizado(VendaDto vendaOriginal, List<PagamentoVendaDto> pagamentosAtualizados)`
**Linha:** 1304-1336

**O que faz:**
Cria nova instância de `VendaDto` copiando todos os campos da original e substituindo apenas a lista de pagamentos.

**Parâmetros:**
- `vendaOriginal`: Venda original
- `pagamentosAtualizados`: Nova lista de pagamentos

**Retorna:**
`VendaDto` - Nova instância com pagamentos atualizados

**Quando usar:**
Usado por `_adicionarPagamentoAVendaLocal()` para criar venda atualizada com novos pagamentos.

---

## Métodos Privados - Finalização e Limpeza

### `_limparDadosMesa()`
**Linha:** 1574-1618

**O que faz:**
Limpa todos os dados da mesa quando venda é finalizada. Reseta produtos, comandas, vendas e deixa mesa livre.

**Lógica:**
1. **Limpa produtos:**
   - `_produtosAgrupados = []`
   - `_produtosPorComanda.clear()`

2. **Limpa comandas:**
   - `_comandasDaMesa = []`

3. **Limpa vendas:**
   - `_vendaAtual = null`
   - `_vendasPorComanda.clear()`

4. **Reseta estado:**
   - `_abaSelecionada = null`
   - `_statusMesa = 'livre'`
   - `_pedidosProcessados.clear()`
   - Contadores zerados
   - Flags de loading resetadas

5. **Notifica listeners:**
   - Chama `notifyListeners()`

**Quando usar:**
Chamado por `marcarVendaFinalizada()` e pelo listener de `mesaLiberada` quando mesa é liberada.

---

## Métodos de Ciclo de Vida

### `dispose()`
**Linha:** 1621-1628

**O que faz:**
Cancela todas as subscriptions de eventos quando o provider é descartado.

**Lógica:**
- Cancela todas as subscriptions em `_eventBusSubscriptions`
- Limpa a lista
- Chama `super.dispose()`

**Quando usar:**
Chamado automaticamente pelo Flutter quando o provider é descartado.

---

## Resumo da Arquitetura

### Fluxo Principal:
1. **Inicialização:** Construtor configura listeners e recalcula contadores
2. **Carregamento:** `loadProdutos()` busca dados do servidor e local
3. **Eventos:** Listeners atualizam estado localmente sem ir no servidor
4. **Finalização:** `marcarVendaFinalizada()` limpa dados e dispara `mesaLiberada`

### Princípios:
- **Estado local primeiro:** Atualiza estado localmente via eventos antes de buscar do servidor
- **Evita chamadas desnecessárias:** Verifica flags e estado antes de buscar do servidor
- **Previne duplicação:** Rastreia pedidos processados para evitar adicionar duas vezes
- **Separação de responsabilidades:** Métodos específicos para cada tarefa
- **Otimização:** Usa índices para busca O(1) em vez de O(n)
