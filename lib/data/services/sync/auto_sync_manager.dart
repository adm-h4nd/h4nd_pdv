import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../repositories/pedido_local_repository.dart';
import '../../models/local/pedido_local.dart';
import '../../models/local/sync_status_pedido.dart';
import '../../../core/events/app_event_bus.dart';
import 'sync_service.dart';
import 'package:hive/hive.dart';

/// Gerenciador de sincronização automática de pedidos
/// Centraliza toda a sincronização em um único ponto:
/// 1. Listener do Hive detecta pedidos pendentes e sincroniza automaticamente
/// 2. Timer periódico para retry de pedidos com erro
/// 3. Notifica quando pedidos são sincronizados para atualizar as telas
class AutoSyncManager {
  final SyncService _syncService;
  final PedidoLocalRepository _pedidoRepo;
  
  StreamSubscription<BoxEvent>? _pedidoBoxSubscription;
  Timer? _retryTimer;
  bool _isInitialized = false;
  
  // Rastreia status anterior dos pedidos para detectar mudanças
  final Map<String, SyncStatusPedido> _statusAnteriorPorPedido = {};
  
  // Callback para notificar quando um pedido é sincronizado com sucesso
  // Parâmetros: (pedidoId, mesaId?, comandaId?)
  // Mantido para compatibilidade, mas eventos são disparados via AppEventBus
  Function(String pedidoId, String? mesaId, String? comandaId)? onPedidoSincronizado;
  
  AutoSyncManager({
    required SyncService syncService,
    required PedidoLocalRepository pedidoRepo,
  })  : _syncService = syncService,
        _pedidoRepo = pedidoRepo;

  /// Inicializa o gerenciador de sincronização automática
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ AutoSyncManager já está inicializado');
      return;
    }
    
    debugPrint('🚀 Inicializando AutoSyncManager...');
    
    try {
      // Garante que a box está aberta
      await _pedidoRepo.getAll();
      
      // Carrega status inicial de todos os pedidos
      await _carregarStatusInicial();
      
      await _setupListener();
      _startRetryTimer();
      _isInitialized = true;
      debugPrint('✅ AutoSyncManager inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar AutoSyncManager: $e');
      // Tenta novamente após um delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isInitialized) {
          initialize();
        }
      });
    }
  }

  /// Carrega status inicial de todos os pedidos para rastrear mudanças
  Future<void> _carregarStatusInicial() async {
    try {
      final pedidos = await _pedidoRepo.getAll();
      _statusAnteriorPorPedido.clear();
      for (final pedido in pedidos) {
        _statusAnteriorPorPedido[pedido.id] = pedido.syncStatus;
      }
      debugPrint('📊 Status inicial carregado para ${pedidos.length} pedidos');
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar status inicial: $e');
    }
  }

  /// Configura listener do Hive para detectar mudanças
  /// ÚNICO lugar que escuta BoxEvent do Hive
  Future<void> _setupListener() async {
    try {
      // Usa watch() do repository para escutar mudanças na box
      final stream = await _pedidoRepo.watch();
      _pedidoBoxSubscription = stream.listen((event) {
        // Processa TODAS as mudanças (incluindo deleções) em background
        Future.microtask(() => _processarMudancaPedido(event));
      });
      debugPrint('👂 Listener do Hive configurado (único responsável por escutar BoxEvent)');
    } catch (e) {
      debugPrint('⚠️ Erro ao configurar listener: $e');
      // Tenta novamente após um delay
      Future.delayed(const Duration(seconds: 2), () async {
        if (!_isInitialized) return;
        await _setupListener();
      });
    }
  }

  /// Processa mudança detectada no Hive
  /// Dispara eventos de negócio apropriados via AppEventBus
  Future<void> _processarMudancaPedido(BoxEvent event) async {
    try {
      // Processa deleção de pedido
      if (event.deleted) {
        final pedidoRemovido = event.value as PedidoLocal?;
        if (pedidoRemovido != null && pedidoRemovido.mesaId != null) {
          debugPrint('🗑️ [AutoSyncManager] Pedido ${pedidoRemovido.id} removido da mesa ${pedidoRemovido.mesaId}');
          
          // Dispara evento de pedido removido
          AppEventBus.instance.dispararPedidoRemovido(
            pedidoId: pedidoRemovido.id,
            mesaId: pedidoRemovido.mesaId!,
            comandaId: pedidoRemovido.comandaId,
          );
          
          // Remove do rastreamento
          _statusAnteriorPorPedido.remove(pedidoRemovido.id);
        }
        return;
      }
      
      // Processa pedido criado/modificado
      final pedido = event.value as PedidoLocal?;
      if (pedido == null) return;
      
      final statusAnterior = _statusAnteriorPorPedido[pedido.id];
      final statusAtual = pedido.syncStatus;
      
      // Detecta mudança de status
      if (statusAnterior != statusAtual) {
        debugPrint('🔄 [AutoSyncManager] Pedido ${pedido.id} mudou status: $statusAnterior → $statusAtual');
        
        // Dispara eventos baseado na mudança de status
        _dispararEventosPorMudancaStatus(
          pedido: pedido,
          statusAnterior: statusAnterior,
          statusAtual: statusAtual,
        );
        
        // Atualiza status anterior
        _statusAnteriorPorPedido[pedido.id] = statusAtual;
      }
      
      // Se é um pedido novo (não estava no rastreamento)
      if (statusAnterior == null && statusAtual == SyncStatusPedido.pendente) {
        debugPrint('📦 [AutoSyncManager] Novo pedido detectado: ${pedido.id}');
        
        // Dispara evento de pedido criado
        if (pedido.mesaId != null) {
          AppEventBus.instance.dispararPedidoCriado(
            pedidoId: pedido.id,
            mesaId: pedido.mesaId!,
            comandaId: pedido.comandaId,
          );
        }
        
        // Atualiza rastreamento
        _statusAnteriorPorPedido[pedido.id] = statusAtual;
      }
      
      // Processa sincronização de pedidos pendentes
      if (statusAtual == SyncStatusPedido.pendente &&
          !_syncService.isPedidoSincronizando(pedido.id)) {
        // Aguarda um pouco para evitar processamento muito rápido
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Verifica novamente o status antes de sincronizar
        final pedidos = await _pedidoRepo.getAll();
        final pedidoAtualizado = pedidos.firstWhere(
          (p) => p.id == pedido.id,
          orElse: () => pedido,
        );
        
        // Sincroniza apenas se ainda estiver pendente e não estiver sendo sincronizado
        if (pedidoAtualizado.syncStatus == SyncStatusPedido.pendente &&
            !_syncService.isPedidoSincronizando(pedidoAtualizado.id)) {
          debugPrint('🔄 [AutoSyncManager] Iniciando sincronização do pedido ${pedido.id}');
          await _sincronizarPedido(pedidoAtualizado);
        }
      }
      // Pedidos com erro são tratados apenas pelo timer periódico para evitar spam
    } catch (e) {
      debugPrint('❌ Erro ao processar mudança de pedido: $e');
    }
  }
  
  /// Dispara eventos apropriados baseado na mudança de status
  void _dispararEventosPorMudancaStatus({
    required PedidoLocal pedido,
    required SyncStatusPedido? statusAnterior,
    required SyncStatusPedido statusAtual,
  }) {
    if (pedido.mesaId == null) return;
    
    // Status mudou para sincronizando
    if (statusAtual == SyncStatusPedido.sincronizando &&
        statusAnterior != SyncStatusPedido.sincronizando) {
      AppEventBus.instance.dispararPedidoSincronizando(
        pedidoId: pedido.id,
        mesaId: pedido.mesaId!,
        comandaId: pedido.comandaId,
      );
    }
    
    // Status mudou para sincronizado
    if (statusAtual == SyncStatusPedido.sincronizado &&
        statusAnterior != SyncStatusPedido.sincronizado) {
      AppEventBus.instance.dispararPedidoSincronizado(
        pedidoId: pedido.id,
        mesaId: pedido.mesaId!,
        comandaId: pedido.comandaId,
      );
      
      // Mantém compatibilidade com callback antigo
      if (onPedidoSincronizado != null) {
        onPedidoSincronizado!(pedido.id, pedido.mesaId, pedido.comandaId);
      }
    }
    
    // Status mudou para erro
    if (statusAtual == SyncStatusPedido.erro &&
        statusAnterior != SyncStatusPedido.erro) {
      AppEventBus.instance.dispararPedidoErro(
        pedidoId: pedido.id,
        mesaId: pedido.mesaId!,
        comandaId: pedido.comandaId,
        erro: pedido.lastSyncError,
      );
    }
  }

  /// Sincroniza um pedido (usado para pendentes e retry de erros)
  Future<void> _sincronizarPedido(PedidoLocal pedido) async {
    if (_syncService.isPedidoSincronizando(pedido.id)) {
      debugPrint('⚠️ Pedido ${pedido.id} já está sendo sincronizado, ignorando...');
      return; // Já está sincronizando
    }
    
    try {
      final sucesso = await _syncService.sincronizarPedidoIndividual(pedido.id);
      if (sucesso) {
        debugPrint('✅ [AutoSyncManager] Pedido ${pedido.id} sincronizado com sucesso');
        // O evento será disparado automaticamente pelo listener quando detectar mudança de status
        // Não precisa disparar manualmente aqui
      } else {
        debugPrint('⚠️ Pedido ${pedido.id} falhou na sincronização, será tentado novamente pelo timer');
        // O evento de erro será disparado automaticamente pelo listener quando detectar mudança de status
      }
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar pedido ${pedido.id}: $e');
    }
  }

  /// Inicia timer periódico para retry de pedidos com erro e limpeza de status travado
  void _startRetryTimer() {
    _retryTimer?.cancel();
    
    // Timer a cada 30 segundos para retry de pedidos com erro
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final pedidos = await _pedidoRepo.getAll();
        
        // Limpa pedidos que ficaram travados em "sincronizando" há mais de 2 minutos
        final agora = DateTime.now();
        for (final pedido in pedidos) {
          if (pedido.syncStatus == SyncStatusPedido.sincronizando) {
            // Se está sincronizando há mais de 2 minutos, provavelmente travou
            final tempoSincronizando = pedido.dataAtualizacao != null
                ? agora.difference(pedido.dataAtualizacao!)
                : const Duration(minutes: 10);
            
            if (tempoSincronizando.inMinutes > 2) {
              debugPrint('⚠️ Pedido ${pedido.id} travado em sincronizando há ${tempoSincronizando.inMinutes}min, resetando...');
              final statusAnterior = pedido.syncStatus;
              pedido.syncStatus = SyncStatusPedido.erro;
              pedido.lastSyncError = 'Sincronização travada, tentando novamente';
              await _pedidoRepo.upsert(pedido);
              
              // Dispara evento de erro (o listener também detectará, mas garantimos aqui)
              if (pedido.mesaId != null && statusAnterior != SyncStatusPedido.erro) {
                AppEventBus.instance.dispararPedidoErro(
                  pedidoId: pedido.id,
                  mesaId: pedido.mesaId!,
                  comandaId: pedido.comandaId,
                  erro: pedido.lastSyncError,
                );
              }
            }
          }
        }
        
        // Busca pedidos com erro para retry
        final pedidosComErro = pedidos
            .where((p) => 
                p.syncStatus == SyncStatusPedido.erro &&
                p.syncAttempts < 5) // Limite de 5 tentativas
            .toList();
        
        if (pedidosComErro.isEmpty) return;
        
        debugPrint('🔄 Timer: Encontrados ${pedidosComErro.length} pedidos com erro para retry');
        
        // Sincroniza um pedido por vez para evitar sobrecarga
        for (final pedido in pedidosComErro) {
          if (_syncService.isPedidoSincronizando(pedido.id)) continue;
          
          await _sincronizarPedido(pedido);
          
          // Aguarda um pouco entre sincronizações
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('❌ Erro no timer de retry: $e');
      }
    });
    
    debugPrint('⏰ Timer de retry iniciado (30s)');
  }

  /// Método mantido para compatibilidade, mas não faz nada
  /// A sincronização é feita automaticamente pelo listener do Hive
  /// quando o pedido é salvo com status pendente
  @Deprecated('Use apenas o listener automático. Este método não faz mais nada.')
  Future<void> sincronizarPedidoImediato(String pedidoId) async {
    debugPrint('ℹ️ sincronizarPedidoImediato chamado para $pedidoId, mas a sincronização é automática via listener');
    // Não faz nada - o listener já detecta e sincroniza automaticamente
  }

  /// Para o gerenciador (útil para cleanup)
  void dispose() {
    debugPrint('🛑 Parando AutoSyncManager...');
    _pedidoBoxSubscription?.cancel();
    _retryTimer?.cancel();
    _isInitialized = false;
    debugPrint('✅ AutoSyncManager parado');
  }
}

