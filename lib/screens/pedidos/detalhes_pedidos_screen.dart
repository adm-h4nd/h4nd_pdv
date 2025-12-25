import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/pedido_list_item.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/services/core/pedido_service.dart';
import '../pedidos/restaurante/novo_pedido_restaurante_screen.dart';
import 'detalhes_pedido_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Tipo de entidade para filtro de pedidos
enum TipoEntidade {
  mesa,
  comanda,
}

/// Dados da entidade (mesa ou comanda)
class EntidadePedidos {
  final String id;
  final String numero;
  final String? descricao;
  final String status;
  final TipoEntidade tipo;
  final String? codigoBarras; // Apenas para comanda

  EntidadePedidos({
    required this.id,
    required this.numero,
    this.descricao,
    required this.status,
    required this.tipo,
    this.codigoBarras,
  });
}

/// Tela genérica de detalhes de pedidos (funciona para mesa e comanda)
class DetalhesPedidosScreen extends StatefulWidget {
  final EntidadePedidos entidade;

  const DetalhesPedidosScreen({
    super.key,
    required this.entidade,
  });

  @override
  State<DetalhesPedidosScreen> createState() => _DetalhesPedidosScreenState();
}

class _DetalhesPedidosScreenState extends State<DetalhesPedidosScreen> {
  List<PedidoListItemDto> _pedidos = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAbrindoNovoPedido = false; // Proteção contra múltiplos cliques
  final _pedidoRepo = PedidoLocalRepository();

  PedidoService get _pedidoService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.pedidoService;
  }

  @override
  void initState() {
    super.initState();
    _pedidoRepo.getAll(); // Garante que a box está aberta
    _loadPedidos();
  }

  List<PedidoLocal> _getPedidosLocais(Box<PedidoLocal>? box) {
    if (box == null || !Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return [];
    }
    
    final pedidos = box.values
        .where((p) {
          if (widget.entidade.tipo == TipoEntidade.mesa) {
            return p.mesaId == widget.entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          } else {
            return p.comandaId == widget.entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          }
        })
        .toList()
      ..sort((a, b) => (b.dataAtualizacao ?? b.dataCriacao).compareTo(a.dataAtualizacao ?? a.dataCriacao));
    
    return pedidos;
  }

  Future<void> _loadPedidos({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _errorMessage = null;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = widget.entidade.tipo == TipoEntidade.mesa
          ? await _pedidoService.getPedidosPorMesa(widget.entidade.id)
          : await _pedidoService.getPedidosPorComanda(widget.entidade.id);

      if (response.success) {
        setState(() {
          _pedidos = response.data ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _pedidos = [];
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _pedidos = [];
        _errorMessage = 'Erro ao carregar pedidos: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    if (widget.entidade.tipo == TipoEntidade.mesa) {
      switch (status.toLowerCase()) {
        case 'livre':
          return AppTheme.successColor;
        case 'ocupada':
          return AppTheme.warningColor;
        case 'reservada':
          return AppTheme.infoColor;
        case 'manutencao':
        case 'suspensa':
          return AppTheme.errorColor;
        default:
          return Colors.grey;
      }
    } else {
      switch (status.toLowerCase()) {
        case 'ativa':
          return AppTheme.successColor;
        case 'encerrada':
          return AppTheme.infoColor;
        case 'cancelada':
          return AppTheme.errorColor;
        default:
          return Colors.grey;
      }
    }
  }

  Color _getPedidoStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aberto':
        return AppTheme.infoColor;
      case 'finalizado':
      case 'entregue':
        return AppTheme.successColor;
      case 'cancelado':
        return AppTheme.errorColor;
      case 'empreparacao':
      case 'pronto':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  bool _podeCriarPedido() {
    if (widget.entidade.tipo == TipoEntidade.mesa) {
      return widget.entidade.status.toLowerCase() != 'livre';
    } else {
      return widget.entidade.status.toLowerCase() == 'ativa';
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.entidade.numero,
          style: GoogleFonts.inter(
            fontSize: adaptive.isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: () => _loadPedidos(refresh: true),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
              // Header compacto com informações
              Builder(
                builder: (context) {
                  if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
                    final total = _pedidos.fold(0.0, (sum, p) => sum + p.valorTotal);
                    final totalPedidos = _pedidos.length;
                    
                    return _buildCompactHeader(adaptive, total, totalPedidos, 0);
                  }
                  
                  return ValueListenableBuilder<Box<PedidoLocal>>(
                    valueListenable: Hive.box<PedidoLocal>(PedidoLocalRepository.boxName).listenable(),
                    builder: (context, box, _) {
                      final pedidosLocais = _getPedidosLocais(box);
                      final total = _pedidos.fold(0.0, (sum, p) => sum + p.valorTotal) +
                          pedidosLocais.fold(0.0, (sum, p) => sum + p.total);
                      final totalPedidos = _pedidos.length + pedidosLocais.length;
                      
                      return _buildCompactHeader(adaptive, total, totalPedidos, pedidosLocais.length);
                    },
                  );
                },
              ),

              // Botão Novo Pedido
              if (_podeCriarPedido())
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    adaptive.isMobile ? 16 : 20,
                    12,
                    adaptive.isMobile ? 16 : 20,
                    8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAbrindoNovoPedido ? null : () async {
                        // Proteção contra múltiplos cliques
                        if (_isAbrindoNovoPedido) {
                          return;
                        }
                        
                        setState(() {
                          _isAbrindoNovoPedido = true;
                        });
                        
                        try {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AdaptiveLayout(
                                child: NovoPedidoRestauranteScreen(
                                  mesaId: widget.entidade.tipo == TipoEntidade.mesa ? widget.entidade.id : null,
                                  comandaId: widget.entidade.tipo == TipoEntidade.comanda ? widget.entidade.id : null,
                                ),
                              ),
                            ),
                          );
                          
                          if (mounted) {
                            _loadPedidos(refresh: true);
                          }
                        } finally {
                          // Sempre libera o flag, mesmo se houver erro
                          if (mounted) {
                            setState(() {
                              _isAbrindoNovoPedido = false;
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      label: Text(
                        'Novo Pedido',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                        ),
                      ),
                    ),
                  ),
                ),

              // Lista de pedidos
              Expanded(
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
                              onPressed: () => _loadPedidos(refresh: true),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Builder(
                            builder: (context) {
                              if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
                                if (_pedidos.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhum pedido encontrado',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    adaptive.isMobile ? 16 : 20,
                                    8,
                                    adaptive.isMobile ? 16 : 20,
                                    8,
                                  ),
                                  itemCount: _pedidos.length,
                                  itemBuilder: (context, index) {
                                    return _buildPedidoCard(_pedidos[index], adaptive);
                                  },
                                );
                              }
                              
                              return ValueListenableBuilder<Box<PedidoLocal>>(
                                valueListenable: Hive.box<PedidoLocal>(PedidoLocalRepository.boxName).listenable(),
                                builder: (context, box, _) {
                                  final pedidosLocais = _getPedidosLocais(box);
                                  final temPedidos = _pedidos.isNotEmpty || pedidosLocais.isNotEmpty;
                                  
                                  if (!temPedidos) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 64,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Nenhum pedido encontrado',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  
                                  return ListView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                      adaptive.isMobile ? 16 : 20,
                                      8,
                                      adaptive.isMobile ? 16 : 20,
                                      8,
                                    ),
                                    itemCount: _pedidos.length + pedidosLocais.length,
                                    itemBuilder: (context, index) {
                                      if (index < pedidosLocais.length) {
                                        final pedidoLocal = pedidosLocais[index];
                                        return _buildPedidoLocalCard(pedidoLocal, adaptive);
                                      }
                                      final pedido = _pedidos[index - pedidosLocais.length];
                                      return _buildPedidoCard(pedido, adaptive);
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
    );
  }

  Widget _buildCompactHeader(AdaptiveLayoutProvider adaptive, double total, int totalPedidos, int pedidosPendentes) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        adaptive.isMobile ? 16 : 20,
        12,
        adaptive.isMobile ? 16 : 20,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Marca d'água sutil de mesa no cabeçalho (apenas para mesa)
          if (widget.entidade.tipo == TipoEntidade.mesa)
            Positioned(
              top: -15,
              right: -40, // Posiciona parcialmente fora da tela
              child: Opacity(
                opacity: 0.15, // Visível mas sutil
                child: Icon(
                  Icons.table_restaurant,
                  size: 200,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          
          Column(
            children: [
              // Linha superior: Nome e Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.entidade.tipo == TipoEntidade.mesa 
                              ? Icons.table_restaurant 
                              : Icons.receipt_long,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.entidade.tipo == TipoEntidade.mesa ? 'Mesa' : 'Comanda'} ${widget.entidade.numero}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.entidade.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(widget.entidade.status).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.entidade.status,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(widget.entidade.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.entidade.descricao != null && widget.entidade.descricao!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.entidade.descricao!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.entidade.codigoBarras != null && widget.entidade.codigoBarras!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.qr_code, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Código: ${widget.entidade.codigoBarras}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
              const SizedBox(height: 10),
              // Linha inferior: Totais compactos
              Row(
                children: [
                  Expanded(
                    child: _buildTotalItem(
                      adaptive,
                      icon: Icons.receipt_long,
                      label: 'Total',
                      value: 'R\$ ${total.toStringAsFixed(2)}',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    child: _buildTotalItem(
                      adaptive,
                      icon: Icons.shopping_cart,
                      label: 'Pedidos',
                      value: '$totalPedidos',
                      color: AppTheme.infoColor,
                      badge: pedidosPendentes > 0 ? pedidosPendentes : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(
    AdaptiveLayoutProvider adaptive, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    int? badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 16 : 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_problem, size: 10, color: Colors.orange.shade700),
                        const SizedBox(width: 3),
                        Text(
                          '$badge',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPedidoCard(PedidoListItemDto pedido, AdaptiveLayoutProvider adaptive) {
    final statusColor = _getPedidoStatusColor(pedido.status);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesPedidoScreen(pedidoServidor: pedido),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
          child: Padding(
            padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pedido.numero,
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 15 : 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              pedido.status,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pedido.clienteNome,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(pedido.dataPedido),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'R\$ ${pedido.valorTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPedidoLocalCard(PedidoLocal pedido, AdaptiveLayoutProvider adaptive) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dataPedido = pedido.dataAtualizacao ?? pedido.dataCriacao;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        border: Border.all(
          color: Colors.orange.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesPedidoScreen(pedidoLocal: pedido),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
          child: Padding(
            padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pedido Local',
                                style: GoogleFonts.inter(
                                  fontSize: adaptive.isMobile ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sync_problem,
                                      size: 11,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Pendente',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(dataPedido),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (pedido.itens.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: pedido.itens.take(3).map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${item.quantidade}x',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.produtoNome,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            if (pedido.itens.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${pedido.itens.length - 3} item${pedido.itens.length - 3 > 1 ? 's' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                          if (pedido.observacoesGeral != null && pedido.observacoesGeral!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.note_outlined,
                                  size: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    pedido.observacoesGeral!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'R\$ ${pedido.total.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 16 : 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

