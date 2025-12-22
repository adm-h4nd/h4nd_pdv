import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import '../../models/mesas/comanda_com_produtos.dart';
import '../../models/mesas/entidade_produtos.dart' show TipoEntidade, MesaComandaInfo;
import '../../data/services/core/pedido_service.dart';
import '../../data/services/core/venda_service.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/models/core/pedido_com_itens_pdv_dto.dart';
import '../../data/models/core/pedidos_com_venda_comandas_dto.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../core/events/app_event_bus.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Provider para gerenciar estado da tela de detalhes de produtos (mesa/comanda)
class MesaDetalhesProvider extends ChangeNotifier {
  final MesaComandaInfo entidade;
  final PedidoService pedidoService;
  final MesaService mesaService;
  final ComandaService comandaService;
  final VendaService vendaService;
  final ConfiguracaoRestauranteDto? configuracaoRestaurante;
  final PedidoLocalRepository pedidoRepo;

  MesaDetalhesProvider({
    required this.entidade,
    required this.pedidoService,
    required this.mesaService,
    required this.comandaService,
    required this.vendaService,
    required this.configuracaoRestaurante,
    required this.pedidoRepo,
  }) {
    // Inicializa status da mesa com o status inicial da entidade
    _statusMesa = entidade.status;
    
    // Configura listeners de eventos
    _setupEventBusListener();
    // Recalcula contadores iniciais
    _recalcularContadoresPedidos();
    _isInitialized = true;
  }

  // Estado de produtos
  List<ProdutoAgrupado> _produtosAgrupados = [];
  bool _isLoading = true;
  bool _carregandoProdutos = false;
  String? _errorMessage;

  // Estado de venda
  VendaDto? _vendaAtual;

  // Controle de abas (apenas quando controle é por comanda e é mesa)
  String? _abaSelecionada; // null = Visão Geral, comandaId = comanda específica

  // Dados das comandas da mesa
  List<ComandaComProdutos> _comandasDaMesa = [];
  bool _carregandoComandas = false;
  Map<String, List<ProdutoAgrupado>> _produtosPorComanda = {}; // comandaId -> produtos
  Map<String, VendaDto?> _vendasPorComanda = {}; // comandaId -> venda

  // Controle de expansão do histórico de pagamentos
  bool _historicoPagamentosExpandido = false;
  
  // Status da mesa (atualizado via eventos)
  String? _statusMesa;
  
  // Status de sincronização (contadores de pedidos locais)
  int _pedidosPendentes = 0;
  int _pedidosSincronizando = 0;
  int _pedidosComErro = 0;
  
  // Listeners de eventos
  List<StreamSubscription<AppEvent>> _eventBusSubscriptions = [];
  bool _isInitialized = false;
  
  // Rastreamento de pedidos já processados para evitar duplicação
  final Set<String> _pedidosProcessados = {};

  // Getters
  List<ProdutoAgrupado> get produtosAgrupados => _produtosAgrupados;
  bool get isLoading => _isLoading;
  bool get carregandoProdutos => _carregandoProdutos;
  String? get errorMessage => _errorMessage;
  VendaDto? get vendaAtual => _vendaAtual;
  String? get abaSelecionada => _abaSelecionada;
  List<ComandaComProdutos> get comandasDaMesa => _comandasDaMesa;
  bool get carregandoComandas => _carregandoComandas;
  Map<String, List<ProdutoAgrupado>> get produtosPorComanda => _produtosPorComanda;
  Map<String, VendaDto?> get vendasPorComanda => _vendasPorComanda;
  bool get historicoPagamentosExpandido => _historicoPagamentosExpandido;
  String? get statusMesa => _statusMesa;
  
  // Getters de status de sincronização
  int get pedidosPendentes => _pedidosPendentes;
  int get pedidosSincronizando => _pedidosSincronizando;
  int get pedidosComErro => _pedidosComErro;
  bool get estaSincronizando => _pedidosSincronizando > 0;
  bool get temErros => _pedidosComErro > 0;
  
  /// Retorna o status visual da mesa/comanda
  /// Se há pedidos pendentes, sincronizando ou com erro, retorna "ocupada"
  /// Se há produtos na mesa (pedidos do servidor), retorna "ocupada"
  /// Caso contrário, retorna o status do servidor
  String get statusVisual {
    // Se há pedidos locais ativos (pendentes, sincronizando ou erro), mesa está ocupada
    if (_pedidosPendentes > 0 || _pedidosSincronizando > 0 || _pedidosComErro > 0) {
      return 'ocupada';
    }
    
    // Se há produtos na mesa (pedidos do servidor), mesa está ocupada
    // Isso garante que mesmo após sincronização, se há produtos, a mesa continua ocupada
    final produtosParaAcao = getProdutosParaAcao();
    if (produtosParaAcao.isNotEmpty) {
      return 'ocupada';
    }
    
    // Caso contrário, usa o status do servidor
    return _statusMesa ?? entidade.status;
  }

  /// Retorna os produtos para ação (geral ou da comanda selecionada)
  List<ProdutoAgrupado> getProdutosParaAcao() {
    if (_abaSelecionada == null) {
      return _produtosAgrupados;
    }
    return _produtosPorComanda[_abaSelecionada] ?? [];
  }

  /// Retorna a venda para ação (geral ou da comanda selecionada)
  VendaDto? getVendaParaAcao() {
    if (_abaSelecionada == null) {
      return _vendaAtual;
    }
    return _vendasPorComanda[_abaSelecionada];
  }


  /// Define a aba selecionada
  void setAbaSelecionada(String? comandaId) {
    if (_abaSelecionada != comandaId) {
      _abaSelecionada = comandaId;
      notifyListeners();
    }
  }

  /// Alterna expansão do histórico de pagamentos
  void toggleHistoricoPagamentos() {
    _historicoPagamentosExpandido = !_historicoPagamentosExpandido;
    notifyListeners();
  }

  /// Verifica se um evento pertence a esta entidade (mesa ou comanda)
  bool _eventoPertenceAEstaEntidade(AppEvent evento) {
    if (entidade.tipo == TipoEntidade.mesa) {
      // Para mesa: verifica se mesaId do evento corresponde
      return evento.mesaId == entidade.id;
    } else {
      // Para comanda: verifica se comandaId do evento corresponde
      return evento.comandaId == entidade.id;
    }
  }

  /// Configura listeners de eventos do AppEventBus
  /// Escuta apenas eventos relacionados à mesa/comanda que este provider controla
  void _setupEventBusListener() {
    final eventBus = AppEventBus.instance;
    
    // Escuta eventos de pedido criado (disparado pelo AutoSyncManager após salvar no Hive)
    // ÚNICO evento que adiciona pedido à listagem local (sem ir ao servidor)
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoCriado).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento) && evento.pedidoId != null) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} criado');
          // Reseta flag de venda finalizada quando um novo pedido é criado
          // Isso permite que a mesa volte a funcionar normalmente
          _vendaFinalizada = false;
          // Adiciona pedido local à listagem (sem buscar no servidor)
          _adicionarPedidoLocalAListagem(evento.pedidoId!);
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizando
    // Apenas atualiza contadores, não precisa recarregar produtos
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizando).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} sincronizando');
          if (_pedidosPendentes > 0) _pedidosPendentes--;
          _pedidosSincronizando++;
          _atualizarStatusSincronizacao();
          // NÃO recarrega produtos - pedido ainda não está no servidor
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizado
    // Apenas atualiza contadores, pedido já está na listagem local
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizado).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} sincronizado');
          if (_pedidosSincronizando > 0) _pedidosSincronizando--;
          _atualizarStatusSincronizacao();
          // NÃO recarrega produtos - pedido já está na listagem local
        }
      }),
    );
    
    // Escuta eventos de pedido com erro
    // Apenas atualiza contadores, pedido ainda está na listagem local
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoErro).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} com erro');
          if (_pedidosSincronizando > 0) _pedidosSincronizando--;
          _pedidosComErro++;
          _atualizarStatusSincronizacao();
          // NÃO recarrega produtos - pedido ainda está na listagem local
        }
      }),
    );
    
    // Escuta eventos de pedido removido
    // Remove pedido da listagem local (sem buscar no servidor)
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoRemovido).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento) && evento.pedidoId != null) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} removido');
          // Remove pedido da listagem local
          _removerPedidoLocalDaListagem(evento.pedidoId!);
        }
      }),
    );
    
    // Escuta eventos de pedido finalizado
    // Quando pedido é finalizado, apenas atualiza contadores
    // O pedido já está na listagem local, não precisa recarregar do servidor
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoFinalizado).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} finalizado');
          // Apenas atualiza contadores, pedido já está na listagem local
          _recalcularContadoresPedidos();
        }
      }),
    );
    
    // Escuta eventos de pagamento processado
    // Adiciona pagamento à venda local sem ir no servidor
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pagamentoProcessado).listen((evento) {
        debugPrint('🔔 [MesaDetalhesProvider] Evento pagamentoProcessado recebido: vendaId=${evento.vendaId}, mesaId=${evento.mesaId}, comandaId=${evento.comandaId}');
        debugPrint('   Entidade atual: tipo=${entidade.tipo}, id=${entidade.id}');
        debugPrint('   Pertence à entidade? ${_eventoPertenceAEstaEntidade(evento)}');
        
        if (_eventoPertenceAEstaEntidade(evento) && evento.vendaId != null) {
          debugPrint('✅ [MesaDetalhesProvider] Evento: Pagamento processado para venda ${evento.vendaId}');
          // Adiciona pagamento à venda local (sem ir no servidor)
          _adicionarPagamentoAVendaLocal(
            vendaId: evento.vendaId!,
            valor: evento.get<double>('valor') ?? 0.0,
          );
        } else {
          debugPrint('⚠️ [MesaDetalhesProvider] Evento pagamentoProcessado ignorado - não pertence à entidade ou vendaId é null');
        }
      }),
    );
    
    // Escuta eventos de venda finalizada
    // Usa marcarVendaFinalizada() para garantir que o evento mesaLiberada seja disparado quando apropriado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.vendaFinalizada).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Venda ${evento.vendaId} finalizada');
          
          // Usa marcarVendaFinalizada() que já tem toda a lógica de verificar e disparar mesaLiberada
          marcarVendaFinalizada(
            comandaId: evento.comandaId,
            mesaId: evento.mesaId,
          );
        }
      }),
    );
    
    // Escuta eventos de comanda paga
    // Usa marcarVendaFinalizada() para garantir consistência e disparar mesaLiberada quando apropriado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.comandaPaga).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Comanda ${evento.comandaId} paga');
          
          // Se for a comanda atual (entidade é comanda), limpa tudo
          if (entidade.tipo == TipoEntidade.comanda && evento.comandaId == entidade.id) {
            marcarVendaFinalizada(
              comandaId: evento.comandaId,
              mesaId: evento.mesaId,
            );
          } else if (entidade.tipo == TipoEntidade.mesa && evento.comandaId != null) {
            // Se for mesa, remove apenas a comanda específica e verifica se pode liberar
            marcarVendaFinalizada(
              comandaId: evento.comandaId,
              mesaId: evento.mesaId ?? entidade.id,
            );
          }
        }
      }),
    );
    
    // Escuta eventos de mesa liberada
    // Quando mesa é liberada, limpa todos os dados e marca como livre
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.mesaLiberada).listen((evento) {
        if (entidade.tipo == TipoEntidade.mesa && evento.mesaId == entidade.id) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Mesa ${evento.mesaId} liberada');
          // Marca como finalizada e limpa todos os dados
          if (!_vendaFinalizada) {
            _vendaFinalizada = true;
          }
          _limparDadosMesa();
        }
      }),
    );
    
    // Escuta eventos de status da mesa mudou
    // NOTA: Não atualiza se a mesa já foi limpa (venda finalizada)
    // porque o status já foi atualizado localmente para "livre"
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.statusMesaMudou).listen((evento) {
        if (entidade.tipo == TipoEntidade.mesa && evento.mesaId == entidade.id) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Status da mesa mudou');
          // Se a mesa está vazia (venda foi finalizada), não precisa ir no servidor
          // porque já atualizamos o status localmente para "livre"
          if (_produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty) {
            debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa, ignorando atualização do servidor');
            return;
          }
          // Atualiza status da mesa apenas se ainda há dados na mesa
          _atualizarStatusMesa();
        }
      }),
    );
    
    debugPrint('✅ [MesaDetalhesProvider] Listeners de eventos configurados para ${entidade.tipo.name} ${entidade.id}');
  }

  /// Adiciona um pedido local à listagem (sem buscar no servidor)
  /// Busca o pedido do Hive e adiciona aos produtos/comandas existentes
  /// Evita duplicação verificando se o pedido já foi processado
  void _adicionarPedidoLocalAListagem(String pedidoId) {
    try {
      // Verifica se o pedido já foi processado (evita duplicação)
      if (_pedidosProcessados.contains(pedidoId)) {
        debugPrint('⚠️ [MesaDetalhesProvider] Pedido $pedidoId já foi processado, ignorando evento duplicado');
        return;
      }
      
      if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
        debugPrint('⚠️ [MesaDetalhesProvider] Hive não está aberto, não é possível adicionar pedido');
        return;
      }
      
      final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
      final pedido = box.get(pedidoId);
      
      if (pedido == null) {
        debugPrint('⚠️ [MesaDetalhesProvider] Pedido $pedidoId não encontrado no Hive');
        return;
      }
      
      // Verifica se pertence a esta entidade
      final pertenceAEstaEntidade = (entidade.tipo == TipoEntidade.mesa && pedido.mesaId == entidade.id) ||
          (entidade.tipo == TipoEntidade.comanda && pedido.comandaId == entidade.id);
      
      if (!pertenceAEstaEntidade) {
        debugPrint('⚠️ [MesaDetalhesProvider] Pedido $pedidoId não pertence a esta entidade');
        return;
      }
      
      // Verifica se o pedido já está sincronizado (não deve adicionar novamente)
      if (pedido.syncStatus == SyncStatusPedido.sincronizado) {
        debugPrint('⚠️ [MesaDetalhesProvider] Pedido $pedidoId já está sincronizado, não adicionando novamente');
        _pedidosProcessados.add(pedidoId); // Marca como processado
        return;
      }
      
      debugPrint('✅ [MesaDetalhesProvider] Adicionando pedido local $pedidoId à listagem');
      
      // Marca pedido como processado ANTES de adicionar (evita duplicação se evento for disparado novamente)
      _pedidosProcessados.add(pedidoId);
      
      // Atualiza contadores
      _recalcularContadoresPedidos();
      
      // Se controle é por comanda e é mesa
      if (entidade.tipo == TipoEntidade.mesa && 
          configuracaoRestaurante != null && 
          configuracaoRestaurante!.controlePorComanda &&
          pedido.comandaId != null) {
        // Adiciona à comanda específica
        _adicionarPedidoLocalAComanda(pedido);
      } else {
        // Adiciona à visão geral
        _adicionarPedidoLocalAVisaoGeral(pedido);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao adicionar pedido local: $e');
    }
  }
  
  /// Adiciona pedido local à visão geral (sem controle por comanda)
  void _adicionarPedidoLocalAVisaoGeral(PedidoLocal pedido) {
    // Converte produtos existentes para mapa
    final produtosMap = _produtosParaMapa(_produtosAgrupados);
    
    // Processa itens do pedido local
    _processarItensPedidoLocal(pedido, produtosMap);
    
    // Atualiza lista de produtos ordenada
    _produtosAgrupados = _mapaParaProdutosOrdenados(produtosMap);
  }
  
  /// Adiciona pedido local a uma comanda específica
  void _adicionarPedidoLocalAComanda(PedidoLocal pedido) {
    if (pedido.comandaId == null) return;
    
    final comandaId = pedido.comandaId!;
    
    // Se a comanda já existe na listagem
    if (_produtosPorComanda.containsKey(comandaId)) {
      // Converte produtos existentes para mapa
      final produtosMap = _produtosParaMapa(_produtosPorComanda[comandaId]!);
      
      // Processa itens do pedido local
      _processarItensPedidoLocal(pedido, produtosMap);
      
      // Atualiza lista de produtos da comanda
      final produtosAtualizados = _mapaParaProdutosOrdenados(produtosMap);
      _produtosPorComanda[comandaId] = produtosAtualizados;
      
      // Atualiza comanda na listagem usando índice otimizado
      final indiceComandas = _criarIndiceComandas();
      final comandaIndex = indiceComandas[comandaId];
      if (comandaIndex != null) {
        _comandasDaMesa[comandaIndex] = ComandaComProdutos(
          comanda: _comandasDaMesa[comandaIndex].comanda,
          produtos: produtosAtualizados,
          venda: _comandasDaMesa[comandaIndex].venda,
        );
      }
    } else {
      // Cria comanda virtual com número real da comanda
      final produtosMap = <String, ProdutoAgrupado>{};
      _processarItensPedidoLocal(pedido, produtosMap);
      
      final produtos = _mapaParaProdutosOrdenados(produtosMap);
      
      // Busca número real da comanda do servidor (apenas uma vez)
      _criarOuAtualizarComandaVirtual(comandaId, produtos, pedido.total);
    }
  }
  
  /// Cria ou atualiza uma comanda virtual com número real do servidor
  /// Método centralizado para evitar duplicação de lógica
  Future<void> _criarOuAtualizarComandaVirtual(
    String comandaId,
    List<ProdutoAgrupado> produtos,
    double totalPedidos,
  ) async {
    try {
      // Busca comanda do servidor para pegar o número real
      final response = await comandaService.getComandaById(comandaId);
      
      String numeroComanda;
      String? codigoBarras;
      String? descricao;
      
      if (response.success && response.data != null) {
        numeroComanda = response.data!.numero;
        codigoBarras = response.data!.codigoBarras;
        descricao = response.data!.descricao;
      } else {
        // Se não conseguir buscar, usa o ID como número temporário
        numeroComanda = comandaId.substring(0, 8);
        codigoBarras = null;
        descricao = null;
      }
      
      // Usa índice otimizado para buscar comanda
      final indiceComandas = _criarIndiceComandas();
      final comandaIndex = indiceComandas[comandaId];
      
      if (comandaIndex != null) {
        // Atualiza comanda existente com número real
        _comandasDaMesa[comandaIndex] = ComandaComProdutos(
          comanda: ComandaListItemDto(
            id: comandaId,
            numero: numeroComanda,
            codigoBarras: codigoBarras,
            descricao: descricao,
            status: _comandasDaMesa[comandaIndex].comanda.status,
            ativa: _comandasDaMesa[comandaIndex].comanda.ativa,
            totalPedidosAtivos: _comandasDaMesa[comandaIndex].comanda.totalPedidosAtivos,
            valorTotalPedidosAtivos: _comandasDaMesa[comandaIndex].comanda.valorTotalPedidosAtivos,
            vendaAtualId: _comandasDaMesa[comandaIndex].comanda.vendaAtualId,
            pagamentos: _comandasDaMesa[comandaIndex].comanda.pagamentos,
          ),
          produtos: _comandasDaMesa[comandaIndex].produtos,
          venda: _comandasDaMesa[comandaIndex].venda,
        );
      } else {
        // Cria nova comanda virtual usando método auxiliar
        _criarComandaVirtualInterna(comandaId, numeroComanda, codigoBarras, descricao, produtos, totalPedidos);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao buscar número da comanda: $e');
      // Em caso de erro, apenas cria se não existir
      final indiceComandas = _criarIndiceComandas();
      if (!indiceComandas.containsKey(comandaId)) {
        _criarComandaVirtualInterna(
          comandaId, 
          comandaId.substring(0, 8), 
          null, 
          null, 
          produtos, 
          totalPedidos
        );
        notifyListeners();
      }
    }
  }
  
  /// Método auxiliar para criar comanda virtual (evita duplicação)
  void _criarComandaVirtualInterna(
    String comandaId,
    String numeroComanda,
    String? codigoBarras,
    String? descricao,
    List<ProdutoAgrupado> produtos,
    double totalPedidos,
  ) {
    final comandaVirtual = ComandaListItemDto(
      id: comandaId,
      numero: numeroComanda,
      codigoBarras: codigoBarras,
      descricao: descricao,
      status: 'Em Uso',
      ativa: true,
      totalPedidosAtivos: 1,
      valorTotalPedidosAtivos: totalPedidos,
      vendaAtualId: null,
      pagamentos: [],
    );
    
    _produtosPorComanda[comandaId] = produtos;
    _vendasPorComanda[comandaId] = null;
    
    _comandasDaMesa.add(ComandaComProdutos(
      comanda: comandaVirtual,
      produtos: produtos,
      venda: null,
    ));
  }

  /// Remove um pedido local da listagem
  /// Quando um pedido é removido do Hive, precisa recarregar do servidor
  /// porque não sabemos quais produtos eram desse pedido específico
  void _removerPedidoLocalDaListagem(String pedidoId) {
    try {
      debugPrint('🗑️ [MesaDetalhesProvider] Pedido local $pedidoId removido, recarregando do servidor');
      
      // Remove do rastreamento
      _pedidosProcessados.remove(pedidoId);
      
      // Atualiza contadores
      _recalcularContadoresPedidos();
      
      // Quando um pedido é removido, precisa recarregar do servidor
      // porque não sabemos quais produtos eram desse pedido específico
      // e precisamos manter os produtos do servidor
      loadProdutos(refresh: true);
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao remover pedido local: $e');
    }
  }

  /// Recalcula contadores de pedidos locais
  void _recalcularContadoresPedidos() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      _pedidosPendentes = 0;
      _pedidosSincronizando = 0;
      _pedidosComErro = 0;
      return;
    }
    
    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final pedidos = box.values.where((p) {
      if (entidade.tipo == TipoEntidade.mesa) {
        return p.mesaId == entidade.id;
      } else {
        return p.comandaId == entidade.id;
      }
    }).toList();
    
    _pedidosPendentes = pedidos.where((p) => p.syncStatus == SyncStatusPedido.pendente).length;
    _pedidosSincronizando = pedidos.where((p) => p.syncStatus == SyncStatusPedido.sincronizando).length;
    _pedidosComErro = pedidos.where((p) => p.syncStatus == SyncStatusPedido.erro).length;
    
    _atualizarStatusSincronizacao();
  }

  /// Atualiza status de sincronização e notifica listeners
  void _atualizarStatusSincronizacao() {
    notifyListeners();
    debugPrint('📊 [MesaDetalhesProvider] Status sincronização: pendentes=$_pedidosPendentes, sincronizando=$_pedidosSincronizando, erros=$_pedidosComErro');
  }

  /// Atualiza status da mesa buscando do servidor
  /// Não vai no servidor se a mesa já foi limpa (venda finalizada)
  Future<void> _atualizarStatusMesa() async {
    if (entidade.tipo != TipoEntidade.mesa) return;
    
    // Se a mesa está vazia (venda foi finalizada), não precisa ir no servidor
    // porque já atualizamos o status localmente para "livre"
    if (_produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa, não precisa buscar status do servidor');
      return;
    }
    
    try {
      final response = await mesaService.getMesaById(entidade.id);
      if (response.success && response.data != null) {
        final novoStatus = response.data!.status.toLowerCase();
        if (_statusMesa != novoStatus) {
          _statusMesa = novoStatus;
          notifyListeners();
          debugPrint('✅ [MesaDetalhesProvider] Status da mesa atualizado: $novoStatus');
        }
      }
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao atualizar status da mesa: $e');
    }
  }

  /// Agrupa um produto no mapa de produtos agrupados
  /// Método auxiliar centralizado para evitar duplicação de código
  void _agruparProdutoNoMapa(
    Map<String, ProdutoAgrupado> produtosMap,
    String produtoId,
    String produtoNome,
    String? produtoVariacaoId,
    String? produtoVariacaoNome,
    double precoUnitario,
    int quantidade, {
    List<dynamic>? variacaoAtributosValores,
  }) {
    // Validações básicas
    if (produtoId.isEmpty || quantidade <= 0) return;
    
    // Cria chave de agrupamento
    final chave = produtoVariacaoId != null && produtoVariacaoId!.isNotEmpty
        ? '$produtoId|$produtoVariacaoId'
        : produtoId;
    
    if (produtosMap.containsKey(chave)) {
      // Adiciona quantidade ao produto existente
      produtosMap[chave]!.adicionarQuantidade(quantidade);
    } else {
      // Cria novo produto agrupado
      produtosMap[chave] = ProdutoAgrupado(
        produtoId: produtoId,
        produtoNome: produtoNome,
        produtoVariacaoId: produtoVariacaoId,
        produtoVariacaoNome: produtoVariacaoNome,
        precoUnitario: precoUnitario,
        quantidadeTotal: quantidade,
        variacaoAtributosValores: variacaoAtributosValores?.cast() ?? const [],
      );
    }
  }
  
  /// Converte lista de produtos agrupados para mapa (para facilitar atualizações)
  Map<String, ProdutoAgrupado> _produtosParaMapa(List<ProdutoAgrupado> produtos) {
    final produtosMap = <String, ProdutoAgrupado>{};
    for (var produto in produtos) {
      final chave = produto.produtoVariacaoId != null && produto.produtoVariacaoId!.isNotEmpty
          ? '${produto.produtoId}|${produto.produtoVariacaoId}'
          : produto.produtoId;
      produtosMap[chave] = produto;
    }
    return produtosMap;
  }
  
  /// Converte mapa de produtos agrupados para lista ordenada
  List<ProdutoAgrupado> _mapaParaProdutosOrdenados(Map<String, ProdutoAgrupado> produtosMap) {
    return produtosMap.values.toList()
      ..sort((a, b) => a.produtoNome.compareTo(b.produtoNome));
  }
  
  /// Cria índice de comandas para busca O(1)
  /// Retorna Map<comandaId, index> para acesso rápido
  Map<String, int> _criarIndiceComandas() {
    final indice = <String, int>{};
    for (int i = 0; i < _comandasDaMesa.length; i++) {
      indice[_comandasDaMesa[i].comanda.id] = i;
    }
    return indice;
  }
  
  /// Busca pedidos locais pendentes
  List<PedidoLocal> _getPedidosLocais(Box<PedidoLocal>? box) {
    if (box == null || !Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return [];
    }
    
    final pedidos = box.values
        .where((p) {
          if (entidade.tipo == TipoEntidade.mesa) {
            return p.mesaId == entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          } else {
            return p.comandaId == entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          }
        })
        .toList();
    
    return pedidos;
  }

  /// Processa itens de um pedido completo (que já vem com itens da API)
  void _processarItensPedidoServidorCompleto(
    PedidoComItensPdvDto pedido, 
    Map<String, ProdutoAgrupado> produtosMap
  ) {
    try {
      debugPrint('    📋 Itens do pedido ${pedido.numero}: ${pedido.itens.length}');

      for (final item in pedido.itens) {
        _agruparProdutoNoMapa(
          produtosMap,
          item.produtoId,
          item.produtoNome,
          item.produtoVariacaoId,
          item.produtoVariacaoNome,
          item.precoUnitario,
          item.quantidade,
          variacaoAtributosValores: item.variacaoAtributosValores,
        );
      }
    } catch (e) {
      // Ignora erros individuais de pedidos
      debugPrint('❌ Erro ao processar itens do pedido ${pedido.numero}: $e');
    }
  }

  /// Processa itens de um pedido local
  void _processarItensPedidoLocal(
    PedidoLocal pedido, 
    Map<String, ProdutoAgrupado> produtosMap
  ) {
    for (final item in pedido.itens) {
      _agruparProdutoNoMapa(
        produtosMap,
        item.produtoId,
        item.produtoNome,
        item.produtoVariacaoId,
        item.produtoVariacaoNome,
        item.precoUnitario,
        item.quantidade,
      );
    }
  }

  /// Busca pedidos do servidor para mesa ou comanda
  /// Não vai no servidor se a venda foi finalizada
  Future<PedidosComVendaComandasDto?> _buscarPedidosServidor() async {
    // Se a venda foi finalizada, não vai no servidor
    if (_vendaFinalizada) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Venda já foi finalizada, não precisa buscar pedidos do servidor');
      return null;
    }
    
    debugPrint('🔍 [MesaDetalhesProvider] Buscando pedidos do servidor - Tipo: ${entidade.tipo}, ID: ${entidade.id}');
    debugPrint('   Status mesa: $_statusMesa, Produtos: ${_produtosAgrupados.length}, Comandas: ${_comandasDaMesa.length}, Venda: ${_vendaAtual != null}');
    
    if (entidade.tipo == TipoEntidade.mesa) {
      final response = await pedidoService.getPedidosPorMesaCompleto(entidade.id);
      debugPrint('📥 Resposta da busca: success=${response.success}, message=${response.message}');
      if (response.success && response.data != null) {
        final resultado = response.data!;
        debugPrint('✅ Pedidos encontrados: ${resultado.pedidos.length}');
        debugPrint('✅ Comandas encontradas: ${resultado.comandas?.length ?? 0}');
        return resultado;
      } else {
        debugPrint('❌ Erro na busca: ${response.message}');
        return null;
      }
    } else {
      final response = await pedidoService.getPedidosPorComandaCompleto(entidade.id);
      debugPrint('📥 Resposta da busca: success=${response.success}, message=${response.message}');
      if (response.success && response.data != null) {
        final resultado = response.data!;
        debugPrint('✅ Pedidos encontrados: ${resultado.pedidos.length}');
        return resultado;
      } else {
        debugPrint('❌ Erro na busca: ${response.message}');
        return null;
      }
    }
  }
  
  /// Busca venda aberta para comanda (quando não vem no retorno de pedidos)
  Future<void> _buscarVendaAbertaSeNecessario() async {
    if (entidade.tipo == TipoEntidade.comanda && _vendaAtual == null) {
      debugPrint('ℹ️ Nenhuma venda encontrada na resposta da comanda, buscando venda aberta diretamente...');
      final vendaResponse = await vendaService.getVendaAbertaPorComanda(entidade.id);
      if (vendaResponse.success && vendaResponse.data != null) {
        _vendaAtual = vendaResponse.data;
        debugPrint('✅ Venda aberta encontrada diretamente: ${vendaResponse.data!.id}');
      } else {
        debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
        _vendaAtual = null;
      }
    }
  }
  
  /// Busca pedidos locais pendentes/sincronizando filtrados
  List<PedidoLocal> _buscarPedidosLocaisFiltrados() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return [];
    }
    
    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final todosPedidosLocais = _getPedidosLocais(box);
    
    // Filtra apenas pedidos pendentes ou sincronizando desta mesa/comanda
    // E que ainda NÃO foram processados via evento pedidoCriado
    final pedidosFiltrados = todosPedidosLocais.where((p) {
      final pertenceAEstaEntidade = (entidade.tipo == TipoEntidade.mesa && p.mesaId == entidade.id) ||
          (entidade.tipo == TipoEntidade.comanda && p.comandaId == entidade.id);
      final estaPendenteOuSincronizando = p.syncStatus == SyncStatusPedido.pendente || 
          p.syncStatus == SyncStatusPedido.sincronizando;
      final jaFoiProcessado = _pedidosProcessados.contains(p.id);
      // Só inclui se pertence à entidade, está pendente/sincronizando E ainda não foi processado
      return pertenceAEstaEntidade && estaPendenteOuSincronizando && !jaFoiProcessado;
    }).toList();
    
    debugPrint('📦 Pedidos locais pendentes/sincronizando encontrados: ${pedidosFiltrados.length} (já processados: ${_pedidosProcessados.length})');
    
    // Marca pedidos locais como processados (para evitar duplicação quando eventos chegarem)
    for (final pedido in pedidosFiltrados) {
      _pedidosProcessados.add(pedido.id);
    }
    
    return pedidosFiltrados;
  }

  /// Carrega produtos agrupados
  /// Não vai no servidor se a mesa já foi limpa (venda finalizada)
  Future<void> loadProdutos({bool refresh = false}) async {
    // Log para rastrear origem da chamada com stack trace
    debugPrint('🔍 [MesaDetalhesProvider] loadProdutos chamado - refresh: $refresh, vendaFinalizada: $_vendaFinalizada, status: $_statusMesa');
    // Stack trace para identificar origem da chamada
    debugPrint('📍 Stack trace: ${StackTrace.current}');
    
    // Evita múltiplas chamadas simultâneas (exceto quando é refresh explícito)
    if (_carregandoProdutos && !refresh) {
      debugPrint('⚠️ loadProdutos já está em execução, ignorando chamada duplicada');
      return;
    }

    // Se a venda foi finalizada, não vai no servidor (verificação prioritária)
    if (_vendaFinalizada) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Venda já foi finalizada, não precisa buscar produtos do servidor');
      _isLoading = false;
      _carregandoProdutos = false;
      notifyListeners();
      return;
    }

    // Se a entidade (mesa/comanda) já está com status 'livre' e não é refresh manual, não vai no servidor
    // Isso evita chamadas quando o widget é recriado após finalizar a venda
    if (!refresh && entidade.status?.toLowerCase() == 'livre' && _produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Entidade já está livre e sem produtos, não precisa buscar produtos do servidor');
      _isLoading = false;
      _carregandoProdutos = false;
      notifyListeners();
      return;
    }

    // Se a mesa está limpa (sem produtos/comandas/venda e status livre), não vai no servidor
    // porque já limpamos tudo localmente e não há mais produtos
    // Também verifica se não há pedidos locais pendentes (indicando que mesa está realmente limpa)
    final pedidosLocaisPendentes = _buscarPedidosLocaisFiltrados();
    if (_produtosAgrupados.isEmpty && 
        _comandasDaMesa.isEmpty && 
        _vendaAtual == null && 
        _statusMesa == 'livre' &&
        pedidosLocaisPendentes.isEmpty) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa (venda finalizada), não precisa buscar produtos do servidor');
      _isLoading = false;
      _carregandoProdutos = false;
      notifyListeners();
      return;
    }

    if (refresh) {
      _errorMessage = null;
      // Limpa rastreamento de pedidos processados quando recarrega do servidor
      // Isso permite que pedidos sejam reprocessados se necessário
      _pedidosProcessados.clear();
      // Reseta flag de venda finalizada quando é refresh manual
      // Permite recarregar dados do servidor se necessário
      _vendaFinalizada = false;
    }

    _isLoading = true;
    _carregandoProdutos = true;
    notifyListeners();

    try {
      // Busca pedidos do servidor (com itens já incluídos)
      final resultadoCompleto = await _buscarPedidosServidor();
      
      if (resultadoCompleto == null) {
        _isLoading = false;
        _carregandoProdutos = false;
        notifyListeners();
        return;
      }
      
      final pedidosServidor = resultadoCompleto.pedidos;
      
      // Atualiza venda atual se vier no retorno
      if (resultadoCompleto.venda != null) {
        _vendaAtual = resultadoCompleto.venda;
        if (entidade.tipo == TipoEntidade.comanda) {
          debugPrint('✅ Venda encontrada na resposta: ${resultadoCompleto.venda!.id}');
        }
      }
      
      // Busca venda aberta se necessário (apenas para comandas)
      await _buscarVendaAbertaSeNecessario();
      
      // Se controle é por comanda, processa comandas usando dados já retornados
      if (entidade.tipo == TipoEntidade.mesa &&
          configuracaoRestaurante != null && 
          configuracaoRestaurante!.controlePorComanda && 
          resultadoCompleto.comandas != null) {
        // Busca pedidos locais pendentes para incluir nas comandas
        List<PedidoLocal> pedidosLocaisParaComandas = [];
        if (Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
          final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
          pedidosLocaisParaComandas = box.values
              .where((p) => 
                  p.mesaId == entidade.id &&
                  p.comandaId != null &&
                  (p.syncStatus == SyncStatusPedido.pendente || p.syncStatus == SyncStatusPedido.sincronizando) &&
                  !_pedidosProcessados.contains(p.id)) // Só inclui se ainda não foi processado
              .toList();
          debugPrint('📦 Pedidos locais para comandas: ${pedidosLocaisParaComandas.length} (já processados: ${_pedidosProcessados.length})');
          // Marca como processados
          for (final pedido in pedidosLocaisParaComandas) {
            _pedidosProcessados.add(pedido.id);
          }
        }
        _processarComandasDoRetorno(
          resultadoCompleto.comandas!, 
          pedidosServidor, 
          pedidosLocais: pedidosLocaisParaComandas
        );
      }

      // Busca pedidos locais PENDENTES ou SINCRONIZANDO
      // IMPORTANTE: Não processa pedidos que já foram adicionados via evento pedidoCriado
      // Isso evita duplicação quando loadProdutos é chamado após um pedido já ter sido adicionado
      final pedidosLocais = _buscarPedidosLocaisFiltrados();
      
      // Atualiza contadores de status de sincronização
      _recalcularContadoresPedidos();

      // Agrupa produtos de todos os pedidos
      final Map<String, ProdutoAgrupado> produtosMap = {};

      // Processa pedidos do servidor (itens já vêm na resposta)
      debugPrint('🔄 Processando ${pedidosServidor.length} pedidos do servidor...');
      for (final pedido in pedidosServidor) {
        debugPrint('  📦 Processando pedido: ${pedido.numero} (ID: ${pedido.id})');
        _processarItensPedidoServidorCompleto(pedido, produtosMap);
      }
      debugPrint('✅ Produtos agrupados após processar servidor: ${produtosMap.length}');

      // Processa pedidos locais
      for (final pedido in pedidosLocais) {
        _processarItensPedidoLocal(pedido, produtosMap);
      }

      // Converte map para lista ordenada usando método auxiliar
      final produtosList = _mapaParaProdutosOrdenados(produtosMap);

      debugPrint('📊 Total de produtos agrupados: ${produtosList.length}');

      _produtosAgrupados = produtosList;
      _isLoading = false;
      _errorMessage = null;
      _carregandoProdutos = false;
      notifyListeners();
      
      debugPrint('✅ Estado atualizado com ${_produtosAgrupados.length} produtos');
    } catch (e) {
      _produtosAgrupados = [];
      _errorMessage = 'Erro ao carregar produtos: ${e.toString()}';
      _isLoading = false;
      _carregandoProdutos = false;
      notifyListeners();
    }
  }

  /// Processa comandas usando dados já retornados (evita chamada duplicada)
  /// Inclui comandas de pedidos locais pendentes que ainda não foram sincronizados
  void _processarComandasDoRetorno(
    List<ComandaListItemDto> comandasRetorno, 
    List<PedidoComItensPdvDto> pedidos, {
    List<PedidoLocal> pedidosLocais = const [],
  }) {
    _carregandoComandas = true;
    notifyListeners();

    try {
      // Cria um mapa de comandas para facilitar busca e merge
      // Preserva comandas virtuais existentes (criadas por pedidos locais)
      final comandasMap = <String, ComandaComProdutos>{};
      
      // Adiciona comandas virtuais existentes ao mapa para preservá-las
      // Usa Set para busca O(1) em vez de any() que é O(n)
      final idsComandasServidor = comandasRetorno.map((c) => c.id).toSet();
      for (final comandaExistente in _comandasDaMesa) {
        // Verifica se é uma comanda virtual (não veio do servidor)
        if (!idsComandasServidor.contains(comandaExistente.comanda.id)) {
          // É comanda virtual, preserva no mapa
          comandasMap[comandaExistente.comanda.id] = comandaExistente;
        }
      }
      
      // Processa comandas do servidor
      for (final comanda in comandasRetorno) {
        // Agrupa produtos dos pedidos dessa comanda (servidor)
        final produtosMap = <String, ProdutoAgrupado>{};
        
        for (final pedido in pedidos) {
          // Só processa pedidos desta comanda
          if (pedido.comandaId != comanda.id) continue;
          
          for (final item in pedido.itens) {
            _agruparProdutoNoMapa(
              produtosMap,
              item.produtoId,
              item.produtoNome,
              item.produtoVariacaoId,
              item.produtoVariacaoNome,
              item.precoUnitario,
              item.quantidade,
              variacaoAtributosValores: item.variacaoAtributosValores,
            );
          }
        }
        
        final produtos = _mapaParaProdutosOrdenados(produtosMap);

        // Usa venda que já vem no objeto comanda se disponível
        VendaDto? vendaComanda = comanda.vendaAtual;

        comandasMap[comanda.id] = ComandaComProdutos(
          comanda: comanda,
          produtos: produtos,
          venda: vendaComanda,
        );
        
        // Popula o mapa de produtos por comanda
        _produtosPorComanda[comanda.id] = produtos;
        _vendasPorComanda[comanda.id] = vendaComanda;
      }
      
      // Processa pedidos locais pendentes para adicionar/atualizar comandas
      // IMPORTANTE: Filtra pedidos que já foram processados via evento pedidoCriado
      final comandasIdsLocais = <String>{};
      // Agrupa pedidos locais por comanda para processar todos de uma vez
      // Mas apenas pedidos que ainda NÃO foram processados
      final Map<String, List<PedidoLocal>> pedidosLocaisPorComanda = {};
      for (final pedidoLocal in pedidosLocais) {
        if (pedidoLocal.comandaId == null) continue;
        // Só adiciona se ainda não foi processado via evento
        if (!_pedidosProcessados.contains(pedidoLocal.id)) {
          pedidosLocaisPorComanda.putIfAbsent(pedidoLocal.comandaId!, () => []).add(pedidoLocal);
          // Marca como processado
          _pedidosProcessados.add(pedidoLocal.id);
        }
      }
      
      // Processa pedidos locais por comanda
      for (final entry in pedidosLocaisPorComanda.entries) {
        final comandaId = entry.key;
        final pedidosDaComanda = entry.value;
        
        comandasIdsLocais.add(comandaId);
        
        // Se a comanda já existe no mapa, adiciona produtos locais
        if (comandasMap.containsKey(comandaId)) {
          // Adiciona produtos de TODOS os pedidos locais desta comanda aos produtos existentes
          final produtosExistentes = _produtosParaMapa(_produtosPorComanda[comandaId]!);
          // Processa todos os pedidos locais desta comanda
          for (final pedidoLocal in pedidosDaComanda) {
            _processarItensPedidoLocal(pedidoLocal, produtosExistentes);
          }
          // Atualiza a lista de produtos da comanda
          final produtosAtualizados = _mapaParaProdutosOrdenados(produtosExistentes);
          _produtosPorComanda[comandaId] = produtosAtualizados;
          comandasMap[comandaId] = ComandaComProdutos(
            comanda: comandasMap[comandaId]!.comanda,
            produtos: produtosAtualizados,
            venda: comandasMap[comandaId]!.venda,
          );
        } else {
          // Cria uma comanda "virtual" para pedidos locais pendentes
          // Verifica se já existe na listagem antes de criar usando índice otimizado
          final indiceComandas = _criarIndiceComandas();
          if (indiceComandas.containsKey(comandaId)) {
            debugPrint('⚠️ [MesaDetalhesProvider] Comanda $comandaId já existe na listagem, não criando novamente');
            continue;
          }
          
          debugPrint('📦 Criando comanda virtual para ${pedidosDaComanda.length} pedido(s) local(is) pendente(s) - ComandaId: $comandaId');
          
          final produtosMapLocal = <String, ProdutoAgrupado>{};
          // Processa todos os pedidos locais desta comanda
          double totalComanda = 0.0;
          for (final pedidoLocal in pedidosDaComanda) {
            _processarItensPedidoLocal(pedidoLocal, produtosMapLocal);
            totalComanda += pedidoLocal.total;
          }
          
          final produtosLocal = _mapaParaProdutosOrdenados(produtosMapLocal);
          
          // Busca número real da comanda e cria comanda virtual
          // Se já existe na listagem atual, apenas atualiza produtos usando índice otimizado
          final comandaExistenteIndex = indiceComandas[comandaId];
          
          if (comandaExistenteIndex != null) {
            // Comanda já existe, apenas atualiza produtos
            final comandaExistente = _comandasDaMesa[comandaExistenteIndex];
            comandasMap[comandaId] = ComandaComProdutos(
              comanda: comandaExistente.comanda,
              produtos: produtosLocal,
              venda: comandaExistente.venda,
            );
            _produtosPorComanda[comandaId] = produtosLocal;
          } else {
            // Busca número real da comanda usando método centralizado
            _criarOuAtualizarComandaVirtual(comandaId, produtosLocal, totalComanda);
            
            // Adiciona ao mapa temporário com número temporário (será atualizado depois)
            comandasMap[comandaId] = ComandaComProdutos(
              comanda: ComandaListItemDto(
                id: comandaId,
                numero: comandaId.substring(0, 8), // Temporário até buscar número real
                codigoBarras: null,
                descricao: null,
                status: 'Em Uso',
                ativa: true,
                totalPedidosAtivos: pedidosDaComanda.length,
                valorTotalPedidosAtivos: totalComanda,
                vendaAtualId: null,
                pagamentos: [],
              ),
              produtos: produtosLocal,
              venda: null,
            );
            
            _produtosPorComanda[comandaId] = produtosLocal;
            _vendasPorComanda[comandaId] = null;
          }
        }
      }
      
      // Converte mapa para lista
      final comandasComProdutos = comandasMap.values.toList();

      _comandasDaMesa = comandasComProdutos;
      _carregandoComandas = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao processar comandas: $e');
      _comandasDaMesa = [];
      _carregandoComandas = false;
      notifyListeners();
    }
  }

  /// Carrega venda atual
  /// Se a mesa já foi limpa (venda finalizada), não vai no servidor
  Future<void> loadVendaAtual() async {
    try {
      // Se a venda foi finalizada, não vai no servidor
      if (_vendaFinalizada) {
        debugPrint('ℹ️ [MesaDetalhesProvider] Venda já foi finalizada, não precisa buscar venda do servidor');
        return;
      }
      
      // Se a mesa está limpa (sem produtos/comandas/venda), não precisa ir no servidor
      if (_produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty && _vendaAtual == null) {
        debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa, não precisa buscar venda do servidor');
        return;
      }
      
      if (entidade.tipo == TipoEntidade.mesa) {
        final response = await mesaService.getMesaById(entidade.id);
        if (response.success && response.data != null) {
          _vendaAtual = response.data!.vendaAtual;
          notifyListeners();
        }
      } else {
        // Para comanda, primeiro tenta buscar pela comanda (pode ter vendaAtual)
        final response = await comandaService.getComandaById(entidade.id);
        if (response.success && response.data != null) {
          // Se a comanda retornou vendaAtual, usa ela
          if (response.data!.vendaAtual != null) {
            _vendaAtual = response.data!.vendaAtual;
            notifyListeners();
          } else {
            // Se não retornou vendaAtual, busca venda aberta diretamente
            debugPrint('🔍 Comanda não retornou vendaAtual, buscando venda aberta diretamente...');
            final vendaResponse = await vendaService.getVendaAbertaPorComanda(entidade.id);
            if (vendaResponse.success && vendaResponse.data != null) {
              _vendaAtual = vendaResponse.data;
              notifyListeners();
              debugPrint('✅ Venda aberta encontrada diretamente: ${vendaResponse.data!.id}');
            } else {
              debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
              _vendaAtual = null;
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar venda atual: $e');
    }
  }

  /// Busca venda aberta quando necessário e atualiza o estado apropriado
  /// Retorna a venda encontrada ou null se não encontrada
  Future<VendaDto?> buscarVendaAberta() async {
    String? comandaIdParaBuscar;
    
    if (entidade.tipo == TipoEntidade.comanda) {
      // Se entidade é comanda diretamente, usa o ID da entidade
      comandaIdParaBuscar = entidade.id;
    } else if (_abaSelecionada != null) {
      // Se há aba selecionada (comanda específica), usa o ID da aba
      comandaIdParaBuscar = _abaSelecionada;
    }
    
    if (comandaIdParaBuscar == null) {
      debugPrint('⚠️ Não foi possível determinar comanda para buscar venda');
      return null;
    }
    
    debugPrint('🔍 Buscando venda aberta para comanda: $comandaIdParaBuscar');
    final vendaResponse = await vendaService.getVendaAbertaPorComanda(comandaIdParaBuscar);
    
    if (vendaResponse.success && vendaResponse.data != null) {
      final venda = vendaResponse.data!;
      // Atualiza o estado apropriado
      if (_abaSelecionada == null) {
        _vendaAtual = venda;
      } else {
        _vendasPorComanda[_abaSelecionada!] = venda;
      }
      notifyListeners();
      debugPrint('✅ Venda aberta encontrada: ${venda.id}');
      return venda;
    } else {
      debugPrint('❌ Nenhuma venda aberta encontrada para comanda: $comandaIdParaBuscar');
      return null;
    }
  }

  /// Cria uma nova instância de VendaDto copiando todos os campos da original
  /// e substituindo apenas a lista de pagamentos
  /// Método auxiliar para evitar duplicação de código
  VendaDto _criarVendaComPagamentoAtualizado(
    VendaDto vendaOriginal,
    List<PagamentoVendaDto> pagamentosAtualizados,
  ) {
    return VendaDto(
      id: vendaOriginal.id,
      empresaId: vendaOriginal.empresaId,
      mesaId: vendaOriginal.mesaId,
      comandaId: vendaOriginal.comandaId,
      veiculoId: vendaOriginal.veiculoId,
      mesaNome: vendaOriginal.mesaNome,
      comandaCodigo: vendaOriginal.comandaCodigo,
      veiculoPlaca: vendaOriginal.veiculoPlaca,
      contextoNome: vendaOriginal.contextoNome,
      contextoDescricao: vendaOriginal.contextoDescricao,
      clienteId: vendaOriginal.clienteId,
      clienteNome: vendaOriginal.clienteNome,
      clienteCPF: vendaOriginal.clienteCPF,
      clienteCNPJ: vendaOriginal.clienteCNPJ,
      status: vendaOriginal.status,
      dataCriacao: vendaOriginal.dataCriacao,
      dataFechamento: vendaOriginal.dataFechamento,
      dataPagamento: vendaOriginal.dataPagamento,
      dataCancelamento: vendaOriginal.dataCancelamento,
      subtotal: vendaOriginal.subtotal,
      descontoTotal: vendaOriginal.descontoTotal,
      acrescimoTotal: vendaOriginal.acrescimoTotal,
      impostosTotal: vendaOriginal.impostosTotal,
      freteTotal: vendaOriginal.freteTotal,
      valorTotal: vendaOriginal.valorTotal,
      pagamentos: pagamentosAtualizados,
    );
  }

  /// Adiciona um pagamento à venda local sem ir no servidor
  /// Atualiza a venda em memória com o novo pagamento e recalcula saldo
  void _adicionarPagamentoAVendaLocal({
    required String vendaId,
    required double valor,
  }) {
    try {
      debugPrint('💰 [MesaDetalhesProvider] Adicionando pagamento local: vendaId=$vendaId, valor=$valor');
      debugPrint('   Venda atual: ${_vendaAtual?.id}, Vendas por comanda: ${_vendasPorComanda.keys.toList()}');
      
      // Cria um pagamento temporário com dados mínimos
      // Quando carregar do servidor, virá com todos os dados completos
      final pagamentoTemporario = PagamentoVendaDto(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        vendaId: vendaId,
        tipoFormaPagamento: 2, // Cartão (padrão, será atualizado quando buscar do servidor)
        formaPagamento: 'Pagamento',
        valor: valor,
        status: 2, // StatusPagamento.Confirmado = 2
        dataPagamento: DateTime.now(),
        dataConfirmacao: DateTime.now(),
      );

      // Atualiza venda atual se for a mesma
      if (_vendaAtual != null && _vendaAtual!.id == vendaId) {
        final pagamentosAtualizados = List<PagamentoVendaDto>.from(_vendaAtual!.pagamentos);
        pagamentosAtualizados.add(pagamentoTemporario);
        
        _vendaAtual = _criarVendaComPagamentoAtualizado(_vendaAtual!, pagamentosAtualizados);
        
        debugPrint('✅ [MesaDetalhesProvider] Pagamento adicionado à venda atual. Total pagamentos: ${pagamentosAtualizados.length}, Saldo restante: ${_vendaAtual!.saldoRestante}');
      } else {
        debugPrint('⚠️ [MesaDetalhesProvider] Venda atual não encontrada ou não corresponde (vendaId atual: ${_vendaAtual?.id})');
      }

      // Atualiza vendas por comanda se necessário
      bool encontrouVendaEmComanda = false;
      for (final entry in _vendasPorComanda.entries) {
        final venda = entry.value;
        if (venda != null && venda.id == vendaId) {
          encontrouVendaEmComanda = true;
          final pagamentosAtualizados = List<PagamentoVendaDto>.from(venda.pagamentos);
          pagamentosAtualizados.add(pagamentoTemporario);
          
          final vendaAtualizada = _criarVendaComPagamentoAtualizado(venda, pagamentosAtualizados);
          _vendasPorComanda[entry.key] = vendaAtualizada;
          
          debugPrint('✅ [MesaDetalhesProvider] Pagamento adicionado à venda da comanda ${entry.key}. Total pagamentos: ${pagamentosAtualizados.length}, Saldo restante: ${vendaAtualizada.saldoRestante}');
          
          // IMPORTANTE: Atualiza também o campo venda dentro de ComandaComProdutos
          // para que a UI reflita a mudança imediatamente
          final comandaIndex = _comandasDaMesa.indexWhere((c) => c.comanda.id == entry.key);
          if (comandaIndex != -1) {
            final comandaExistente = _comandasDaMesa[comandaIndex];
            _comandasDaMesa[comandaIndex] = ComandaComProdutos(
              comanda: comandaExistente.comanda,
              produtos: comandaExistente.produtos,
              venda: vendaAtualizada, // Atualiza venda com pagamentos atualizados
            );
            debugPrint('✅ [MesaDetalhesProvider] Venda atualizada na comanda ${entry.key} da listagem (_comandasDaMesa). Saldo restante: ${vendaAtualizada.saldoRestante}');
          } else {
            debugPrint('⚠️ [MesaDetalhesProvider] Comanda ${entry.key} não encontrada em _comandasDaMesa (total: ${_comandasDaMesa.length})');
          }
        }
      }
      
      if (!encontrouVendaEmComanda && _vendaAtual?.id != vendaId) {
        debugPrint('⚠️ [MesaDetalhesProvider] Venda $vendaId não encontrada nem em _vendaAtual nem em _vendasPorComanda');
        debugPrint('   Vendas por comanda disponíveis: ${_vendasPorComanda.entries.map((e) => '${e.key}: ${e.value?.id}').join(', ')}');
      }

      debugPrint('🔄 [MesaDetalhesProvider] Chamando notifyListeners() após adicionar pagamento');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao adicionar pagamento à venda local: $e');
    }
  }

  /// Remove uma comanda específica da listagem quando ela é finalizada
  /// Remove também pagamentos e produtos daquela comanda
  /// Se não sobrar mais nenhuma comanda/pedido, libera a mesa completamente
  void _removerComandaDaListagem(String comandaId) {
    try {
      debugPrint('🧹 [MesaDetalhesProvider] Removendo comanda $comandaId da listagem (incluindo pagamentos)');
      
      // Remove comanda da listagem
      _comandasDaMesa.removeWhere((c) => c.comanda.id == comandaId);
      
      // Remove produtos da comanda
      _produtosPorComanda.remove(comandaId);
      
      // Remove venda da comanda (inclui pagamentos)
      _vendasPorComanda.remove(comandaId);
      
      // Se a aba selecionada era essa comanda, reseta para visão geral
      if (_abaSelecionada == comandaId) {
        _abaSelecionada = null;
      }
      
      // Recalcula produtos agrupados da visão geral (remove produtos dessa comanda)
      _recalcularProdutosAgrupadosVisaoGeral();
      
      debugPrint('✅ [MesaDetalhesProvider] Comanda $comandaId removida da listagem');
      debugPrint('   Comandas restantes: ${_comandasDaMesa.length}');
      debugPrint('   Produtos agrupados: ${_produtosAgrupados.length}');
      
      // NOTA: O evento mesaLiberada será disparado pelo método marcarVendaFinalizada()
      // quando ele verificar que não há mais comandas/pedidos
      // Este método apenas remove a comanda, não dispara eventos
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao remover comanda da listagem: $e');
    }
  }

  /// Recalcula produtos agrupados da visão geral após remover uma comanda
  void _recalcularProdutosAgrupadosVisaoGeral() {
    try {
      // Agrupa produtos de todas as comandas restantes
      final produtosMap = <String, ProdutoAgrupado>{};
      
      for (final comanda in _comandasDaMesa) {
        for (final produto in comanda.produtos) {
          _agruparProdutoNoMapa(
            produtosMap,
            produto.produtoId,
            produto.produtoNome,
            produto.produtoVariacaoId,
            produto.produtoVariacaoNome,
            produto.precoUnitario,
            produto.quantidadeTotal,
            variacaoAtributosValores: produto.variacaoAtributosValores,
          );
        }
      }
      
      // Adiciona produtos de pedidos locais pendentes/sincronizando
      final pedidosLocais = _buscarPedidosLocaisFiltrados();
      for (final pedido in pedidosLocais) {
        _processarItensPedidoLocal(pedido, produtosMap);
      }
      
      _produtosAgrupados = _mapaParaProdutosOrdenados(produtosMap);
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao recalcular produtos agrupados: $e');
    }
  }

  /// Flag para indicar que a venda foi finalizada e mesa está limpa
  /// Usado para evitar chamadas desnecessárias ao servidor
  bool _vendaFinalizada = false;

  /// Marca venda como finalizada de forma SÍNCRONA
  /// Deve ser chamado ANTES de disparar o evento para evitar race conditions
  /// Isso garante que loadProdutos() não vai no servidor mesmo se for chamado antes do listener processar
  /// Se comandaId for fornecido, remove apenas aquela comanda. Se não, limpa tudo.
  /// Se mesaId for fornecido e a mesa puder ser liberada, dispara evento mesaLiberada internamente.
  void marcarVendaFinalizada({String? comandaId, String? mesaId}) {
    debugPrint('🚨 [MesaDetalhesProvider] Marcando venda como finalizada (síncrono) - comandaId: $comandaId, mesaId: $mesaId');
    
    // Determina mesaId se não foi fornecido
    String? mesaIdParaLiberacao = mesaId;
    debugPrint('🔍 [MesaDetalhesProvider] Determinando mesaId para liberação:');
    debugPrint('   mesaId fornecido: $mesaId');
    debugPrint('   entidade.tipo: ${entidade.tipo}');
    debugPrint('   entidade.id: ${entidade.id}');
    debugPrint('   _vendaAtual?.mesaId: ${_vendaAtual?.mesaId}');
    
    if (mesaIdParaLiberacao == null) {
      if (entidade.tipo == TipoEntidade.mesa) {
        mesaIdParaLiberacao = entidade.id;
        debugPrint('   ✅ Usando entidade.id (mesa): $mesaIdParaLiberacao');
      } else if (entidade.tipo == TipoEntidade.comanda) {
        // Tenta buscar mesaId da venda atual ou das vendas por comanda
        mesaIdParaLiberacao = _vendaAtual?.mesaId;
        if (mesaIdParaLiberacao == null && _vendasPorComanda.isNotEmpty) {
          // Busca mesaId da primeira venda disponível
          for (final venda in _vendasPorComanda.values) {
            if (venda?.mesaId != null) {
              mesaIdParaLiberacao = venda!.mesaId;
              debugPrint('   ✅ Encontrado mesaId em _vendasPorComanda: $mesaIdParaLiberacao');
              break;
            }
          }
        }
        // Se ainda não encontrou, tenta buscar da primeira comanda
        if (mesaIdParaLiberacao == null && _comandasDaMesa.isNotEmpty) {
          mesaIdParaLiberacao = _comandasDaMesa.first.venda?.mesaId;
          debugPrint('   ✅ Encontrado mesaId em _comandasDaMesa: $mesaIdParaLiberacao');
        }
        if (mesaIdParaLiberacao == null) {
          debugPrint('   ⚠️ Não foi possível determinar mesaId para comanda');
        }
      }
    } else {
      debugPrint('   ✅ Usando mesaId fornecido: $mesaIdParaLiberacao');
    }
    
    // Se tem comandaId, remove apenas aquela comanda
    if (comandaId != null) {
      debugPrint('🚨 [MesaDetalhesProvider] Removendo apenas comanda $comandaId');
      _removerComandaDaListagem(comandaId);
      
      // Verifica se ainda há comandas restantes
      final pedidosLocaisRestantes = _buscarPedidosLocaisFiltrados();
      if (_comandasDaMesa.isEmpty && 
          _produtosAgrupados.isEmpty && 
          pedidosLocaisRestantes.isEmpty &&
          _vendaAtual == null &&
          _vendasPorComanda.isEmpty) {
        debugPrint('🚨 [MesaDetalhesProvider] Não há mais comandas, liberando mesa completamente');
        _vendaFinalizada = true;
        _limparDadosMesa();
        
        // Dispara evento mesaLiberada se tiver mesaId
        if (mesaIdParaLiberacao != null) {
          debugPrint('✅ [MesaDetalhesProvider] Disparando evento mesaLiberada para mesa $mesaIdParaLiberacao');
          AppEventBus.instance.dispararMesaLiberada(mesaId: mesaIdParaLiberacao);
        }
      }
    } else {
      // Não tem comandaId, limpa tudo
      _vendaFinalizada = true;
      _limparDadosMesa();
      
      // Dispara evento mesaLiberada se tiver mesaId
      if (mesaIdParaLiberacao != null) {
        debugPrint('✅ [MesaDetalhesProvider] Disparando evento mesaLiberada para mesa $mesaIdParaLiberacao');
        AppEventBus.instance.dispararMesaLiberada(mesaId: mesaIdParaLiberacao);
      }
    }
  }

  /// Limpa todos os dados da mesa quando venda é finalizada
  /// Reseta produtos, comandas, vendas e deixa mesa livre (sem ir no servidor)
  void _limparDadosMesa() {
    try {
      debugPrint('🧹 [MesaDetalhesProvider] Limpando dados da mesa após venda finalizada');
      
      // Flag já foi setada por marcarVendaFinalizada() ou pelo listener
      // Não precisa setar novamente aqui (evita duplicação)
      
      // Limpa produtos
      _produtosAgrupados = [];
      _produtosPorComanda.clear();
      
      // Limpa comandas
      _comandasDaMesa = [];
      
      // Limpa vendas
      _vendaAtual = null;
      _vendasPorComanda.clear();
      
      // Reseta aba selecionada
      _abaSelecionada = null;
      
      // Atualiza status da mesa para livre
      _statusMesa = 'livre';
      
      // Limpa pedidos processados
      _pedidosProcessados.clear();
      
      // Reseta contadores
      _pedidosPendentes = 0;
      _pedidosSincronizando = 0;
      _pedidosComErro = 0;
      
      // Reseta flags de loading
      _isLoading = false;
      _carregandoProdutos = false;
      _carregandoComandas = false;
      _errorMessage = null;
      
      debugPrint('✅ [MesaDetalhesProvider] Dados da mesa limpos. Mesa agora está livre');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao limpar dados da mesa: $e');
    }
  }

  @override
  void dispose() {
    // Cancela todas as subscriptions de eventos
    for (final subscription in _eventBusSubscriptions) {
      subscription.cancel();
    }
    _eventBusSubscriptions.clear();
    super.dispose();
  }
}
