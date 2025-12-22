import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/models/modules/restaurante/comanda_filter.dart';
import '../../data/models/core/api_response.dart';
import '../../data/models/core/paginated_response.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import 'detalhes_comanda_screen.dart';
import '../mesas/detalhes_produtos_mesa_screen.dart';
import '../../models/mesas/entidade_produtos.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Tela de listagem de comandas (Restaurante)
class ComandasScreen extends StatefulWidget {
  /// Se deve ocultar o AppBar (usado quando acessada via bottom navigation)
  final bool hideAppBar;
  /// ID da comanda para selecionar automaticamente ao carregar
  final String? comandaId;

  const ComandasScreen({
    super.key,
    this.hideAppBar = false,
    this.comandaId,
  });

  @override
  State<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends State<ComandasScreen> {
  List<ComandaListItemDto> _comandas = [];
  List<ComandaListItemDto> _filteredComandas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 1000; // Carregar todas as comandas de uma vez
  bool _hasMore = true;
  final TextEditingController _searchController = TextEditingController();
  ComandaListItemDto? _selectedComanda; // Comanda selecionada para layout desktop
  final _pedidoRepo = PedidoLocalRepository();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterComandas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComandas();
      // Garante que a box de pedidos está aberta
      _pedidoRepo.getAll();
      // Escuta mudanças nos pedidos para atualizar seleção automaticamente
      _setupPedidosListener();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quando a tela volta ao foco, verifica se há comanda para selecionar automaticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _comandas.isNotEmpty && _selectedComanda == null) {
        _selecionarComandaComPedidosPendentes();
      }
    });
  }

  /// Configura listener para pedidos locais e atualiza seleção quando há novos pedidos
  void _setupPedidosListener() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return;
    }

    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    box.listenable().addListener(_onPedidosChanged);
  }

  /// Callback quando há mudanças nos pedidos locais
  void _onPedidosChanged() {
    if (!mounted || _comandas.isEmpty) {
      return;
    }

    // Se não há comanda selecionada, tenta selecionar automaticamente
    if (_selectedComanda == null) {
      _selecionarComandaComPedidosPendentes();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Remove listener de pedidos
    if (Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
      box.listenable().removeListener(_onPedidosChanged);
    }
    super.dispose();
  }

  void _filterComandas() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredComandas = _comandas;
      } else {
        _filteredComandas = _comandas.where((comanda) {
          final numero = comanda.numero.toLowerCase().trim();
          final codigoBarras = (comanda.codigoBarras ?? '').toLowerCase();
          final descricao = (comanda.descricao ?? '').toLowerCase();
          final status = comanda.status.toLowerCase();
          
          return numero.contains(query) || 
                 codigoBarras.contains(query) ||
                 descricao.contains(query) || 
                 status.contains(query);
        }).toList();
      }
    });
  }

  ComandaService get _comandaService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.comandaService;
  }

  Future<void> _loadComandas({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _comandas = [];
        _hasMore = true;
        _errorMessage = null;
      });
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _comandaService.searchComandas(
        page: _currentPage,
        pageSize: _pageSize,
        filter: ComandaFilterDto(ativa: true), // Apenas comandas ativas
      );

      if (response.success && response.data != null) {
        final paginatedData = response.data!;
        setState(() {
          if (refresh) {
            _comandas = paginatedData.list;
          } else {
            _comandas.addAll(paginatedData.list);
          }
          _filteredComandas = _comandas;
          _hasMore = paginatedData.pagination.page < paginatedData.pagination.totalPages;
          _currentPage++;
          _isLoading = false;
        });

        // Selecionar comanda automaticamente se comandaId foi fornecido
        if (widget.comandaId != null && _selectedComanda == null) {
          _selecionarComandaPorId(widget.comandaId!);
        } else if (widget.comandaId == null && _selectedComanda == null) {
          // Se não há comandaId fornecido, tenta selecionar automaticamente
          // a comanda que tem pedidos pendentes (mais recente)
          _selecionarComandaComPedidosPendentes();
        }
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar comandas: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Seleciona uma comanda por ID automaticamente
  void _selecionarComandaPorId(String comandaId) {
    try {
      final comanda = _comandas.firstWhere(
        (c) => c.id == comandaId,
      );
      
      final adaptive = AdaptiveLayoutProvider.of(context);
      if (adaptive != null && !adaptive.isMobile) {
        // Desktop: seleciona na lista
        setState(() {
          _selectedComanda = comanda;
        });
      } else {
        // Mobile: navega para tela de detalhes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesComandaScreen(comanda: comanda),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Comanda $comandaId não encontrada na lista: $e');
      // Comanda não encontrada, não faz nada
    }
  }

  /// Seleciona automaticamente a comanda que tem pedidos pendentes (mais recente)
  void _selecionarComandaComPedidosPendentes() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return;
    }

    try {
      final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
      final pedidosPendentes = box.values
          .where((p) => 
              p.comandaId != null && 
              p.comandaId!.isNotEmpty &&
              p.syncStatus != SyncStatusPedido.sincronizado)
          .toList();

      if (pedidosPendentes.isEmpty) {
        return;
      }

      // Ordena por data de criação (mais recente primeiro)
      pedidosPendentes.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
      
      // Pega a comanda do pedido mais recente
      final comandaIdMaisRecente = pedidosPendentes.first.comandaId!;
      
      // Busca a comanda na lista
      try {
        final comanda = _comandas.firstWhere(
          (c) => c.id == comandaIdMaisRecente,
        );

        final adaptive = AdaptiveLayoutProvider.of(context);
        if (adaptive != null && !adaptive.isMobile) {
          // Desktop: seleciona na lista
          setState(() {
            _selectedComanda = comanda;
          });
          debugPrint('✅ Comanda ${comanda.numero} selecionada automaticamente (tem pedidos pendentes)');
        }
        // Mobile: não navega automaticamente, apenas seleciona se estiver na lista
      } catch (e) {
        debugPrint('⚠️ Comanda $comandaIdMaisRecente não encontrada na lista: $e');
        // Não faz nada se não encontrar
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao selecionar comanda com pedidos pendentes: $e');
      // Não faz nada se não encontrar
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return AppTheme.successColor;
      case 'em uso':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: widget.hideAppBar
          ? null
          : AppHeader(
        title: 'Comandas',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadComandas(refresh: true),
            tooltip: 'Atualizar',
            color: AppTheme.textPrimary,
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de pesquisa
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Pesquisar por número ou código de barras...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: adaptive.isMobile ? 14 : 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: adaptive.isMobile ? 20 : 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade400,
                            size: adaptive.isMobile ? 20 : 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : const SizedBox.shrink(),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: adaptive.isMobile ? 16 : 20,
                    vertical: adaptive.isMobile ? 14 : 16,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 15 : 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          // Lista de comandas - Layout responsivo
          Expanded(
            child: adaptive.isMobile
                ? _buildMobileLayout(adaptive)
                : _buildDesktopLayout(adaptive),
          ),
        ],
      ),
    );
  }

  /// Calcula o número de colunas dinamicamente baseado na largura disponível
  int _calculateColumnsCount(AdaptiveLayoutProvider adaptive, double availableWidth) {
    if (adaptive.isMobile) {
      return 2; // Mobile sempre 2 colunas
    }
    
    // Tamanho mínimo desejado para cada card (incluindo espaçamento)
    const double minCardWidth = 140.0;
    const double spacing = 12.0;
    const double padding = 24.0 * 2;
    
    final double usableWidth = availableWidth - padding;
    final int columns = (usableWidth / (minCardWidth + spacing)).floor();
    
    return columns.clamp(2, 10);
  }

  Widget _buildMobileLayout(AdaptiveLayoutProvider adaptive) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadComandas(refresh: true),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _comandas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredComandas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Nenhuma comanda encontrada'
                  : 'Nenhuma comanda cadastrada',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _filteredComandas.length,
      itemBuilder: (context, index) {
        final comanda = _filteredComandas[index];
        return _buildComandaCard(comanda, adaptive);
      },
    );
  }

  Widget _buildDesktopLayout(AdaptiveLayoutProvider adaptive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula largura disponível para o grid (40% da tela)
        final double gridWidth = constraints.maxWidth * 0.4;
        final int columnsCount = _calculateColumnsCount(adaptive, gridWidth);
        
        return Row(
          children: [
            // Coluna esquerda: GridView de comandas
            Expanded(
              flex: 4, // 40% da largura
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => _loadComandas(refresh: true),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : _isLoading && _comandas.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredComandas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchController.text.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.receipt_long_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Nenhuma comanda encontrada'
                                        : 'Nenhuma comanda cadastrada',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadComandas(refresh: true),
                              child: GridView.builder(
                                padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnsCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: adaptive.isDesktop ? 1.0 : 1.05,
                                ),
                                itemCount: _filteredComandas.length,
                                itemBuilder: (context, index) {
                                  final comanda = _filteredComandas[index];
                                  final isSelected = _selectedComanda?.id == comanda.id;
                                  return _buildComandaCard(comanda, adaptive, isSelected: isSelected);
                                },
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: false,
                              ),
                            ),
            ),
            // Divisor vertical
            Container(
              width: 1,
              color: Colors.grey.shade300,
            ),
            // Coluna direita: Detalhes da comanda selecionada
            Expanded(
              flex: 6, // 60% da largura
              child: _selectedComanda == null
                  ? _buildEmptyDetailsPanel(adaptive)
                  : DetalhesProdutosMesaScreen(
                      key: ValueKey('comanda_detalhes_${_selectedComanda!.id}'),
                      entidade: MesaComandaInfo(
                        id: _selectedComanda!.id,
                        numero: _selectedComanda!.numero,
                        descricao: _selectedComanda!.descricao,
                        status: _selectedComanda!.status,
                        tipo: TipoEntidade.comanda,
                        codigoBarras: _selectedComanda!.codigoBarras,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Painel vazio quando nenhuma comanda está selecionada
  Widget _buildEmptyDetailsPanel(AdaptiveLayoutProvider adaptive) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Selecione uma comanda para ver os detalhes',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComandaCard(ComandaListItemDto comanda, AdaptiveLayoutProvider adaptive, {bool isSelected = false}) {
    final isEmUso = comanda.status.toLowerCase() == 'em uso' || comanda.temVendaAtiva;
    final statusColor = _getStatusColor(comanda.status);
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Material(
      color: Colors.transparent,
      key: ValueKey('comanda_${comanda.numero}_${comanda.id}'),
      child: InkWell(
        onTap: () {
          if (adaptive.isMobile) {
            // Mobile: navega para tela de detalhes
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesComandaScreen(comanda: comanda),
                ),
              ),
            );
          } else {
            // Desktop: atualiza seleção
            setState(() {
              _selectedComanda = comanda;
            });
          }
        },
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isEmUso 
                      ? statusColor.withOpacity(0.3)
                      : Colors.grey.shade200),
              width: isSelected ? 2 : (isEmUso ? 2 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: isEmUso
                    ? statusColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(adaptive.isDesktop ? 8.0 : (adaptive.isMobile ? 8.0 : 10.0)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone e número lado a lado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(adaptive.isDesktop ? 6 : (adaptive.isMobile ? 6 : 8)),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(adaptive.isDesktop ? 8 : (adaptive.isMobile ? 8 : 10)),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: adaptive.isDesktop ? 18 : (adaptive.isMobile ? 18 : 20),
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: adaptive.isDesktop ? 6 : (adaptive.isMobile ? 6 : 8)),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: double.infinity,
                          ),
                          child: Text(
                            comanda.numero,
                            style: GoogleFonts.inter(
                              fontSize: adaptive.isDesktop ? 14 : (adaptive.isMobile ? 14 : 16),
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: adaptive.isDesktop ? 6 : (adaptive.isMobile ? 6 : 8)),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.isDesktop ? 8 : (adaptive.isMobile ? 8 : 10),
                      vertical: adaptive.isDesktop ? 4 : (adaptive.isMobile ? 4 : 5),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(adaptive.isDesktop ? 6 : (adaptive.isMobile ? 6 : 8)),
                    ),
                    child: Text(
                      comanda.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isDesktop ? 9 : (adaptive.isMobile ? 9 : 10),
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Informações adicionais (se houver pedidos)
                  if (comanda.totalPedidosAtivos > 0) ...[
                    SizedBox(height: adaptive.isDesktop ? 4 : (adaptive.isMobile ? 4 : 6)),
                    Text(
                      currencyFormat.format(comanda.valorTotalPedidosAtivos),
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isDesktop ? 11 : (adaptive.isMobile ? 11 : 12),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
