import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/core/pedido_list_item.dart';
import '../../../data/models/local/pedido_local.dart';
import '../../../data/models/local/item_pedido_local.dart';
import '../../../data/models/local/produto_local.dart';
import '../../../data/models/local/produto_variacao_local.dart';
import '../../../data/repositories/pedido_local_repository.dart';
import '../../../data/repositories/produto_local_repository.dart';
import '../../../data/services/core/pedido_service.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/core/api_response.dart';
import '../../../data/services/core/auth_service.dart';

/// Tela de detalhes do pedido
/// Aceita tanto PedidoListItemDto (do servidor) quanto PedidoLocal (local)
class DetalhesPedidoScreen extends StatefulWidget {
  final PedidoListItemDto? pedidoServidor;
  final PedidoLocal? pedidoLocal;

  const DetalhesPedidoScreen({
    Key? key,
    this.pedidoServidor,
    this.pedidoLocal,
  }) : assert(
          pedidoServidor != null || pedidoLocal != null,
          'Deve fornecer pedidoServidor ou pedidoLocal',
        ),
        super(key: key);

  @override
  State<DetalhesPedidoScreen> createState() => _DetalhesPedidoScreenState();
}

class _DetalhesPedidoScreenState extends State<DetalhesPedidoScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _itens = [];
  final _produtoRepo = ProdutoLocalRepository();

  PedidoService get _pedidoService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.pedidoService;
  }

  ApiClient get _apiClient {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.authService.apiClient;
  }

  @override
  void initState() {
    super.initState();
    _produtoRepo.init();
    _loadItens();
  }

  Future<void> _loadItens() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.pedidoLocal != null) {
        // Para pedidos locais, usa os dados já disponíveis
        _itens = widget.pedidoLocal!.itens.map((item) {
          return {
            'id': item.id,
            'produtoId': item.produtoId,
            'produtoNome': item.produtoNome,
            'produtoVariacaoId': item.produtoVariacaoId,
            'produtoVariacaoNome': item.produtoVariacaoNome,
            'precoUnitario': item.precoUnitario,
            'quantidade': item.quantidade,
            'precoTotal': item.precoTotal,
            'observacoes': item.observacoes,
            'componentesRemovidos': item.componentesRemovidos,
            'proporcoesAtributos': item.proporcoesAtributos != null
                ? Map<String, double>.from(item.proporcoesAtributos!)
                : null,
            'valoresAtributosSelecionados': item.valoresAtributosSelecionados != null
                ? Map<String, List<String>>.from(
                    item.valoresAtributosSelecionados!.map(
                      (key, value) => MapEntry(key, List<String>.from(value)),
                    ),
                  )
                : null,
          };
        }).toList();
        setState(() {
          _isLoading = false;
        });
      } else if (widget.pedidoServidor != null) {
        // Para pedidos do servidor, busca o pedido completo (que já inclui os itens)
        final response = await _pedidoService.getPedidoById(widget.pedidoServidor!.id);

        if (!response.success || response.data == null) {
          setState(() {
            _errorMessage = response.message.isNotEmpty 
                ? response.message 
                : 'Erro ao carregar itens do pedido';
            _isLoading = false;
          });
          return;
        }

        final pedidoData = response.data!;
        final listData = pedidoData['itens'];

        if (listData == null || listData is! List) {
          setState(() {
            _itens = [];
            _isLoading = false;
          });
          return;
        }

        _itens = (listData as List).map((item) {
          return {
            'id': item['id']?.toString() ?? '',
            'produtoId': item['produtoId']?.toString() ?? '',
            'produtoNome': item['produtoNome']?.toString() ?? '',
            'produtoVariacaoId': item['produtoVariacaoId']?.toString(),
            'produtoVariacaoNome': item['produtoVariacaoNome']?.toString(),
            'precoUnitario': (item['precoUnitario'] is num)
                ? (item['precoUnitario'] as num).toDouble()
                : double.tryParse(item['precoUnitario']?.toString() ?? '0') ?? 0.0,
            'quantidade': item['quantidade'] is int
                ? item['quantidade'] as int
                : int.tryParse(item['quantidade']?.toString() ?? '0') ?? 0,
            'precoTotal': (item['precoTotal'] is num)
                ? (item['precoTotal'] as num).toDouble()
                : double.tryParse(item['precoTotal']?.toString() ?? '0') ?? 0.0,
            'observacoes': item['observacoes']?.toString(),
            'componentesRemovidos': (item['componentesRemovidos'] as List?)?.map((e) => e.toString()).toList() ?? [],
            'proporcoesAtributos': item['proporcoesAtributos'] as Map<String, dynamic>?,
            'valoresAtributosSelecionados': item['valoresAtributosSelecionados'] as Map<String, dynamic>?,
          };
        }).toList();

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar itens: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pedido = widget.pedidoServidor ?? widget.pedidoLocal;
    if (pedido == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Pedido não encontrado')),
      );
    }

    final isLocal = widget.pedidoLocal != null;
    final statusColor = isLocal
        ? Colors.orange
        : _getStatusColor(widget.pedidoServidor?.status ?? '');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dataPedido = isLocal
        ? (widget.pedidoLocal!.dataAtualizacao ?? widget.pedidoLocal!.dataCriacao)
        : widget.pedidoServidor!.dataPedido;
    final total = isLocal
        ? widget.pedidoLocal!.total
        : widget.pedidoServidor!.valorTotal;
    final observacoesGeral = isLocal
        ? widget.pedidoLocal!.observacoesGeral
        : null;

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
          isLocal ? 'Detalhes do Pedido Local' : 'Detalhes do Pedido',
          style: GoogleFonts.inter(
            fontSize: adaptive.isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
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
                        onPressed: _loadItens,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card de informações do pedido - Layout compacto
                      Container(
                        margin: EdgeInsets.fromLTRB(
                          adaptive.isMobile ? 16 : 20,
                          adaptive.isMobile ? 12 : 16,
                          adaptive.isMobile ? 16 : 20,
                          8,
                        ),
                        padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                          border: isLocal
                              ? Border.all(color: Colors.orange.shade300, width: 1.5)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Linha 1: Título e Status
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            isLocal
                                                ? 'Pedido Local'
                                                : 'Pedido ${widget.pedidoServidor!.numero}',
                                            style: GoogleFonts.inter(
                                              fontSize: adaptive.isMobile ? 16 : 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isLocal)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: statusColor.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                widget.pedidoServidor!.status,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.orange.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.sync_problem,
                                                    size: 12,
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
                                      const SizedBox(height: 4),
                                      Text(
                                        dateFormat.format(dataPedido),
                                        style: GoogleFonts.inter(
                                          fontSize: adaptive.isMobile ? 11 : 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Linha 2: Total e Itens em linha compacta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.attach_money,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              'R\$ ${total.toStringAsFixed(2)}',
                                              style: GoogleFonts.inter(
                                                fontSize: adaptive.isMobile ? 18 : 20,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.shade300,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Itens',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            '${_itens.length}',
                                            style: GoogleFonts.inter(
                                              fontSize: adaptive.isMobile ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Observações gerais (se houver)
                            if (observacoesGeral != null && observacoesGeral.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200, width: 1),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note, size: 14, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        observacoesGeral,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Título da lista de itens
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          adaptive.isMobile ? 16 : 20,
                          4,
                          adaptive.isMobile ? 16 : 20,
                          8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Itens do Pedido',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 15 : 17,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_itens.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lista de itens
                      if (_itens.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhum item encontrado',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._itens.map((item) => _buildItemCard(item, adaptive)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, AdaptiveLayoutProvider adaptive) {
    return Container(
      margin: EdgeInsets.only(
        left: adaptive.isMobile ? 16 : 20,
        right: adaptive.isMobile ? 16 : 20,
        bottom: 8,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantidade badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${item['quantidade']}x',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do produto
                    Text(
                      item['produtoNome'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    // Variação (se houver)
                    if (item['produtoVariacaoNome'] != null && (item['produtoVariacaoNome'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Variação: ${item['produtoVariacaoNome']}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    // Preço unitário inline
                    Text(
                      'R\$ ${(item['precoUnitario'] as double).toStringAsFixed(2)} cada',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Preço total do item
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${(item['precoTotal'] as double).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Atributos selecionados
          if (item['valoresAtributosSelecionados'] != null && (item['valoresAtributosSelecionados'] as Map<String, List<String>>).isNotEmpty) ...[
            const SizedBox(height: 6),
            FutureBuilder<ProdutoLocal?>(
              key: ValueKey('atributos_${item['id']}_${item['produtoId']}'),
              future: Future(() async {
                await _produtoRepo.init();
                return _produtoRepo.buscarPorId(item['produtoId'] as String);
              }),
              builder: (context, produtoSnapshot) {
                List<Map<String, dynamic>> atributosSelecionados = [];
                
                if (produtoSnapshot.hasData && produtoSnapshot.data != null) {
                  final produto = produtoSnapshot.data!;
                  final valoresAtributos = item['valoresAtributosSelecionados'] as Map<String, List<String>>?;
                  
                  if (valoresAtributos != null) {
                    for (var entry in valoresAtributos.entries) {
                      final atributoId = entry.key;
                      final valorIds = entry.value;
                      
                      // Buscar o atributo no produto
                      try {
                        final atributo = produto.atributos.firstWhere((a) => a.id == atributoId);
                        final nomesValores = valorIds.map((valorId) {
                          try {
                            final valor = atributo.valores.firstWhere((v) => v.id == valorId);
                            return valor.nome;
                          } catch (e) {
                            return null;
                          }
                        }).where((nome) => nome != null).cast<String>().toList();
                        
                        if (nomesValores.isNotEmpty) {
                          List<double>? proporcoes;
                          final proporcoesAtributos = item['proporcoesAtributos'] as Map<String, double>?;
                          if (proporcoesAtributos != null) {
                            proporcoes = valorIds
                                .map((valorId) => proporcoesAtributos[valorId])
                                .where((p) => p != null)
                                .cast<double>()
                                .toList();
                            // Se ficou vazio após filtrar, definir como null
                            if (proporcoes.isEmpty) {
                              proporcoes = null;
                            }
                          }
                          
                          atributosSelecionados.add({
                            'nomeAtributo': atributo.nome,
                            'nomesValores': nomesValores,
                            'proporcoes': proporcoes,
                          });
                        }
                      } catch (e) {
                        // Atributo não encontrado
                      }
                    }
                  }
                }
                
                if (atributosSelecionados.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: atributosSelecionados.map((atributoInfo) {
                    final nomeAtributo = atributoInfo['nomeAtributo'] as String;
                    final nomesValores = atributoInfo['nomesValores'] as List<String>;
                    final proporcoes = atributoInfo['proporcoes'] as List<double>?;
                    
                    return Container(
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
                          Text(
                            '$nomeAtributo: ',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              proporcoes != null && proporcoes.isNotEmpty
                                  ? nomesValores.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final nome = entry.value;
                                      final proporcao = proporcoes.length > index ? proporcoes[index] : null;
                                      return proporcao != null && proporcao != 1.0
                                          ? '$nome (${(proporcao * 100).toStringAsFixed(0)}%)'
                                          : nome;
                                    }).join(', ')
                                  : nomesValores.join(', '),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          // Componentes removidos
          if (item['componentesRemovidos'] != null && (item['componentesRemovidos'] as List).isNotEmpty) ...[
            const SizedBox(height: 6),
            FutureBuilder<ProdutoLocal?>(
              key: ValueKey('componentes_${item['id']}_${item['produtoId']}'),
              future: Future(() async {
                await _produtoRepo.init();
                return _produtoRepo.buscarPorId(item['produtoId'] as String);
              }),
              builder: (context, produtoSnapshot) {
                List<String> nomesComponentesRemovidos = [];
                
                if (produtoSnapshot.hasData && produtoSnapshot.data != null) {
                  final produto = produtoSnapshot.data!;
                  ProdutoVariacaoLocal? variacao;
                  
                  // Buscar variação se houver
                  if (item['produtoVariacaoId'] != null && produto.variacoes.isNotEmpty) {
                    try {
                      variacao = produto.variacoes.firstWhere(
                        (v) => v.id == item['produtoVariacaoId'],
                      );
                    } catch (e) {
                      // Variação não encontrada, usar composição do produto
                    }
                  }
                  
                  // Usar composição da variação ou do produto
                  final composicao = variacao != null && variacao.composicao.isNotEmpty
                      ? variacao.composicao
                      : produto.composicao;
                  
                  // Mapear IDs para nomes
                  final componentesRemovidos = item['componentesRemovidos'] as List;
                  nomesComponentesRemovidos = composicao
                      .where((c) => componentesRemovidos.contains(c.componenteId))
                      .map((c) => c.componenteNome)
                      .toList();
                }
                
                // Só exibir se encontrou os nomes
                if (nomesComponentesRemovidos.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.remove_circle_outline, size: 12, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Removido${nomesComponentesRemovidos.length == 1 ? '' : 's'}:',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: nomesComponentesRemovidos.map((nome) {
                                return Text(
                                  nome,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.orange.shade900,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Observações do item
          if (item['observacoes'] != null && (item['observacoes'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 12, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['observacoes'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
