import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/item_pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../screens/pedidos/restaurante/modals/selecionar_produto_modal.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/events/app_event_bus.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'services_provider.dart';

/// Provider para gerenciar o pedido em construção
class PedidoProvider extends ChangeNotifier {
  PedidoLocal? _pedidoAtual;
  final _pedidoRepo = PedidoLocalRepository();
  MesaService? _mesaService;
  ComandaService? _comandaService;

  PedidoLocal? get pedidoAtual => _pedidoAtual;
  
  /// Define o serviço de mesa (deve ser injetado)
  set mesaService(MesaService service) {
    _mesaService = service;
  }

  /// Define o serviço de comanda (deve ser injetado)
  set comandaService(ComandaService service) {
    _comandaService = service;
  }

  /// Total do pedido
  double get total => _pedidoAtual?.total ?? 0.0;

  /// Quantidade total de itens
  int get quantidadeTotal => _pedidoAtual?.quantidadeTotal ?? 0;

  /// Lista de itens do pedido
  List<ItemPedidoLocal> get itens => _pedidoAtual?.itens ?? [];

  /// Verifica se o pedido está vazio
  bool get isEmpty => _pedidoAtual == null || _pedidoAtual!.itens.isEmpty;

  PedidoProvider() {
    _inicializarPedido();
  }

  /// Inicializa um novo pedido
  void _inicializarPedido({
    String? mesaId,
    String? comandaId,
  }) {
    _pedidoAtual = PedidoLocal(
      id: const Uuid().v4(), // Gera um novo ID para cada pedido
      mesaId: mesaId,
      comandaId: comandaId,
    );
    notifyListeners();
  }

  /// Inicia um novo pedido
  /// A venda será criada automaticamente no backend quando o primeiro pedido for enviado
  Future<bool> iniciarNovoPedido({
    String? mesaId,
    String? comandaId,
    BuildContext? context,
  }) async {
    _inicializarPedido(
      mesaId: mesaId,
      comandaId: comandaId,
    );
    
    return true;
  }

  /// Adiciona itens ao pedido a partir do resultado da seleção de produto
  void adicionarItens(ProdutoSelecionadoResult resultado) {
    if (_pedidoAtual == null) {
      _inicializarPedido();
    }

    for (var itemSelecionado in resultado.itens) {
      final itemPedido = ItemPedidoLocal(
        id: const Uuid().v4(),
        produtoId: itemSelecionado.produtoId,
        produtoNome: itemSelecionado.produtoNome,
        produtoVariacaoId: itemSelecionado.produtoVariacaoId,
        produtoVariacaoNome: itemSelecionado.produtoVariacaoNome,
        precoUnitario: itemSelecionado.precoUnitario,
        quantidade: 1,
        observacoes: itemSelecionado.observacoes,
        proporcoesAtributos: itemSelecionado.proporcoesAtributos,
        valoresAtributosSelecionados: itemSelecionado.valoresAtributosSelecionados,
        componentesRemovidos: itemSelecionado.componentesRemovidos,
      );

      _pedidoAtual!.adicionarItem(itemPedido);
    }

    notifyListeners();
  }

  /// Remove um item do pedido
  void removerItem(String itemId) {
    if (_pedidoAtual == null) return;
    _pedidoAtual!.removerItem(itemId);
    notifyListeners();
  }

  /// Atualiza a quantidade de um item
  void atualizarQuantidadeItem(String itemId, int novaQuantidade) {
    if (_pedidoAtual == null) return;
    if (novaQuantidade <= 0) {
      removerItem(itemId);
      return;
    }
    _pedidoAtual!.atualizarQuantidadeItem(itemId, novaQuantidade);
    notifyListeners();
  }

  /// Atualiza um item existente (componentes removidos e observações)
  void atualizarItem(ItemPedidoLocal itemAtualizado) {
    if (_pedidoAtual == null) return;
    
    final index = _pedidoAtual!.itens.indexWhere((item) => item.id == itemAtualizado.id);
    if (index == -1) return;
    
    _pedidoAtual!.itens[index] = itemAtualizado;
    _pedidoAtual!.dataAtualizacao = DateTime.now();
    notifyListeners();
  }

  /// Limpa todos os itens do pedido
  void limparPedido() {
    if (_pedidoAtual == null) return;
    _pedidoAtual!.limparItens();
    notifyListeners();
  }

  /// Define observações gerais do pedido
  void setObservacoesGeral(String? observacoes) {
    if (_pedidoAtual == null) {
      _inicializarPedido();
    }
    _pedidoAtual!.observacoesGeral = observacoes;
    _pedidoAtual!.dataAtualizacao = DateTime.now();
    notifyListeners();
  }

  /// Finaliza o pedido atual e salva na base local para sincronização
  /// Retorna o ID do pedido salvo se foi finalizado com sucesso, null caso contrário
  Future<String?> finalizarPedido() async {
    if (_pedidoAtual == null || _pedidoAtual!.itens.isEmpty) {
      return null;
    }

    try {
      // Preserva mesaId e comandaId antes de limpar
      final mesaId = _pedidoAtual!.mesaId;
      final comandaId = _pedidoAtual!.comandaId;

      // Marca o pedido como pendente de sincronização
      _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
      _pedidoAtual!.syncAttempts = 0;
      _pedidoAtual!.dataAtualizacao = DateTime.now();

      // Salva na base local
      await _pedidoRepo.upsert(_pedidoAtual!);
      
      // Armazena ID do pedido antes de limpar
      final pedidoIdSalvo = _pedidoAtual!.id;
      
      // O evento pedidoCriado será disparado pelo AutoSyncManager quando detectar
      // a mudança no Hive, garantindo que o pedido já está salvo

      // Limpa o pedido atual para permitir criar um novo, preservando mesa/comanda
      _inicializarPedido(
        mesaId: mesaId,
        comandaId: comandaId,
      );

      notifyListeners();
      
      debugPrint('📦 Pedido $pedidoIdSalvo salvo localmente');
      return pedidoIdSalvo;
    } catch (e) {
      debugPrint('Erro ao finalizar pedido: $e');
      return null;
    }
  }
}

