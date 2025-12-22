import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import '../../core/utils/date_formatter.dart';

/// Widget para exibir histórico de pagamentos
class HistoricoPagamentosWidget extends StatelessWidget {
  final List<PagamentoVendaDto> pagamentos;
  final AdaptiveLayoutProvider adaptive;

  const HistoricoPagamentosWidget({
    super.key,
    required this.pagamentos,
    required this.adaptive,
  });

  @override
  Widget build(BuildContext context) {
    // Ordena por data de pagamento (mais recente primeiro)
    final pagamentosOrdenados = List<PagamentoVendaDto>.from(pagamentos)
      ..sort((a, b) => b.dataPagamento.compareTo(a.dataPagamento));
    
    return Column(
      children: pagamentosOrdenados.map((pagamento) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pagamento.formaPagamento,
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'R\$ ${pagamento.valor.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.formatarDataHora(pagamento.dataPagamento),
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 12 : 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (pagamento.numeroParcelas > 1) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.credit_card,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pagamento.numeroParcelas}x',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 12 : 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              if (pagamento.bandeiraCartao != null || pagamento.ultimosDigitosCartao != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (pagamento.bandeiraCartao != null) ...[
                      Text(
                        pagamento.bandeiraCartao!,
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 11 : 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (pagamento.ultimosDigitosCartao != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•••• ${pagamento.ultimosDigitosCartao}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 11 : 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ] else if (pagamento.ultimosDigitosCartao != null) ...[
                      Text(
                        '•••• ${pagamento.ultimosDigitosCartao}',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 11 : 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
