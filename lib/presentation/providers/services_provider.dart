import 'package:flutter/foundation.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/services/modules/restaurante/configuracao_restaurante_service.dart';
import '../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../data/services/core/produto_service.dart';
import '../../data/services/core/pedido_service.dart';
import '../../data/services/core/exibicao_produto_service.dart';
import '../../data/services/core/venda_service.dart';
import '../../data/services/sync/sync_service.dart';
import '../../data/services/sync/auto_sync_manager.dart';
import '../../data/repositories/produto_local_repository.dart';
import '../../data/repositories/exibicao_produto_local_repository.dart';
import '../../data/repositories/pedido_local_repository.dart';
import 'sync_provider.dart';

/// Provider para serviços compartilhados
/// Garante que todos os serviços usem o mesmo ApiClient do AuthService
class ServicesProvider extends ChangeNotifier {
  final AuthService _authService;
  late final MesaService _mesaService;
  late final ComandaService _comandaService;
  late final ConfiguracaoRestauranteService _configuracaoRestauranteService;
  late final ProdutoService _produtoService;
  late final PedidoService _pedidoService;
  late final ExibicaoProdutoService _exibicaoProdutoService;
  late final VendaService _vendaService;

  /// Serviço de autenticação
  AuthService get authService => _authService;

  /// Serviço de mesas
  MesaService get mesaService => _mesaService;

  /// Serviço de comandas
  ComandaService get comandaService => _comandaService;

  /// Serviço de configuração do restaurante
  ConfiguracaoRestauranteService get configuracaoRestauranteService => _configuracaoRestauranteService;

  /// Serviço de produtos
  ProdutoService get produtoService => _produtoService;

  /// Serviço de pedidos
  PedidoService get pedidoService => _pedidoService;

  /// Serviço de exibição de produtos
  ExibicaoProdutoService get exibicaoProdutoService => _exibicaoProdutoService;
  
  /// Serviço de vendas
  VendaService get vendaService => _vendaService;

  // Repositories locais
  late final ProdutoLocalRepository _produtoLocalRepo;
  late final ExibicaoProdutoLocalRepository _exibicaoLocalRepo;
  late final PedidoLocalRepository _pedidoLocalRepo;

  // Serviços de sincronização
  late final SyncService _syncService;
  late final SyncProvider _syncProvider;
  late final AutoSyncManager _autoSyncManager;

  // Cache de configuração do restaurante
  ConfiguracaoRestauranteDto? _configuracaoRestaurante;
  bool _configuracaoRestauranteCarregada = false;

  ServicesProvider(this._authService) {
    // Usa o mesmo ApiClient do AuthService para garantir que o token seja compartilhado
    _mesaService = MesaService(apiClient: _authService.apiClient);
    _comandaService = ComandaService(apiClient: _authService.apiClient);
    _configuracaoRestauranteService = ConfiguracaoRestauranteService(apiClient: _authService.apiClient);
    _produtoService = ProdutoService(apiClient: _authService.apiClient);
    _pedidoService = PedidoService(apiClient: _authService.apiClient);
    _exibicaoProdutoService = ExibicaoProdutoService(apiClient: _authService.apiClient);
    _vendaService = VendaService(apiClient: _authService.apiClient);
    
    // Inicializar repositories locais
    _produtoLocalRepo = ProdutoLocalRepository();
    _exibicaoLocalRepo = ExibicaoProdutoLocalRepository();
    _pedidoLocalRepo = PedidoLocalRepository();
    
    // Criar serviços de sincronização
    _syncService = SyncService(
      apiClient: _authService.apiClient,
      produtoRepo: _produtoLocalRepo,
      exibicaoRepo: _exibicaoLocalRepo,
      pedidoRepo: _pedidoLocalRepo,
      pedidoService: _pedidoService,
      configuracaoRestauranteService: _configuracaoRestauranteService,
    );
    
    // Criar provider de sincronização
    _syncProvider = SyncProvider(
      syncService: _syncService,
      produtoRepo: _produtoLocalRepo,
      exibicaoRepo: _exibicaoLocalRepo,
    );
    
    // Criar gerenciador de sincronização automática
    _autoSyncManager = AutoSyncManager(
      syncService: _syncService,
      pedidoRepo: _pedidoLocalRepo,
    );
    
    debugPrint('ServicesProvider criado com AuthService: ${_authService.hashCode}');
    debugPrint('ApiClient usado: ${_authService.apiClient.hashCode}');
  }

  /// Inicializa repositories (abre boxes do Hive)
  /// Deve ser chamado após a inicialização do Hive
  Future<void> initRepositories() async {
    await _produtoLocalRepo.init();
    await _exibicaoLocalRepo.init();
    
    // Inicializa sincronização automática após abrir repositories
    await _autoSyncManager.initialize();
  }

  /// Repository de produtos local
  ProdutoLocalRepository get produtoLocalRepo => _produtoLocalRepo;

  /// Repository de exibição local
  ExibicaoProdutoLocalRepository get exibicaoLocalRepo => _exibicaoLocalRepo;

  /// Serviço de sincronização
  SyncService get syncService => _syncService;

  /// Provider de sincronização
  SyncProvider get syncProvider => _syncProvider;
  
  /// Gerenciador de sincronização automática
  AutoSyncManager get autoSyncManager => _autoSyncManager;

  // === CONFIGURAÇÃO DO RESTAURANTE ===

  /// Configuração do restaurante (cacheada)
  ConfiguracaoRestauranteDto? get configuracaoRestaurante => _configuracaoRestaurante;

  /// Indica se a configuração já foi carregada (mesmo que seja null)
  bool get configuracaoRestauranteCarregada => _configuracaoRestauranteCarregada;

  /// Carrega a configuração do restaurante do servidor
  /// Se já foi carregada, retorna o valor em cache (a menos que forceRefresh = true)
  Future<void> carregarConfiguracaoRestaurante({bool forceRefresh = false}) async {
    if (_configuracaoRestauranteCarregada && !forceRefresh) {
      debugPrint('📋 Configuração do restaurante já está em cache');
      return;
    }

    try {
      debugPrint('📋 Carregando configuração do restaurante...');
      final response = await _configuracaoRestauranteService.getConfiguracao();
      
      if (response.success) {
        _configuracaoRestaurante = response.data;
        _configuracaoRestauranteCarregada = true;
        
        if (_configuracaoRestaurante != null) {
          debugPrint('✅ Configuração carregada: TipoControleVenda=${_configuracaoRestaurante!.tipoControleVenda} (${_configuracaoRestaurante!.controlePorMesa ? "PorMesa" : "PorComanda"})');
        } else {
          debugPrint('⚠️ Configuração não encontrada (null)');
        }
        
        notifyListeners();
      } else {
        debugPrint('❌ Erro ao carregar configuração: ${response.message}');
      }
    } catch (e) {
      debugPrint('❌ Exceção ao carregar configuração: $e');
    }
  }

  /// Limpa o cache da configuração (útil quando muda de empresa ou faz logout)
  void limparConfiguracaoRestaurante() {
    _configuracaoRestaurante = null;
    _configuracaoRestauranteCarregada = false;
    notifyListeners();
  }
}

