import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../data/models/local/item_pedido_local.dart';
import '../../../../data/models/local/produto_local.dart';
import '../../../../data/models/local/produto_variacao_local.dart';
import '../../../../data/models/local/produto_composicao_local.dart';
import '../../../../data/repositories/produto_local_repository.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../presentation/providers/pedido_provider.dart';

/// Modal para editar um item do pedido (componentes removidos e observações)
class EditarItemPedidoModal extends StatefulWidget {
  final ItemPedidoLocal item;

  const EditarItemPedidoModal({
    super.key,
    required this.item,
  });

  static Future<void> show(BuildContext context, ItemPedidoLocal item) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditarItemPedidoModal(item: item),
    );
  }

  @override
  State<EditarItemPedidoModal> createState() => _EditarItemPedidoModalState();
}

class _EditarItemPedidoModalState extends State<EditarItemPedidoModal> {
  ProdutoLocal? _produto;
  ProdutoVariacaoLocal? _variacao;
  bool _isLoading = true;
  
  final Map<String, dynamic> _itemData = {};
  bool _itemExpandido = true;
  final TextEditingController _observacaoController = TextEditingController();

  ProdutoLocalRepository get _produtoRepo {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.produtoLocalRepo;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      // Carregar produto
      _produto = _produtoRepo.buscarPorId(widget.item.produtoId);
      
      // Carregar variação se houver
      if (widget.item.produtoVariacaoId != null && _produto != null) {
        _variacao = _produto!.variacoes.firstWhere(
          (v) => v.id == widget.item.produtoVariacaoId,
          orElse: () => _produto!.variacoes.first,
        );
      }

      // Inicializar dados do item com valores existentes
      _itemData['componentesRemovidos'] = List<String>.from(widget.item.componentesRemovidos);
      _itemData['observacao'] = widget.item.observacoes ?? '';
      _observacaoController.text = widget.item.observacoes ?? '';

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados do produto: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ProdutoComposicaoLocal> _obterComposicao() {
    if (_variacao != null) {
      return _variacao!.composicao.isNotEmpty ? _variacao!.composicao : [];
    }
    if (_produto != null) {
      return _produto!.composicao.isNotEmpty ? _produto!.composicao : [];
    }
    return [];
  }

  List<ProdutoComposicaoLocal> _obterComposicaoRemovivel() {
    return _obterComposicao().where((c) => c.isRemovivel).toList();
  }

  void _alternarComponenteRemovido(String componenteId) {
    setState(() {
      final componentesRemovidos = List<String>.from(_itemData['componentesRemovidos'] ?? []);
      if (componentesRemovidos.contains(componenteId)) {
        componentesRemovidos.remove(componenteId);
      } else {
        componentesRemovidos.add(componenteId);
      }
      _itemData['componentesRemovidos'] = componentesRemovidos;
    });
  }

  bool _isComponenteRemovido(String componenteId) {
    final componentesRemovidos = _itemData['componentesRemovidos'] as List<String>? ?? [];
    return componentesRemovidos.contains(componenteId);
  }

  void _confirmar() {
    final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
    final componentesRemovidos = List<String>.from(_itemData['componentesRemovidos'] ?? []);
    final observacao = _observacaoController.text.trim();

    // Atualizar o item no pedido
    final itemAtualizado = ItemPedidoLocal(
      id: widget.item.id,
      produtoId: widget.item.produtoId,
      produtoNome: widget.item.produtoNome,
      produtoVariacaoId: widget.item.produtoVariacaoId,
      produtoVariacaoNome: widget.item.produtoVariacaoNome,
      precoUnitario: widget.item.precoUnitario,
      quantidade: widget.item.quantidade,
      observacoes: observacao.isNotEmpty ? observacao : null,
      proporcoesAtributos: widget.item.proporcoesAtributos,
      valoresAtributosSelecionados: widget.item.valoresAtributosSelecionados,
      componentesRemovidos: componentesRemovidos,
      dataAdicao: widget.item.dataAdicao,
    );

    // Atualizar o item diretamente no pedido
    pedidoProvider.atualizarItem(itemAtualizado);

    Navigator.of(context).pop();
    
    AppToast.showSuccess(
      context,
      'Item atualizado com sucesso',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final composicaoRemovivel = _obterComposicaoRemovivel();
    final componentesRemovidos = _itemData['componentesRemovidos'] as List<String>? ?? [];
    final observacao = _observacaoController.text;
    final temPersonalizacao = componentesRemovidos.isNotEmpty || observacao.isNotEmpty;

    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(20),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _produto == null
              ? const Center(child: Text('Produto não encontrado'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Editar item',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.item.produtoVariacaoNome ?? widget.item.produtoNome,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Conteúdo
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (composicaoRemovivel.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Este produto não possui componentes removíveis.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            else ...[
                              Text(
                                'Remova componentes conforme necessário:',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildItemCard(composicaoRemovivel, temPersonalizacao),
                            ],
                            const SizedBox(height: 16),
                            // Campo de observação
                            Text(
                              'Observação',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _observacaoController,
                              onChanged: (value) {
                                setState(() {
                                  _itemData['observacao'] = value;
                                });
                              },
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Adicione uma observação para este item...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _confirmar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            child: const Text('Salvar alterações'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );

    if (isMobile) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: content,
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: content,
      ),
    );
  }

  Widget _buildItemCard(
    List<ProdutoComposicaoLocal> composicaoRemovivel,
    bool temPersonalizacao,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: temPersonalizacao ? Colors.orange.shade300 : Colors.grey.shade300,
          width: temPersonalizacao ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: temPersonalizacao ? Colors.orange.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          InkWell(
            onTap: () {
              setState(() {
                _itemExpandido = !_itemExpandido;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: temPersonalizacao
                                ? Colors.orange.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            size: 20,
                            color: temPersonalizacao
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Item ${widget.item.quantidade > 1 ? '1' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              if (temPersonalizacao) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if ((_itemData['componentesRemovidos'] as List<String>?)?.isNotEmpty ?? false)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.remove_circle_outline,
                                              size: 14,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${(_itemData['componentesRemovidos'] as List<String>?)?.length ?? 0} removido${((_itemData['componentesRemovidos'] as List<String>?)?.length ?? 0) == 1 ? '' : 's'}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_observacaoController.text.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.note,
                                              size: 14,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Obs',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
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
                  ),
                  Icon(
                    _itemExpandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo expandido
          if (_itemExpandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Componentes removíveis:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...composicaoRemovivel.map((componente) {
                    final isRemovido = _isComponenteRemovido(componente.componenteId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _alternarComponenteRemovido(componente.componenteId),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isRemovido ? Colors.red.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isRemovido ? Colors.red.shade300 : Colors.grey.shade300,
                              width: isRemovido ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRemovido ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isRemovido ? Colors.red.shade700 : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  componente.componenteNome,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isRemovido ? FontWeight.w600 : FontWeight.normal,
                                    color: isRemovido ? Colors.red.shade700 : Colors.grey.shade800,
                                    decoration: isRemovido ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              if (isRemovido)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Removido',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
