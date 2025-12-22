import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../presentation/providers/pedido_provider.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../data/models/local/item_pedido_local.dart';
import '../../../../data/models/local/produto_variacao_local.dart';
import '../modals/editar_item_pedido_modal.dart';

/// Painel lateral elegante para mostrar resumo do pedido em construção
class PedidoResumoPanel extends StatelessWidget {
  final VoidCallback? onFinalizarPedido;
  final VoidCallback? onLimparPedido;

  const PedidoResumoPanel({
    super.key,
    this.onFinalizarPedido,
    this.onLimparPedido,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PedidoProvider>(
      builder: (context, pedidoProvider, child) {
        if (pedidoProvider.isEmpty) {
          return _buildEmptyState();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(pedidoProvider),
              Expanded(
                child: _buildItensList(pedidoProvider),
              ),
              _buildFooter(pedidoProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum item adicionado',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione produtos para começar',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PedidoProvider pedidoProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (onLimparPedido != null)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () {
                      _confirmarLimparPedido(context);
                    },
                    tooltip: 'Limpar pedido',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                size: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 6),
              Text(
                '${pedidoProvider.quantidadeTotal} ${pedidoProvider.quantidadeTotal == 1 ? 'item' : 'itens'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItensList(PedidoProvider pedidoProvider) {
    final itens = pedidoProvider.itens;

    if (itens.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itens.length,
      itemBuilder: (context, index) {
        final item = itens[index];
        return _buildItemCard(context, item, index, pedidoProvider);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, ItemPedidoLocal item, int index, PedidoProvider pedidoProvider) {
    return Consumer<ServicesProvider>(
      builder: (context, servicesProvider, child) {
        final produtoRepo = servicesProvider.produtoLocalRepo;
        final produto = produtoRepo.buscarPorId(item.produtoId);
        
        // Buscar nomes dos componentes removidos
        List<String> nomesComponentesRemovidos = [];
        if (produto != null && item.componentesRemovidos.isNotEmpty) {
          ProdutoVariacaoLocal? variacao;
          if (item.produtoVariacaoId != null && produto.variacoes.isNotEmpty) {
            try {
              variacao = produto.variacoes.firstWhere(
                (v) => v.id == item.produtoVariacaoId,
              );
            } catch (e) {
              // Variação não encontrada, usar composição do produto
            }
          }
          
          final composicao = variacao != null && variacao.composicao.isNotEmpty
              ? variacao.composicao
              : produto.composicao;
          
          nomesComponentesRemovidos = composicao
              .where((c) => item.componentesRemovidos.contains(c.componenteId))
              .map((c) => c.componenteNome)
              .toList();
        }
        
        // Buscar informações dos atributos selecionados
        List<Map<String, dynamic>> atributosSelecionados = [];
        if (produto != null && item.valoresAtributosSelecionados != null && item.valoresAtributosSelecionados!.isNotEmpty) {
          for (var entry in item.valoresAtributosSelecionados!.entries) {
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
                if (item.proporcoesAtributos != null) {
                  proporcoes = valorIds
                      .map((valorId) => item.proporcoesAtributos![valorId])
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
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              _editarItem(context, item);
            },
            onLongPress: () {
              _confirmarRemoverItem(context, item, pedidoProvider);
            },
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho do item
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.produtoVariacaoNome ?? item.produtoNome,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.produtoVariacaoNome != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.produtoNome,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () {
                            pedidoProvider.removerItem(item.id);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    // Atributos selecionados
                    if (atributosSelecionados.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: atributosSelecionados.map((atributoInfo) {
                          final nomeAtributo = atributoInfo['nomeAtributo'] as String;
                          final nomesValores = atributoInfo['nomesValores'] as List<String>;
                          final proporcoes = atributoInfo['proporcoes'] as List<double>?;
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
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
                                    fontSize: 12,
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
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                      
                    // Componentes removidos e observações
                    if (nomesComponentesRemovidos.isNotEmpty ||
                        (item.observacoes != null && item.observacoes!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (nomesComponentesRemovidos.isNotEmpty ||
                                    (item.observacoes != null && item.observacoes!.isNotEmpty))
                                ? Colors.orange.shade200
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Componentes removidos
                            if (nomesComponentesRemovidos.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Removido${nomesComponentesRemovidos.length == 1 ? '' : 's'}:',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ...nomesComponentesRemovidos.map((nome) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade700,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    nome,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade800,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (item.observacoes != null && item.observacoes!.isNotEmpty)
                                const SizedBox(height: 12),
                            ],

                            // Observação
                            if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.note_outlined,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Observação:',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.observacoes!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
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

                    // Rodapé com quantidade e preço
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Controle de quantidade
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () {
                                  pedidoProvider.atualizarQuantidadeItem(
                                    item.id,
                                    item.quantidade - 1,
                                  );
                                },
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${item.quantidade}',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () {
                                  pedidoProvider.atualizarQuantidadeItem(
                                    item.id,
                                    item.quantidade + 1,
                                  );
                                },
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        // Preço total do item
                        Text(
                          'R\$ ${item.precoTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  void _confirmarRemoverItem(BuildContext context, ItemPedidoLocal item, PedidoProvider pedidoProvider) {
    AppDialog.showConfirm(
      context: context,
      title: 'Remover item?',
      message: 'Tem certeza que deseja remover "${item.produtoVariacaoNome ?? item.produtoNome}" do pedido?',
      confirmText: 'Remover',
      cancelText: 'Cancelar',
      icon: Icons.delete_outline,
      iconColor: Colors.red,
    ).then((confirmado) {
      if (confirmado == true && context.mounted) {
        pedidoProvider.removerItem(item.id);
        AppToast.showSuccess(
          context,
          '${item.produtoVariacaoNome ?? item.produtoNome} removido do pedido',
        );
      }
    });
  }

  Widget _buildFooter(PedidoProvider pedidoProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'R\$ ${pedidoProvider.total.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Botão finalizar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pedidoProvider.isEmpty ? null : onFinalizarPedido,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                'Finalizar Pedido',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarLimparPedido(BuildContext context) {
    Provider.of<PedidoProvider>(context, listen: false).limparPedido();
    AppToast.showSuccess(
      context,
      'Pedido limpo',
    );
  }

  void _editarItem(BuildContext context, ItemPedidoLocal item) {
    EditarItemPedidoModal.show(context, item);
  }
}

