import 'package:flutter/foundation.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/item_pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../screens/pedidos/restaurante/modals/selecionar_produto_modal.dart';
import 'package:uuid/uuid.dart';

/// Provider para gerenciar o pedido em construção
/// Responsável apenas pelo gerenciamento de estado do pedido local
class PedidoProvider extends ChangeNotifier {
  PedidoLocal? _pedidoAtual;
  final _pedidoRepo = PedidoLocalRepository();

  PedidoLocal? get pedidoAtual => _pedidoAtual;

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
  }) async {
    debugPrint('📝 [PedidoProvider] iniciarNovoPedido chamado:');
    debugPrint('  - MesaId: $mesaId');
    debugPrint('  - ComandaId: $comandaId');
    
    _inicializarPedido(
      mesaId: mesaId,
      comandaId: comandaId,
    );
    
    debugPrint('📝 [PedidoProvider] Pedido inicializado:');
    debugPrint('  - MesaId no pedido: ${_pedidoAtual?.mesaId}');
    debugPrint('  - ComandaId no pedido: ${_pedidoAtual?.comandaId}');
    
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

      debugPrint('💾 [PedidoProvider] Finalizando pedido:');
      debugPrint('  - PedidoId: ${_pedidoAtual!.id}');
      debugPrint('  - MesaId preservado: $mesaId');
      debugPrint('  - ComandaId preservado: $comandaId');

      // Marca o pedido como pendente de sincronização
      _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
      _pedidoAtual!.syncAttempts = 0;
      _pedidoAtual!.dataAtualizacao = DateTime.now();

      // Salva na base local
      debugPrint('💾 [PedidoProvider] Salvando pedido no Hive:');
      debugPrint('  - PedidoId: ${_pedidoAtual!.id}');
      debugPrint('  - MesaId ANTES do upsert: ${_pedidoAtual!.mesaId}');
      debugPrint('  - ComandaId ANTES do upsert: ${_pedidoAtual!.comandaId}');
      
      await _pedidoRepo.upsert(_pedidoAtual!);
      
      // Verificar se foi salvo corretamente lendo de volta
      final pedidos = await _pedidoRepo.getAll();
      final pedidoSalvo = pedidos.firstWhere(
        (p) => p.id == _pedidoAtual!.id,
        orElse: () => throw Exception('Pedido não encontrado após salvar'),
      );
      
      debugPrint('💾 [PedidoProvider] Pedido lido do Hive após salvar:');
      debugPrint('  - PedidoId: ${pedidoSalvo.id}');
      debugPrint('  - MesaId APÓS ler do Hive: ${pedidoSalvo.mesaId}');
      debugPrint('  - ComandaId APÓS ler do Hive: ${pedidoSalvo.comandaId}');
      
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

