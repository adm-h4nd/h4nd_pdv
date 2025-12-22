import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../data/services/modules/restaurante/mesa_service.dart';
import '../../../../data/services/modules/restaurante/comanda_service.dart';
import '../../../../data/services/core/venda_service.dart';
import '../../../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../../../data/models/modules/restaurante/mesa_filter.dart';
import '../../../../data/models/modules/restaurante/comanda_filter.dart';
import '../../../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../../../data/models/core/api_response.dart';
import '../../../../data/models/core/paginated_response.dart';
import 'package:google_fonts/google_fonts.dart';

/// Resultado da seleção de mesa e comanda
class SelecaoMesaComandaResult {
  final MesaListItemDto? mesa;
  final ComandaListItemDto? comanda;

  SelecaoMesaComandaResult({
    this.mesa,
    this.comanda,
  });

  bool get temSelecao => mesa != null || comanda != null;
}

/// Dialog para selecionar mesa e/ou comanda antes de criar um pedido
class SelecionarMesaComandaDialog extends StatefulWidget {
  final String? mesaIdPreSelecionada;
  final String? comandaIdPreSelecionada;
  final bool permiteVendaAvulsa; // Permite criar pedido sem mesa/comanda

  const SelecionarMesaComandaDialog({
    super.key,
    this.mesaIdPreSelecionada,
    this.comandaIdPreSelecionada,
    this.permiteVendaAvulsa = false,
  });

  @override
  State<SelecionarMesaComandaDialog> createState() => _SelecionarMesaComandaDialogState();

  /// Mostra o dialog e retorna o resultado da seleção
  static Future<SelecaoMesaComandaResult?> show(
    BuildContext context, {
    String? mesaIdPreSelecionada,
    String? comandaIdPreSelecionada,
    bool permiteVendaAvulsa = false,
  }) async {
    return showDialog<SelecaoMesaComandaResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveLayout(
        child: SelecionarMesaComandaDialog(
          mesaIdPreSelecionada: mesaIdPreSelecionada,
          comandaIdPreSelecionada: comandaIdPreSelecionada,
          permiteVendaAvulsa: permiteVendaAvulsa,
        ),
      ),
    );
  }
}

class _SelecionarMesaComandaDialogState extends State<SelecionarMesaComandaDialog> {
  MesaListItemDto? _mesaSelecionada;
  ComandaListItemDto? _comandaSelecionada;
  String? _mesaIdVinculadaComanda; // ID da mesa vinculada à venda da comanda (se houver)
  
  // Controle de busca de mesas
  final TextEditingController _mesaSearchController = TextEditingController();
  List<MesaListItemDto> _mesasDisponiveis = [];
  bool _carregandoMesas = false;
  bool _mostrarListaMesas = false;
  
  // Controle de busca de comandas
  final TextEditingController _comandaSearchController = TextEditingController();
  List<ComandaListItemDto> _comandasDisponiveis = [];
  bool _carregandoComandas = false;
  bool _mostrarListaComandas = false;

  MesaService get _mesaService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.mesaService;
  }

  ComandaService get _comandaService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.comandaService;
  }

  ServicesProvider get _servicesProvider {
    return Provider.of<ServicesProvider>(context, listen: false);
  }

  VendaService get _vendaService {
    return _servicesProvider.vendaService;
  }

  ConfiguracaoRestauranteDto? get _configuracaoRestaurante {
    return _servicesProvider.configuracaoRestaurante;
  }

  /// Verifica se deve mostrar seleção de comanda
  bool get _mostrarSelecaoComanda {
    // Se configuração é PorMesa, não mostra comanda
    if (_configuracaoRestaurante != null && _configuracaoRestaurante!.controlePorMesa) {
      return false;
    }
    return true;
  }

  /// Verifica se comanda é obrigatória
  bool get _comandaObrigatoria {
    // Se configuração é PorComanda, comanda é obrigatória
    if (_configuracaoRestaurante != null && _configuracaoRestaurante!.controlePorComanda) {
      return true; // Sempre obrigatória quando controle é por comanda
    }
    return false;
  }

  /// Verifica se mesa é obrigatória
  bool get _mesaObrigatoria {
    // Se configuração é PorMesa, mesa é obrigatória
    if (_configuracaoRestaurante != null && _configuracaoRestaurante!.controlePorMesa) {
      return true;
    }
    // Se veio de tela de comanda, mesa é opcional
    if (widget.comandaIdPreSelecionada != null) {
      return false;
    }
    // Caso contrário, segue configuração padrão
    return false;
  }

  @override
  void initState() {
    super.initState();
    _mesaSearchController.addListener(_onMesaSearchChanged);
    _comandaSearchController.addListener(_onComandaSearchChanged);
    
    // Carrega configuração se ainda não foi carregada
    if (!_servicesProvider.configuracaoRestauranteCarregada) {
      _servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
        debugPrint('⚠️ Erro ao carregar configuração: $e');
      });
    }
    
    // Se há pré-seleção, busca os dados
    if (widget.mesaIdPreSelecionada != null) {
      _buscarMesaPreSelecionada();
    }
    if (widget.comandaIdPreSelecionada != null) {
      _buscarComandaPreSelecionada();
    }
  }

  Future<void> _buscarMesaPreSelecionada() async {
    try {
      final response = await _mesaService.getMesaById(widget.mesaIdPreSelecionada!);
      if (response.success && response.data != null) {
        setState(() {
          _mesaSelecionada = response.data;
          _mesaSearchController.text = response.data!.numero;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar mesa pré-selecionada: $e');
    }
  }

  Future<void> _buscarComandaPreSelecionada() async {
    try {
      final response = await _comandaService.getComandaById(widget.comandaIdPreSelecionada!);
      if (response.success && response.data != null) {
        setState(() {
          _comandaSelecionada = response.data;
          _comandaSearchController.text = response.data!.numero;
        });
        
        // Buscar venda aberta da comanda para validar mesa vinculada
        if (_configuracaoRestaurante?.controlePorComanda == true) {
          try {
            final vendaResponse = await _vendaService.getVendaAbertaPorComanda(widget.comandaIdPreSelecionada!);
            
            if (vendaResponse.success && vendaResponse.data != null && vendaResponse.data!.mesaId != null) {
              final venda = vendaResponse.data!;
              _mesaIdVinculadaComanda = venda.mesaId;
              
              // Se tem mesa pré-selecionada e é diferente da mesa vinculada, mostrar erro e limpar comanda
              if (widget.mesaIdPreSelecionada != null && widget.mesaIdPreSelecionada != venda.mesaId) {
                // Armazena dados antes de limpar
                final numeroComanda = response.data!.numero;
                final nomeMesaVinculada = venda.mesaNome ?? 'desconhecida';
                
                // Limpa a comanda selecionada (não muda a mesa)
                setState(() {
                  _comandaSelecionada = null;
                  _comandaSearchController.clear();
                  _mesaIdVinculadaComanda = null;
                });
                
                // Mostra dialog de erro
                await AppDialog.showError(
                  context: context,
                  title: 'Comanda já vinculada',
                  message: 'A comanda $numeroComanda já está vinculada à mesa $nomeMesaVinculada. '
                      'Todos os pedidos desta comanda devem ser feitos na mesma mesa.\n\n'
                      'Por favor, selecione outra comanda.',
                );
                return; // Não preenche mesa automaticamente
              } else {
                // Preenche mesa automaticamente se não tinha mesa pré-selecionada
                if (widget.mesaIdPreSelecionada == null) {
                  final mesaResponse = await _mesaService.getMesaById(venda.mesaId!);
                  if (mesaResponse.success && mesaResponse.data != null) {
                    setState(() {
                      _mesaSelecionada = mesaResponse.data;
                      _mesaSearchController.text = mesaResponse.data!.numero;
                    });
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar venda aberta da comanda pré-selecionada: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar comanda pré-selecionada: $e');
    }
  }

  @override
  void dispose() {
    _mesaSearchController.dispose();
    _comandaSearchController.dispose();
    super.dispose();
  }

  void _onMesaSearchChanged() {
    final query = _mesaSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _mostrarListaMesas = false;
        _mesasDisponiveis = [];
      });
      return;
    }

    _buscarMesas(query);
  }

  void _onComandaSearchChanged() {
    final query = _comandaSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _mostrarListaComandas = false;
        _comandasDisponiveis = [];
      });
      return;
    }

    _buscarComandas(query);
  }

  Future<void> _buscarMesas(String query) async {
    setState(() {
      _carregandoMesas = true;
      _mostrarListaMesas = true;
    });

    try {
      final response = await _mesaService.searchMesas(
        page: 1,
        pageSize: 100, // Buscar mais para filtrar localmente
        filter: MesaFilterDto(
          searchTerm: query,
          ativa: true,
        ),
      );

      if (response.success && response.data != null) {
        setState(() {
          _mesasDisponiveis = response.data!.list;
          _carregandoMesas = false;
        });
      } else {
        setState(() {
          _mesasDisponiveis = [];
          _carregandoMesas = false;
        });
      }
    } catch (e) {
      setState(() {
        _mesasDisponiveis = [];
        _carregandoMesas = false;
      });
    }
  }

  Future<void> _buscarComandas(String query) async {
    setState(() {
      _carregandoComandas = true;
      _mostrarListaComandas = true;
    });

    try {
      final response = await _comandaService.searchComandas(
        page: 1,
        pageSize: 20,
        filter: ComandaFilterDto(
          search: query,
          ativa: true,
        ),
      );

      if (response.success && response.data != null) {
        setState(() {
          _comandasDisponiveis = response.data!.list;
          _carregandoComandas = false;
        });
      } else {
        setState(() {
          _comandasDisponiveis = [];
          _carregandoComandas = false;
        });
      }
    } catch (e) {
      setState(() {
        _comandasDisponiveis = [];
        _carregandoComandas = false;
      });
    }
  }

  void _selecionarMesa(MesaListItemDto mesa) async {
    // Validação: se a comanda já tem mesa vinculada e é diferente, bloquear e limpar comanda
    if (_comandaSelecionada != null && _mesaIdVinculadaComanda != null && mesa.id != _mesaIdVinculadaComanda) {
      // Armazena número da comanda antes de limpar
      final numeroComanda = _comandaSelecionada!.numero;
      
      // Limpa a comanda selecionada
      setState(() {
        _comandaSelecionada = null;
        _comandaSearchController.clear();
        _mesaIdVinculadaComanda = null;
      });
      
      // Mostra dialog de erro
      await AppDialog.showError(
        context: context,
        title: 'Comanda já vinculada',
        message: 'A comanda $numeroComanda já está vinculada a outra mesa. '
            'Todos os pedidos desta comanda devem ser feitos na mesma mesa.\n\n'
            'Por favor, selecione outra comanda.',
      );
      return; // Não permite selecionar mesa diferente
    }
    
    setState(() {
      _mesaSelecionada = mesa;
      _mesaSearchController.text = mesa.numero;
      _mostrarListaMesas = false;
    });
  }

  void _removerMesa() {
    setState(() {
      _mesaSelecionada = null;
      _mesaSearchController.clear();
      _mostrarListaMesas = false;
    });
  }

  void _selecionarComanda(ComandaListItemDto comanda) async {
    setState(() {
      _comandaSelecionada = comanda;
      _comandaSearchController.text = comanda.numero;
      _mostrarListaComandas = false;
      _mesaIdVinculadaComanda = null; // Reset ao selecionar nova comanda
    });

    // Buscar venda aberta da comanda para preencher mesa automaticamente e validar
    if (_configuracaoRestaurante?.controlePorComanda == true) {
      try {
        debugPrint('🔍 Buscando venda aberta da comanda ${comanda.numero}...');
        final vendaResponse = await _vendaService.getVendaAbertaPorComanda(comanda.id);
        
        if (vendaResponse.success && vendaResponse.data != null && vendaResponse.data!.mesaId != null) {
          final venda = vendaResponse.data!;
          _mesaIdVinculadaComanda = venda.mesaId; // Armazena ID da mesa vinculada
          debugPrint('✅ Venda aberta encontrada com mesa: ${venda.mesaId} (${venda.mesaNome})');
          
          // Se já tem mesa selecionada e é diferente da mesa vinculada, mostrar erro e limpar comanda
          if (_mesaSelecionada != null && _mesaSelecionada!.id != venda.mesaId) {
            // Limpa a comanda selecionada (não muda a mesa)
            setState(() {
              _comandaSelecionada = null;
              _comandaSearchController.clear();
              _mesaIdVinculadaComanda = null;
            });
            
            // Mostra dialog de erro
            await AppDialog.showError(
              context: context,
              title: 'Comanda já vinculada',
              message: 'A comanda ${comanda.numero} já está vinculada à mesa ${venda.mesaNome}. '
                  'Todos os pedidos desta comanda devem ser feitos na mesma mesa.\n\n'
                  'Por favor, selecione outra comanda.',
            );
            return; // Não preenche mesa automaticamente
          }
          
          // Buscar dados da mesa vinculada e preencher automaticamente
          final mesaResponse = await _mesaService.getMesaById(venda.mesaId!);
          if (mesaResponse.success && mesaResponse.data != null) {
            setState(() {
              _mesaSelecionada = mesaResponse.data;
              _mesaSearchController.text = mesaResponse.data!.numero;
            });
            debugPrint('✅ Mesa preenchida automaticamente: ${mesaResponse.data!.numero}');
          }
        } else {
          debugPrint('ℹ️ Nenhuma venda aberta encontrada ou venda sem mesa vinculada');
          _mesaIdVinculadaComanda = null;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar venda aberta da comanda: $e');
        _mesaIdVinculadaComanda = null;
        // Não bloqueia a seleção da comanda se houver erro
      }
    }
  }

  void _removerComanda() {
    setState(() {
      _comandaSelecionada = null;
      _comandaSearchController.clear();
      _mostrarListaComandas = false;
      _mesaIdVinculadaComanda = null; // Limpa também a referência da mesa vinculada
    });
  }

  bool _podeConfirmar() {
    // Se permite venda avulsa, sempre pode confirmar (mesmo sem seleção)
    if (widget.permiteVendaAvulsa) {
      return true;
    }
    
    // Se configuração é PorComanda, comanda é obrigatória
    // Verifica se foi selecionada ou se já veio pré-selecionada (carregada em initState)
    if (_comandaObrigatoria) {
      final temComanda = _comandaSelecionada != null;
      if (!temComanda) {
        return false;
      }
    }
    
    // Se configuração é PorMesa, mesa é obrigatória
    // Verifica se foi selecionada ou se já veio pré-selecionada (carregada em initState)
    if (_mesaObrigatoria && widget.mesaIdPreSelecionada == null) {
      if (_mesaSelecionada == null) {
        return false;
      }
    }
    
    // Caso contrário (vindo de comanda), precisa ter pelo menos a comanda
    // Mesa é opcional quando vem de comanda
    if (widget.comandaIdPreSelecionada != null) {
      // Comanda já veio pré-selecionada e foi carregada em initState
      return _comandaSelecionada != null;
    }
    
    // Fallback: deve ter pelo menos mesa ou comanda
    return _mesaSelecionada != null || _comandaSelecionada != null || 
           widget.mesaIdPreSelecionada != null;
  }

  void _confirmar() async {
    // Validação: se comanda é obrigatória, deve ter selecionado ou pré-selecionada (carregada)
    if (_comandaObrigatoria) {
      final temComanda = _comandaSelecionada != null;
      if (!temComanda) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comanda é obrigatória para criar pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validação: se mesa é obrigatória, deve ter selecionado ou pré-selecionada
    if (_mesaObrigatoria && widget.mesaIdPreSelecionada == null) {
      if (_mesaSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesa é obrigatória para criar pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Se permite venda avulsa e não selecionou nada, permite continuar
    if (widget.permiteVendaAvulsa && _mesaSelecionada == null && _comandaSelecionada == null) {
      Navigator.of(context).pop(
        SelecaoMesaComandaResult(
          mesa: null,
          comanda: null,
        ),
      );
      return;
    }

    // Validação crítica: se comanda tem mesa vinculada, a mesa selecionada deve ser a mesma
    if (_comandaSelecionada != null && _mesaIdVinculadaComanda != null) {
      final mesaIdSelecionada = _mesaSelecionada?.id ?? widget.mesaIdPreSelecionada;
      
      if (mesaIdSelecionada != null && mesaIdSelecionada != _mesaIdVinculadaComanda) {
        // Armazena número da comanda antes de limpar
        final numeroComanda = _comandaSelecionada!.numero;
        
        // Limpa a comanda selecionada
        setState(() {
          _comandaSelecionada = null;
          _comandaSearchController.clear();
          _mesaIdVinculadaComanda = null;
        });
        
        // Mostra dialog de erro
        await AppDialog.showError(
          context: context,
          title: 'Comanda já vinculada',
          message: 'A comanda $numeroComanda já está vinculada a outra mesa. '
              'Todos os pedidos desta comanda devem ser feitos na mesma mesa.\n\n'
              'Por favor, selecione outra comanda.',
        );
        return; // Bloqueia a confirmação
      }
    }

    // Validação básica: deve ter pelo menos mesa ou comanda (a menos que seja venda avulsa)
    final temMesa = _mesaSelecionada != null || widget.mesaIdPreSelecionada != null;
    final temComanda = _comandaSelecionada != null || widget.comandaIdPreSelecionada != null;
    
    if (!widget.permiteVendaAvulsa && !temMesa && !temComanda) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma mesa ou comanda'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      SelecaoMesaComandaResult(
        mesa: _mesaSelecionada,
        comanda: _comandaSelecionada,
      ),
    );
  }

  void _cancelar() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const SizedBox.shrink();
    }

    final dialogWidth = adaptive.isMobile 
        ? MediaQuery.of(context).size.width * 0.9
        : adaptive.isTablet
            ? 600.0
            : 700.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Novo Pedido',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 20 : 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: _cancelar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getInstrucaoSelecao(),
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: adaptive.isMobile ? 24 : 32),

                    // Ordem dos campos baseada na configuração:
                    // - Se controlePorComanda: Comanda primeiro (obrigatória), Mesa depois (opcional)
                    // - Se controlePorMesa: Apenas Mesa (comanda oculta)
                    if (_mostrarSelecaoComanda) ...[
                      // Controle por Comanda: Comanda primeiro
                      _buildSelecaoComanda(adaptive),
                      SizedBox(height: adaptive.isMobile ? 24 : 32),
                      // Mesa depois (opcional)
                      _buildSelecaoMesa(adaptive),
                    ] else ...[
                      // Controle por Mesa: Apenas Mesa (comanda oculta)
                      _buildSelecaoMesa(adaptive),
                    ],
                  ],
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelar,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: adaptive.isMobile ? 12 : 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _podeConfirmar() ? _confirmar : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                        ),
                      ),
                      child: Text(
                        'Continuar',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstrucaoSelecao() {
    if (widget.comandaIdPreSelecionada != null) {
      // Vindo de tela de comanda: comanda já selecionada, mesa opcional
      return 'Comanda selecionada. Selecione uma mesa (opcional)';
    } else if (widget.mesaIdPreSelecionada != null && _comandaObrigatoria) {
      // Vindo de tela de mesa com controle por comanda: mesa já selecionada, comanda obrigatória
      return 'Mesa selecionada. Selecione a comanda (obrigatória)';
    } else if (_comandaObrigatoria) {
      // Controle por comanda: comanda obrigatória
      return 'Selecione a comanda (obrigatória) e mesa (opcional)';
    } else if (widget.permiteVendaAvulsa) {
      return 'Selecione a mesa e/ou comanda (opcional - pode deixar vazio para venda avulsa)';
    } else {
      return 'Selecione a mesa e/ou comanda (opcional)';
    }
  }

  Widget _buildSelecaoMesa(AdaptiveLayoutProvider adaptive) {
    // Mesa é obrigatória apenas se configuração é PorMesa e não veio pré-selecionada
    final mesaObrigatoria = _mesaObrigatoria && widget.mesaIdPreSelecionada == null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mesa',
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (!mesaObrigatoria) ...[
              const SizedBox(width: 8),
              Text(
                '(Opcional)',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: adaptive.isMobile ? 12 : 16),
        
        // Campo de busca ou mesa selecionada
        if (_mesaSelecionada != null)
          _buildMesaSelecionada(adaptive)
        else
          _buildCampoBuscaMesa(adaptive),

        // Lista de resultados
        if (_mostrarListaMesas && _mesaSelecionada == null)
          _buildListaMesas(adaptive),
      ],
    );
  }

  Widget _buildCampoBuscaMesa(AdaptiveLayoutProvider adaptive) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _mesaSearchController,
        decoration: InputDecoration(
          hintText: 'Buscar mesa...',
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: adaptive.isMobile ? 14 : 15,
          ),
          prefixIcon: Icon(
            Icons.table_restaurant,
            color: Colors.grey.shade400,
            size: adaptive.isMobile ? 20 : 22,
          ),
          suffixIcon: _mesaSearchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey.shade400,
                    size: adaptive.isMobile ? 20 : 22,
                  ),
                  onPressed: () {
                    _mesaSearchController.clear();
                  },
                )
              : null,
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
    );
  }

  Widget _buildMesaSelecionada(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
            ),
            child: Icon(
              Icons.table_restaurant,
              color: AppTheme.primaryColor,
              size: adaptive.isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: adaptive.isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mesaSelecionada!.numero,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_mesaSelecionada!.descricao != null && _mesaSelecionada!.descricao!.isNotEmpty)
                  Text(
                    _mesaSelecionada!.descricao!,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 13 : 14,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: _removerMesa,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaMesas(AdaptiveLayoutProvider adaptive) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: _carregandoMesas
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          : _mesasDisponiveis.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Nenhuma mesa encontrada',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mesasDisponiveis.length,
                  itemBuilder: (context, index) {
                    final mesa = _mesasDisponiveis[index];
                    return _buildItemMesa(mesa, adaptive);
                  },
                ),
    );
  }

  Widget _buildItemMesa(MesaListItemDto mesa, AdaptiveLayoutProvider adaptive) {
    final isOcupada = mesa.status.toLowerCase() == 'ocupada';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selecionarMesa(mesa),
        child: Padding(
          padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: isOcupada
                      ? AppTheme.warningColor.withOpacity(0.1)
                      : AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(adaptive.isMobile ? 8 : 10),
                ),
                child: Icon(
                  Icons.table_restaurant,
                  color: isOcupada
                      ? AppTheme.warningColor
                      : AppTheme.successColor,
                  size: adaptive.isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: adaptive.isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mesa.numero,
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (mesa.descricao != null && mesa.descricao!.isNotEmpty)
                      Text(
                        mesa.descricao!,
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 13 : 14,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 8 : 10,
                  vertical: adaptive.isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: isOcupada
                      ? AppTheme.warningColor.withOpacity(0.1)
                      : AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(adaptive.isMobile ? 8 : 10),
                ),
                child: Text(
                  mesa.status,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isOcupada
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelecaoComanda(AdaptiveLayoutProvider adaptive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Comanda',
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_comandaObrigatoria) ...[
              const SizedBox(width: 8),
              Text(
                '(Obrigatória)',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: adaptive.isMobile ? 12 : 16),
        
        // Campo de busca ou comanda selecionada
        if (_comandaSelecionada != null)
          _buildComandaSelecionada(adaptive)
        else
          _buildCampoBuscaComanda(adaptive),

        // Lista de resultados
        if (_mostrarListaComandas && _comandaSelecionada == null)
          _buildListaComandas(adaptive),
      ],
    );
  }

  Widget _buildCampoBuscaComanda(AdaptiveLayoutProvider adaptive) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _comandaSearchController,
        decoration: InputDecoration(
          hintText: 'Buscar comanda por número ou código de barras...',
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: adaptive.isMobile ? 14 : 15,
          ),
          prefixIcon: Icon(
            Icons.receipt_long,
            color: Colors.grey.shade400,
            size: adaptive.isMobile ? 20 : 22,
          ),
          suffixIcon: _comandaSearchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey.shade400,
                    size: adaptive.isMobile ? 20 : 22,
                  ),
                  onPressed: () {
                    _comandaSearchController.clear();
                  },
                )
              : null,
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
    );
  }

  Widget _buildComandaSelecionada(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: AppTheme.infoColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
            ),
            child: Icon(
              Icons.receipt_long,
              color: AppTheme.infoColor,
              size: adaptive.isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: adaptive.isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _comandaSelecionada!.numero,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_comandaSelecionada!.codigoBarras != null && _comandaSelecionada!.codigoBarras!.isNotEmpty)
                  Text(
                    'Código: ${_comandaSelecionada!.codigoBarras}',
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 13 : 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: _removerComanda,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaComandas(AdaptiveLayoutProvider adaptive) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: _carregandoComandas
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          : _comandasDisponiveis.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Nenhuma comanda encontrada',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _comandasDisponiveis.length,
                  itemBuilder: (context, index) {
                    final comanda = _comandasDisponiveis[index];
                    return _buildItemComanda(comanda, adaptive);
                  },
                ),
    );
  }

  Widget _buildItemComanda(ComandaListItemDto comanda, AdaptiveLayoutProvider adaptive) {
    final isAtiva = comanda.status.toLowerCase() == 'ativa';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selecionarComanda(comanda),
        child: Padding(
          padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: isAtiva
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(adaptive.isMobile ? 8 : 10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: isAtiva
                      ? AppTheme.successColor
                      : AppTheme.infoColor,
                  size: adaptive.isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: adaptive.isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comanda.numero,
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (comanda.codigoBarras != null && comanda.codigoBarras!.isNotEmpty)
                      Text(
                        'Código: ${comanda.codigoBarras}',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 12 : 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 8 : 10,
                  vertical: adaptive.isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: isAtiva
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(adaptive.isMobile ? 8 : 10),
                ),
                child: Text(
                  comanda.status,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isAtiva
                        ? AppTheme.successColor
                        : AppTheme.infoColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
