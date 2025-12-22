import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../widgets/app_header.dart';
import '../../../presentation/providers/pedido_provider.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import 'components/categoria_navigation_tree.dart';
import 'components/pedido_resumo_panel.dart';
import 'dialogs/selecionar_mesa_comanda_dialog.dart';

/// Tela de criação de novo pedido para restaurante
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId; // ID da mesa (opcional)
  final String? comandaId; // ID da comanda (opcional)
  final bool isModal; // Indica se deve ser exibido como modal

  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.isModal = false,
  });

  /// Mostra o novo pedido de forma adaptativa:
  /// - Mobile: Tela cheia (Navigator.push)
  /// - Desktop/Tablet: Modal (showDialog)
  static Future<bool?> show(
    BuildContext context, {
    String? mesaId,
    String? comandaId,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    
    // Mobile: usa tela cheia
    if (adaptive?.isMobile ?? true) {
      return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: NovoPedidoRestauranteScreen(
              mesaId: mesaId,
              comandaId: comandaId,
              isModal: false,
            ),
          ),
        ),
      );
    }
    
    // Desktop/Tablet: usa modal
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveLayout(
        child: NovoPedidoRestauranteScreen(
          mesaId: mesaId,
          comandaId: comandaId,
          isModal: true,
        ),
      ),
    );
  }

  @override
  State<NovoPedidoRestauranteScreen> createState() => _NovoPedidoRestauranteScreenState();
}

class _NovoPedidoRestauranteScreenState extends State<NovoPedidoRestauranteScreen> {
  MesaListItemDto? _mesa;
  ComandaListItemDto? _comanda;

  void _fecharLoadingSeAberto(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Erro ao fechar loading: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Inicializar pedido quando a tela é aberta
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
        final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
        
        // Mostra loading enquanto verifica/abre sessão
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Carrega configuração do restaurante se necessário
        if (!servicesProvider.configuracaoRestauranteCarregada) {
          await servicesProvider.carregarConfiguracaoRestaurante();
        }
        
        if (!mounted) {
          _fecharLoadingSeAberto(context);
          return;
        }
        
        final configRestaurante = servicesProvider.configuracaoRestaurante;
        String? mesaIdFinal = widget.mesaId;
        String? comandaIdFinal = widget.comandaId;

        // Validação: Se configuração é PorComanda e veio de mesa sem comanda, exige seleção de comanda
        if (configRestaurante != null && 
            configRestaurante.controlePorComanda && 
            widget.mesaId != null && 
            widget.comandaId == null) {
          // Fecha o loading atual antes de abrir o dialog
          _fecharLoadingSeAberto(context);
          
          if (!mounted) return;
          
          // Abre dialog para selecionar comanda (mesa já pré-selecionada)
          final resultado = await SelecionarMesaComandaDialog.show(
            context,
            mesaIdPreSelecionada: widget.mesaId,
            permiteVendaAvulsa: false, // Não permite venda avulsa quando vem de mesa
          );
          
          if (!mounted) return;
          
          if (resultado == null || resultado.comanda == null) {
            // Usuário cancelou ou não selecionou comanda obrigatória
            Navigator.of(context).pop(); // Volta para tela anterior
            return;
          }
          
          comandaIdFinal = resultado.comanda!.id;
          mesaIdFinal = resultado.mesa?.id ?? widget.mesaId; // Mantém mesa original se não mudou
          
          // Mostra loading novamente após seleção
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Busca dados da mesa/comanda se houver
        if (mesaIdFinal != null && mounted) {
          final mesaResponse = await servicesProvider.mesaService.getMesaById(mesaIdFinal);
          if (mesaResponse.success && mesaResponse.data != null && mounted) {
            setState(() {
              _mesa = mesaResponse.data;
            });
          }
        }

        if (comandaIdFinal != null && mounted) {
          final comandaResponse = await servicesProvider.comandaService.getComandaById(comandaIdFinal);
          if (comandaResponse.success && comandaResponse.data != null && mounted) {
            setState(() {
              _comanda = comandaResponse.data;
            });
          }
        }

        if (!mounted) {
          _fecharLoadingSeAberto(context);
          return;
        }

        // Validação final antes de iniciar pedido
        if (configRestaurante != null && configRestaurante.controlePorComanda && comandaIdFinal == null) {
          _fecharLoadingSeAberto(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comanda é obrigatória para criar pedido'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(); // Volta para tela anterior
          return;
        }

        final sucesso = await pedidoProvider.iniciarNovoPedido(
          mesaId: mesaIdFinal,
          comandaId: comandaIdFinal,
          context: context,
        );

        if (!mounted) {
          _fecharLoadingSeAberto(context);
          return;
        }

        // Fecha o loading
        _fecharLoadingSeAberto(context);

        // Se usuário cancelou a abertura de sessão, volta para tela anterior
        if (!sucesso && widget.mesaId != null && mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;
        
        // Fecha o loading se ainda estiver aberto
        _fecharLoadingSeAberto(context);
        
        debugPrint('Erro ao inicializar pedido: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao inicializar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    
    // Conteúdo comum
    Widget buildContent() {
      return Column(
        children: [
          // Banner destacado com informações da mesa/comanda (apenas em tela cheia, não no modal)
          if (!widget.isModal && (_mesa != null || _comanda != null))
            _buildMesaComandaBanner(),
          // Conteúdo principal
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 1024;
                
                if (isMobile) {
                  // Layout mobile: painel como bottom sheet ou aba
                  return Stack(
                    children: [
                      CategoriaNavigationTree(
                        onProdutoSelected: (produto) {
                          debugPrint('Produto selecionado: ${produto.produtoNome}');
                        },
                      ),
                      // Botão flutuante para abrir resumo do pedido
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Consumer<PedidoProvider>(
                          builder: (context, pedidoProvider, child) {
                            if (pedidoProvider.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return FloatingActionButton.extended(
                              onPressed: () {
                                _mostrarResumoPedidoMobile(context);
                              },
                              backgroundColor: AppTheme.primaryColor,
                              icon: Stack(
                                children: [
                                  const Icon(Icons.shopping_cart, color: Colors.white),
                                  if (pedidoProvider.quantidadeTotal > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          '${pedidoProvider.quantidadeTotal}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: Text(
                                'R\$ ${pedidoProvider.total.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // Layout desktop: divisão lado a lado
                  return Row(
                    children: [
                      // Área principal de navegação (70% da largura)
                      Expanded(
                        flex: 7,
                        child: CategoriaNavigationTree(
                          onProdutoSelected: (produto) {
                            debugPrint('Produto selecionado: ${produto.produtoNome}');
                          },
                        ),
                      ),
                      // Painel lateral com resumo do pedido (30% da largura, mínimo 350px)
                      Container(
                        width: 400,
                        constraints: const BoxConstraints(minWidth: 350, maxWidth: 500),
                        child: PedidoResumoPanel(
                          onFinalizarPedido: () {
                            _finalizarPedido(context);
                          },
                          onLimparPedido: () {
                            // O botão de limpar já está no header do painel
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      );
    }

    // Modal: usa Dialog
    if (widget.isModal && adaptive != null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: adaptive.isDesktop ? 40 : 20,
          vertical: adaptive.isDesktop ? 20 : 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: adaptive.isDesktop ? 1400 : 1200,
            maxHeight: MediaQuery.of(context).size.height * 0.95,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header do modal com informações da mesa/comanda
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 16 : 20,
                  vertical: adaptive.isMobile ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Ícone
                    Icon(
                      Icons.add_shopping_cart,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    SizedBox(width: adaptive.isMobile ? 10 : 12),
                    // Título e informações da mesa/comanda
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Novo Pedido',
                            style: GoogleFonts.inter(
                              fontSize: adaptive.isMobile ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_mesa != null || _comanda != null) ...[
                            SizedBox(width: adaptive.isMobile ? 12 : 16),
                            _buildMesaComandaHeaderCompact(),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              // Conteúdo com scroll
              Expanded(
                child: buildContent(),
              ),
            ],
          ),
        ),
      );
    }

    // Tela cheia: usa Scaffold (mobile)
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppHeader(
        title: 'Novo Pedido',
        subtitle: 'Em edição',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: buildContent(),
    );
  }

  /// Header compacto para modal mostrando mesa/comanda
  Widget _buildMesaComandaHeaderCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mesa != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant,
                  size: 12,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Mesa ${_mesa!.numero}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_mesa != null && _comanda != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward,
              size: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        if (_comanda != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.successColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 12,
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Comanda ${_comanda!.numero}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Banner compacto mostrando mesa/comanda vinculada ao pedido
  Widget _buildMesaComandaBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_mesa != null) ...[
            _buildBadge(
              icon: Icons.table_restaurant,
              label: _mesa!.numero,
              color: AppTheme.primaryColor,
            ),
          ],
          if (_mesa != null && _comanda != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 1,
                height: 24,
                color: Colors.grey.shade300,
              ),
            ),
          if (_comanda != null)
            _buildBadge(
              icon: Icons.receipt_long,
              label: _comanda!.numero,
              color: Colors.indigo,
            ),
        ],
      ),
    );
  }

  /// Badge compacto com ícone e número
  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _finalizarPedido(BuildContext context) async {
    final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
    
    if (pedidoProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item ao pedido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Finaliza o pedido e salva na base local
      final pedidoIdSalvo = await pedidoProvider.finalizarPedido();

      if (!context.mounted) return;

      // Fecha o loading
      Navigator.of(context).pop();

      if (pedidoIdSalvo != null) {
        // A sincronização é automática via listener do Hive
        // Não precisa chamar manualmente
        
        // Mostra mensagem de sucesso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pedido finalizado! Sincronizando...',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Volta para a tela anterior após um breve delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao finalizar pedido. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      // Fecha o loading se ainda estiver aberto
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao finalizar pedido: $e'),
          backgroundColor: Colors.red,
      ),
    );
    }
  }

  void _mostrarResumoPedidoMobile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Conteúdo do resumo
              Expanded(
                child: PedidoResumoPanel(
                  onFinalizarPedido: () {
                    Navigator.of(context).pop();
                    _finalizarPedido(context);
                  },
                  onLimparPedido: () {
                    // O botão de limpar já está no header do painel
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
