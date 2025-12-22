import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mesas/comanda_com_produtos.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import 'produto_card_widget.dart';

/// Widget para exibir card de comanda expansível
class ComandaCardWidget extends StatelessWidget {
  final ComandaComProdutos comandaData;
  final AdaptiveLayoutProvider adaptive;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onPagarComanda;

  const ComandaCardWidget({
    super.key,
    required this.comandaData,
    required this.adaptive,
    required this.isExpanded,
    required this.onTap,
    this.onPagarComanda,
  });

  @override
  Widget build(BuildContext context) {
    final comanda = comandaData.comanda;
    final produtos = comandaData.produtos;
    final venda = comandaData.venda;
    final total = produtos.fold<double>(0.0, (sum, p) => sum + p.precoTotal);
    final saldoRestante = venda?.saldoRestante ?? total;
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: EdgeInsets.only(bottom: adaptive.isMobile ? 12 : 16),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header do card (sempre visível)
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
              child: Row(
                children: [
                  // Ícone da comanda
                  Container(
                    padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: AppTheme.primaryColor,
                      size: adaptive.isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: adaptive.isMobile ? 12 : 16),
                  // Informações da comanda
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comanda ${comanda.numero}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: adaptive.isMobile ? 6 : 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: comanda.status.toLowerCase() == 'em uso'
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                comanda.status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: comanda.status.toLowerCase() == 'em uso'
                                      ? AppTheme.successColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(width: adaptive.isMobile ? 8 : 12),
                            Text(
                              '${produtos.length} produto${produtos.length != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Valor e ícone de expansão
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(saldoRestante),
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: saldoRestante > 0 ? AppTheme.errorColor : AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Produtos (expansível)
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Container(
              constraints: const BoxConstraints(
                maxHeight: 400, // Altura máxima fixa para lista de produtos dentro do card
              ),
              child: produtos.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                      child: Center(
                        child: Text(
                          'Nenhum produto encontrado',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
                      itemCount: produtos.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: adaptive.isMobile ? 8 : 10),
                          child: ProdutoCardWidget(
                            produto: produtos[index],
                            adaptive: adaptive,
                          ),
                        );
                      },
                    ),
            ),
            // Botão de pagamento (só aparece se houver venda)
            if (venda != null && produtos.isNotEmpty && onPagarComanda != null)
              Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPagarComanda,
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(
                      'Pagar Comanda',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: adaptive.isMobile ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
