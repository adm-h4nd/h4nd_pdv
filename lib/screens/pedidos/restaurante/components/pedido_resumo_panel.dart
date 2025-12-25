import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/utils/image_url_helper.dart';
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione produtos para começar',
              style: GoogleFonts.plusJakartaSans(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pedido',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${pedidoProvider.quantidadeTotal} ${pedidoProvider.quantidadeTotal == 1 ? 'item' : 'itens'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onLimparPedido != null)
            Builder(
              builder: (context) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _confirmarLimparPedido(context);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        
        // Obter URL da imagem do produto
        String? imagemUrl;
        if (produto != null) {
          if (item.produtoVariacaoId != null && produto.variacoes.isNotEmpty) {
            try {
              final variacao = produto.variacoes.firstWhere(
                (v) => v.id == item.produtoVariacaoId,
              );
              if (variacao.imagemFileName != null && variacao.imagemFileName!.isNotEmpty) {
                imagemUrl = ImageUrlHelper.getThumbnailImageUrl(variacao.imagemFileName);
              }
            } catch (e) {
              // Variação não encontrada
            }
          }
          if (imagemUrl == null && produto.imagemFileName != null && produto.imagemFileName!.isNotEmpty) {
            imagemUrl = ImageUrlHelper.getThumbnailImageUrl(produto.imagemFileName);
          }
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              _editarItem(context, item);
            },
            onLongPress: () {
              _confirmarRemoverItem(context, item, pedidoProvider);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho do item com imagem
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Imagem pequena como identificador
                        if (imagemUrl != null)
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imagemUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        // Nome do produto e botões na mesma linha
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.produtoNome,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.produtoVariacaoNome != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.produtoVariacaoNome!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              // Botões de quantidade logo abaixo do nome
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          pedidoProvider.atualizarQuantidadeItem(
                                            item.id,
                                            item.quantidade - 1,
                                          );
                                        },
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          bottomLeft: Radius.circular(10),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Icon(
                                            Icons.remove,
                                            size: 18,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.symmetric(
                                          vertical: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '${item.quantidade}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          pedidoProvider.atualizarQuantidadeItem(
                                            item.id,
                                            item.quantidade + 1,
                                          );
                                        },
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(10),
                                          bottomRight: Radius.circular(10),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Icon(
                                            Icons.add,
                                            size: 18,
                                            color: Colors.grey.shade700,
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
                        // Botão remover e total na vertical
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _confirmarRemoverItem(context, item, pedidoProvider);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${item.precoTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Atributos selecionados
                    if (atributosSelecionados.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
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
                                  style: GoogleFonts.plusJakartaSans(
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
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
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
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Removido${nomesComponentesRemovidos.length == 1 ? '' : 's'}:',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        ...nomesComponentesRemovidos.map((nome) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 3,
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade700,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    nome,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
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
                                const SizedBox(height: 8),
                            ],

                            // Observação
                            if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.note_outlined,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Observação:',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.observacoes!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: Colors.grey.shade800,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
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
    final nomeProduto = item.produtoVariacaoNome != null 
        ? '${item.produtoNome} - ${item.produtoVariacaoNome}'
        : item.produtoNome;
    
    AppDialog.showConfirm(
      context: context,
      title: 'Remover item?',
      message: 'Tem certeza que deseja remover "$nomeProduto" do pedido?',
      confirmText: 'Remover',
      cancelText: 'Cancelar',
      icon: Icons.delete_outline,
      iconColor: Colors.red,
    ).then((confirmado) {
      if (confirmado == true && context.mounted) {
        pedidoProvider.removerItem(item.id);
        AppToast.showSuccess(
          context,
          '$nomeProduto removido do pedido',
        );
      }
    });
  }

  Widget _buildFooter(PedidoProvider pedidoProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'R\$ ${pedidoProvider.total.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
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
    AppDialog.showConfirm(
      context: context,
      title: 'Limpar pedido?',
      message: 'Tem certeza que deseja limpar todo o pedido? Esta ação não pode ser desfeita.',
      confirmText: 'Limpar',
      cancelText: 'Cancelar',
      icon: Icons.delete_outline,
      iconColor: Colors.red,
    ).then((confirmado) {
      if (confirmado == true && context.mounted) {
        Provider.of<PedidoProvider>(context, listen: false).limparPedido();
        AppToast.showSuccess(
          context,
          'Pedido limpo',
        );
      }
    });
  }

  void _editarItem(BuildContext context, ItemPedidoLocal item) {
    EditarItemPedidoModal.show(context, item);
  }
}

