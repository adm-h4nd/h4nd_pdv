import 'dart:async';
import 'package:flutter/foundation.dart';

/// Tipos de eventos do sistema
/// Organizados por domínio para facilitar manutenção
enum TipoEvento {
  // === MESAS ===
  /// Pedido criado localmente
  pedidoCriado,
  
  /// Pedido começou a sincronizar
  pedidoSincronizando,
  
  /// Pedido sincronizado com sucesso
  pedidoSincronizado,
  
  /// Pedido com erro na sincronização
  pedidoErro,
  
  /// Pedido removido do Hive
  pedidoRemovido,
  
  /// Pedido finalizado no servidor
  pedidoFinalizado,
  
  /// Venda finalizada (pagamento completo)
  vendaFinalizada,
  
  /// Comanda paga
  comandaPaga,
  
  /// Mesa liberada
  mesaLiberada,
  
  /// Status da mesa mudou (qualquer mudança)
  statusMesaMudou,
  
  /// Mesa transferida (requer atualização do servidor)
  mesaTransferida,
  
  // === PRODUTOS ===
  /// Produto criado
  produtoCriado,
  
  /// Produto atualizado
  produtoAtualizado,
  
  /// Produto deletado
  produtoDeletado,
  
  /// Produto sincronizado
  produtoSincronizado,
  
  // === VENDAS ===
  /// Venda criada
  vendaCriada,
  
  /// Venda cancelada
  vendaCancelada,
  
  /// Pagamento processado
  pagamentoProcessado,
  
  /// Venda balcão pendente criada (aguardando pagamento)
  vendaBalcaoPendenteCriada,
  
  // === SINCRONIZAÇÃO ===
  /// Sincronização iniciada
  sincronizacaoIniciada,
  
  /// Sincronização concluída
  sincronizacaoConcluida,
  
  /// Erro na sincronização
  sincronizacaoErro,
  
  // === AUTENTICAÇÃO ===
  /// Usuário logado
  usuarioLogado,
  
  /// Usuário deslogado
  usuarioDeslogado,
  
  /// Token expirado
  tokenExpirado,
}

/// Domínios do sistema
enum DominioEvento {
  mesa,
  produto,
  venda,
  sincronizacao,
  autenticacao,
}

/// Evento genérico do sistema
class AppEvent {
  final TipoEvento tipo;
  final DominioEvento dominio;
  final Map<String, dynamic>? dados;
  final DateTime timestamp;

  AppEvent({
    required this.tipo,
    required this.dominio,
    this.dados,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Getters auxiliares para facilitar acesso aos dados
  
  String? get mesaId => dados?['mesaId'] as String?;
  String? get comandaId => dados?['comandaId'] as String?;
  String? get pedidoId => dados?['pedidoId'] as String?;
  String? get vendaId => dados?['vendaId'] as String?;
  String? get produtoId => dados?['produtoId'] as String?;
  String? get usuarioId => dados?['usuarioId'] as String?;
  String? get erro => dados?['erro'] as String?;
  
  /// Retorna o valor de uma chave específica
  T? get<T>(String key) => dados?[key] as T?;

  @override
  String toString() {
    return 'AppEvent(tipo: $tipo, dominio: $dominio, dados: $dados, timestamp: $timestamp)';
  }
}

/// Event Bus centralizado para todos os eventos do sistema
/// Similar ao Observable do Angular - permite múltiplos listeners
/// 
/// Uso:
/// ```dart
/// // Disparar evento
/// AppEventBus.instance.disparar(AppEvent(
///   tipo: TipoEvento.vendaFinalizada,
///   dominio: DominioEvento.mesa,
///   dados: {'mesaId': '123', 'vendaId': '456'},
/// ));
/// 
/// // Escutar eventos
/// AppEventBus.instance.on(TipoEvento.vendaFinalizada).listen((evento) {
///   // Fazer algo
/// });
/// ```
class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  AppEventBus._internal();

  // StreamController para todos os eventos
  final StreamController<AppEvent> _eventController = StreamController<AppEvent>.broadcast();

  /// Stream de todos os eventos
  Stream<AppEvent> get stream => _eventController.stream;

  /// Dispara um evento para todos os listeners
  void disparar(AppEvent evento) {
    debugPrint('📢 [AppEventBus] Disparando evento: $evento');
    _eventController.add(evento);
  }

  /// Retorna um stream filtrado por tipo de evento
  Stream<AppEvent> on(TipoEvento tipo) {
    return stream.where((evento) => evento.tipo == tipo);
  }

  /// Retorna um stream filtrado por domínio
  Stream<AppEvent> onDominio(DominioEvento dominio) {
    return stream.where((evento) => evento.dominio == dominio);
  }

  /// Retorna um stream filtrado por tipo E domínio
  Stream<AppEvent> onTipoEDominio(TipoEvento tipo, DominioEvento dominio) {
    return stream.where((evento) => evento.tipo == tipo && evento.dominio == dominio);
  }

  /// Retorna um stream filtrado por mesaId
  Stream<AppEvent> onMesa(String mesaId) {
    return stream.where((evento) => evento.mesaId == mesaId);
  }

  /// Retorna um stream filtrado por produtoId
  Stream<AppEvent> onProduto(String produtoId) {
    return stream.where((evento) => evento.produtoId == produtoId);
  }

  // ========== MÉTODOS AUXILIARES POR DOMÍNIO ==========

  // === MESAS ===
  
  void dispararPedidoCriado({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoCriado,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararPedidoSincronizando({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoSincronizando,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararPedidoSincronizado({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoSincronizado,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararPedidoErro({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
    String? erro,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoErro,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
        if (erro != null) 'erro': erro,
      },
    ));
  }

  void dispararPedidoRemovido({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoRemovido,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararPedidoFinalizado({
    required String pedidoId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pedidoFinalizado,
      dominio: DominioEvento.mesa,
      dados: {
        'pedidoId': pedidoId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararVendaFinalizada({
    required String vendaId,
    required String mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.vendaFinalizada,
      dominio: DominioEvento.mesa,
      dados: {
        'vendaId': vendaId,
        'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararComandaPaga({
    required String comandaId,
    required String mesaId,
    String? vendaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.comandaPaga,
      dominio: DominioEvento.mesa,
      dados: {
        'comandaId': comandaId,
        'mesaId': mesaId,
        if (vendaId != null) 'vendaId': vendaId,
      },
    ));
  }

  void dispararMesaLiberada({
    required String mesaId,
  }) {
    debugPrint('🚀 [AppEventBus] Disparando evento mesaLiberada para mesa: $mesaId');
    disparar(AppEvent(
      tipo: TipoEvento.mesaLiberada,
      dominio: DominioEvento.mesa,
      dados: {'mesaId': mesaId},
    ));
    debugPrint('✅ [AppEventBus] Evento mesaLiberada disparado');
  }

  void dispararStatusMesaMudou({
    required String mesaId,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.statusMesaMudou,
      dominio: DominioEvento.mesa,
      dados: {
        'mesaId': mesaId,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararMesaTransferida({
    required String mesaId,
  }) {
    debugPrint('📢 [AppEventBus] Disparando evento mesaTransferida para mesa: $mesaId');
    disparar(AppEvent(
      tipo: TipoEvento.mesaTransferida,
      dominio: DominioEvento.mesa,
      dados: {
        'mesaId': mesaId,
      },
    ));
    debugPrint('✅ [AppEventBus] Evento mesaTransferida disparado');
  }

  // === PRODUTOS ===

  void dispararProdutoCriado({
    required String produtoId,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.produtoCriado,
      dominio: DominioEvento.produto,
      dados: {
        'produtoId': produtoId,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararProdutoAtualizado({
    required String produtoId,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.produtoAtualizado,
      dominio: DominioEvento.produto,
      dados: {
        'produtoId': produtoId,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararProdutoDeletado({
    required String produtoId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.produtoDeletado,
      dominio: DominioEvento.produto,
      dados: {'produtoId': produtoId},
    ));
  }

  void dispararProdutoSincronizado({
    required String produtoId,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.produtoSincronizado,
      dominio: DominioEvento.produto,
      dados: {
        'produtoId': produtoId,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  // === VENDAS ===

  void dispararVendaCriada({
    required String vendaId,
    String? mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.vendaCriada,
      dominio: DominioEvento.venda,
      dados: {
        'vendaId': vendaId,
        if (mesaId != null) 'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararVendaCancelada({
    required String vendaId,
    String? mesaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.vendaCancelada,
      dominio: DominioEvento.venda,
      dados: {
        'vendaId': vendaId,
        if (mesaId != null) 'mesaId': mesaId,
      },
    ));
  }

  void dispararPagamentoProcessado({
    required String vendaId,
    required double valor,
    String? mesaId,
    String? comandaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.pagamentoProcessado,
      dominio: DominioEvento.venda,
      dados: {
        'vendaId': vendaId,
        'valor': valor,
        if (mesaId != null) 'mesaId': mesaId,
        if (comandaId != null) 'comandaId': comandaId,
      },
    ));
  }

  void dispararVendaBalcaoPendenteCriada({
    required String vendaId,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.vendaBalcaoPendenteCriada,
      dominio: DominioEvento.venda,
      dados: {
        'vendaId': vendaId,
      },
    ));
  }

  // === SINCRONIZAÇÃO ===

  void dispararSincronizacaoIniciada({
    String? tipo, // 'produtos', 'pedidos', 'tudo'
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.sincronizacaoIniciada,
      dominio: DominioEvento.sincronizacao,
      dados: {
        if (tipo != null) 'tipo': tipo,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararSincronizacaoConcluida({
    String? tipo,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.sincronizacaoConcluida,
      dominio: DominioEvento.sincronizacao,
      dados: {
        if (tipo != null) 'tipo': tipo,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararSincronizacaoErro({
    required String erro,
    String? tipo,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.sincronizacaoErro,
      dominio: DominioEvento.sincronizacao,
      dados: {
        'erro': erro,
        if (tipo != null) 'tipo': tipo,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  // === AUTENTICAÇÃO ===

  void dispararUsuarioLogado({
    required String usuarioId,
    Map<String, dynamic>? dadosExtras,
  }) {
    disparar(AppEvent(
      tipo: TipoEvento.usuarioLogado,
      dominio: DominioEvento.autenticacao,
      dados: {
        'usuarioId': usuarioId,
        if (dadosExtras != null) ...dadosExtras,
      },
    ));
  }

  void dispararUsuarioDeslogado() {
    disparar(AppEvent(
      tipo: TipoEvento.usuarioDeslogado,
      dominio: DominioEvento.autenticacao,
    ));
  }

  void dispararTokenExpirado() {
    disparar(AppEvent(
      tipo: TipoEvento.tokenExpirado,
      dominio: DominioEvento.autenticacao,
    ));
  }

  /// Fecha o stream (útil para cleanup)
  void dispose() {
    _eventController.close();
  }

  /// Singleton instance
  static AppEventBus get instance => _instance;
}
