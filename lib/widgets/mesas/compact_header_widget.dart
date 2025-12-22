import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import 'total_item_widget.dart';
import 'historico_pagamentos_widget.dart';

/// Header compacto com valores financeiros e histórico de pagamentos expansível
class CompactHeaderWidget extends StatelessWidget {
  final AdaptiveLayoutProvider adaptive;
  final double total;
  final double valorPago;
  final List<PagamentoVendaDto> pagamentos;
  final bool historicoExpandido;
  final VoidCallback onToggleHistorico;

  const CompactHeaderWidget({
    super.key,
    required this.adaptive,
    required this.total,
    required this.valorPago,
    required this.pagamentos,
    required this.historicoExpandido,
    required this.onToggleHistorico,
  });

  @override
  Widget build(BuildContext context) {
    final saldoRestante = total - valorPago;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resumo de valores
          Padding(
            padding: EdgeInsets.fromLTRB(
              adaptive.isMobile ? 16 : 20,
              14,
              adaptive.isMobile ? 16 : 20,
              14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TotalItemWidget(
                    adaptive: adaptive,
                    icon: Icons.receipt_long,
                    label: 'Total',
                    value: 'R\$ ${total.toStringAsFixed(2)}',
                    color: AppTheme.primaryColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TotalItemWidget(
                        adaptive: adaptive,
                        icon: Icons.check_circle_outline,
                        label: 'Valor Pago',
                        value: 'R\$ ${valorPago.toStringAsFixed(2)}',
                        color: AppTheme.successColor,
                      ),
                      // Ícone de expansão apenas se houver pagamentos
                      if (pagamentos.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: onToggleHistorico,
                            child: Icon(
                              historicoExpandido ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: TotalItemWidget(
                    adaptive: adaptive,
                    icon: Icons.pending_outlined,
                    label: 'Saldo a Pagar',
                    value: 'R\$ ${saldoRestante.toStringAsFixed(2)}',
                    color: saldoRestante > 0 ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Expansão de histórico de pagamentos (apenas se houver pagamentos e estiver expandido)
          if (pagamentos.isNotEmpty && historicoExpandido)
            Container(
              padding: EdgeInsets.fromLTRB(
                adaptive.isMobile ? 16 : 20,
                0,
                adaptive.isMobile ? 16 : 20,
                12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: HistoricoPagamentosWidget(
                pagamentos: pagamentos,
                adaptive: adaptive,
              ),
            ),
        ],
      ),
    );
  }
}
