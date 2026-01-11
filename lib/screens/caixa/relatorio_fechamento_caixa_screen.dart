import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../data/models/core/caixa/ciclo_caixa_dto.dart';
import '../../../data/models/core/caixa/tipo_movimentacao.dart';
import '../../../widgets/app_header.dart';
import '../../../presentation/widgets/common/home_navigation.dart';

/// Tela de relatório de fechamento de caixa
/// Exibe valores esperados vs contados e detalhes por PDV
class RelatorioFechamentoCaixaScreen extends StatelessWidget {
  final CicloCaixaDto cicloCaixa;

  const RelatorioFechamentoCaixaScreen({
    super.key,
    required this.cicloCaixa,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppHeader(
        title: 'Relatório de Fechamento',
        showBackButton: false, // Não exibe botão de voltar
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Conteúdo scrollável
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cabeçalho do relatório
                        _buildHeader(context, adaptive),
                        SizedBox(height: adaptive.isMobile ? 12 : 16),

                        // Resumo geral
                        _buildResumoGeral(context, adaptive),
                        SizedBox(height: adaptive.isMobile ? 12 : 16),

                        // Comparação por forma de pagamento
                        _buildComparacaoFormasPagamento(context, adaptive),
                        SizedBox(height: adaptive.isMobile ? 12 : 16),

                        // Detalhes por PDV
                        _buildDetalhesPorPDV(context, adaptive),
                        // Espaço para os botões do rodapé
                        SizedBox(height: adaptive.isMobile ? 80 : 100),
                      ],
                    ),
                  ),
                ),
              ),
              // Rodapé com botões fixos
              _buildFooter(context, adaptive),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdaptiveLayoutProvider adaptive) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dataAbertura = DateTime.tryParse(cicloCaixa.dataHoraAbertura);
    final dataFechamento = cicloCaixa.dataHoraFechamento != null
        ? DateTime.tryParse(cicloCaixa.dataHoraFechamento!)
        : null;

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cicloCaixa.caixaNome,
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ciclo de Caixa',
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          if (adaptive.isMobile)
            Column(
              children: [
                _buildInfoItem('Abertura', dataAbertura != null
                    ? dateFormat.format(dataAbertura)
                    : '-'),
                const SizedBox(height: 12),
                _buildInfoItem('Fechamento', dataFechamento != null
                    ? dateFormat.format(dataFechamento)
                    : '-'),
                const SizedBox(height: 12),
                _buildInfoItem('Valor Inicial', _formatCurrency(cicloCaixa.valorInicial)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Abertura', dataAbertura != null
                      ? dateFormat.format(dataAbertura)
                      : '-'),
                ),
                Expanded(
                  child: _buildInfoItem('Fechamento', dataFechamento != null
                      ? dateFormat.format(dataFechamento)
                      : '-'),
                ),
                Expanded(
                  child: _buildInfoItem('Valor Inicial', _formatCurrency(cicloCaixa.valorInicial)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildResumoGeral(BuildContext context, AdaptiveLayoutProvider adaptive) {
    final totalEsperado = _getTotalEsperado();
    final totalContado = _getTotalContado();
    final diferenca = totalContado - totalEsperado;
    final percentual = totalEsperado > 0 ? (totalContado / totalEsperado * 100) : 0.0;

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo Geral',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: adaptive.isMobile ? 12 : 14),
          if (adaptive.isMobile)
            Column(
              children: [
                _buildResumoItem('Esperado', totalEsperado, Colors.white),
                const SizedBox(height: 8),
                _buildResumoItem('Contado', totalContado, Colors.white),
                const SizedBox(height: 8),
                _buildResumoItem(
                  'Diferença',
                  diferenca,
                  diferenca == 0 ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildResumoItem('Esperado', totalEsperado, Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildResumoItem('Contado', totalContado, Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildResumoItem(
                    'Diferença',
                    diferenca,
                    diferenca == 0 ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          SizedBox(height: adaptive.isMobile ? 10 : 12),
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Percentual',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, double valor, Color valorColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(valor),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparacaoFormasPagamento(
    BuildContext context,
    AdaptiveLayoutProvider adaptive,
  ) {
    final formasPagamento = [
      _FormaPagamentoData(
        label: 'Dinheiro',
        esperado: cicloCaixa.valorDinheiroEsperado ?? 0,
        contado: cicloCaixa.valorDinheiroContado ?? 0,
        icon: Icons.money,
        color: AppTheme.successColor,
      ),
      _FormaPagamentoData(
        label: 'Cartão Crédito',
        esperado: cicloCaixa.valorCartaoCreditoEsperado ?? 0,
        contado: cicloCaixa.valorCartaoCreditoContado ?? 0,
        icon: Icons.credit_card,
        color: AppTheme.infoColor,
      ),
      _FormaPagamentoData(
        label: 'Cartão Débito',
        esperado: cicloCaixa.valorCartaoDebitoEsperado ?? 0,
        contado: cicloCaixa.valorCartaoDebitoContado ?? 0,
        icon: Icons.credit_card,
        color: AppTheme.primaryColor,
      ),
      _FormaPagamentoData(
        label: 'PIX',
        esperado: cicloCaixa.valorPIXEsperado ?? 0,
        contado: cicloCaixa.valorPIXContado ?? 0,
        icon: Icons.qr_code,
        color: AppTheme.secondaryColor,
      ),
      _FormaPagamentoData(
        label: 'Outros',
        esperado: cicloCaixa.valorOutrosEsperado ?? 0,
        contado: cicloCaixa.valorOutrosContado ?? 0,
        icon: Icons.more_horiz,
        color: AppTheme.textSecondary,
      ),
    ].where((f) => f.esperado > 0 || f.contado > 0).toList();

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparação por Forma de Pagamento',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: adaptive.isMobile ? 12 : 14),
          if (adaptive.isMobile)
            ...formasPagamento.map((forma) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildFormaPagamentoItem(forma, adaptive),
                ))
          else
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: formasPagamento.map((forma) => SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildFormaPagamentoItem(forma, adaptive),
                    )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormaPagamentoItem(
    _FormaPagamentoData forma,
    AdaptiveLayoutProvider adaptive,
  ) {
    final diferenca = forma.contado - forma.esperado;
    final isOk = diferenca == 0;
    final maxValor = forma.esperado > forma.contado ? forma.esperado : forma.contado;

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOk ? AppTheme.successColor.withOpacity(0.3) : AppTheme.errorColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: forma.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(forma.icon, color: forma.color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  forma.label,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isOk ? AppTheme.successColor : AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOk ? 'OK' : 'FALTA',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.isMobile ? 10 : 12),
          // Barra de progresso
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Esperado: ${_formatCurrency(forma.esperado)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Contado: ${_formatCurrency(forma.contado)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOk ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: maxValor > 0 ? (forma.esperado / maxValor).clamp(0.0, 1.0) : 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: maxValor > 0 ? (forma.contado / maxValor).clamp(0.0, 1.0) : 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: isOk ? AppTheme.successColor : AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: adaptive.isMobile ? 8 : 10),
          if (diferenca != 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    diferenca > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Diferença: ${_formatCurrency(diferenca.abs())} ${diferenca > 0 ? 'a mais' : 'a menos'}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetalhesPorPDV(BuildContext context, AdaptiveLayoutProvider adaptive) {
    final resumosPorPDV = _agruparMovimentacoesPorPDV();

    if (resumosPorPDV.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo por PDV',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: adaptive.isMobile ? 12 : 14),
          ...resumosPorPDV.values.map((resumo) => _buildPDVCard(
                resumo,
                adaptive,
              )),
        ],
      ),
    );
  }

  Widget _buildPDVCard(
    _PDVResumo resumo,
    AdaptiveLayoutProvider adaptive,
  ) {
    final saldo = resumo.entradas - resumo.saidas;

    return Card(
      margin: EdgeInsets.only(bottom: adaptive.isMobile ? 8 : 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.point_of_sale,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resumo.pdvNome,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(saldo),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: saldo >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                    Text(
                      'Saldo',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: adaptive.isMobile ? 10 : 12),
            if (adaptive.isMobile)
              Column(
                children: [
                  _buildPDVResumoItem(adaptive, 'Entradas', resumo.entradas, AppTheme.successColor),
                  const SizedBox(height: 6),
                  _buildPDVResumoItem(adaptive, 'Saídas', resumo.saidas, AppTheme.errorColor),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildPDVResumoItem(adaptive, 'Entradas', resumo.entradas, AppTheme.successColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPDVResumoItem(adaptive, 'Saídas', resumo.saidas, AppTheme.errorColor),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

   Widget _buildPDVResumoItem(AdaptiveLayoutProvider adaptive, String label, double valor, Color color) {
     return Container(
       padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
       decoration: BoxDecoration(
         color: color.withOpacity(0.1),
         borderRadius: BorderRadius.circular(8),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(
             label,
             style: GoogleFonts.inter(
               fontSize: adaptive.isMobile ? 12 : 13,
               color: AppTheme.textSecondary,
             ),
           ),
           Text(
             _formatCurrency(valor),
             style: GoogleFonts.inter(
               fontSize: adaptive.isMobile ? 14 : 15,
               fontWeight: FontWeight.bold,
               color: color,
             ),
           ),
         ],
       ),
     );
   }

  double _getTotalEsperado() {
    return (cicloCaixa.valorDinheiroEsperado ?? 0) +
        (cicloCaixa.valorCartaoCreditoEsperado ?? 0) +
        (cicloCaixa.valorCartaoDebitoEsperado ?? 0) +
        (cicloCaixa.valorPIXEsperado ?? 0) +
        (cicloCaixa.valorOutrosEsperado ?? 0);
  }

  double _getTotalContado() {
    return (cicloCaixa.valorDinheiroContado ?? 0) +
        (cicloCaixa.valorCartaoCreditoContado ?? 0) +
        (cicloCaixa.valorCartaoDebitoContado ?? 0) +
        (cicloCaixa.valorPIXContado ?? 0) +
        (cicloCaixa.valorOutrosContado ?? 0);
  }

  Map<String, _PDVResumo> _agruparMovimentacoesPorPDV() {
    final map = <String, _PDVResumo>{};
    for (final mov in cicloCaixa.movimentacoes) {
      final pdvNome = mov.pdvNome.isNotEmpty ? mov.pdvNome : 'PDV Desconhecido';
      final resumo = map.putIfAbsent(
        pdvNome,
        () => _PDVResumo(pdvNome: pdvNome),
      );
      
      if (mov.tipo == TipoMovimentacao.entrada) {
        resumo.entradas += mov.valor;
      } else {
        resumo.saidas += mov.valor;
      }
    }
    return map;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  /// Constrói o rodapé com botões de ação
  Widget _buildFooter(BuildContext context, AdaptiveLayoutProvider adaptive) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
              spreadRadius: 0,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.isMobile ? 16 : 24,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Botão Imprimir
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implementar impressão
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidade de impressão em desenvolvimento'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.print),
                label: Text(
                  'Imprimir',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: adaptive.isMobile ? 14 : 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: adaptive.isMobile ? 14 : 16,
                  ),
                  side: BorderSide(color: AppTheme.primaryColor, width: 2),
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(width: adaptive.isMobile ? 12 : 16),
            // Botão Concluir
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navegar para a Home, removendo todas as telas anteriores
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const AdaptiveLayout(
                        child: HomeNavigation(),
                      ),
                    ),
                    (route) => false, // Remove todas as rotas anteriores
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'Concluir',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: adaptive.isMobile ? 14 : 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: adaptive.isMobile ? 14 : 16,
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormaPagamentoData {
  final String label;
  final double esperado;
  final double contado;
  final IconData icon;
  final Color color;

  _FormaPagamentoData({
    required this.label,
    required this.esperado,
    required this.contado,
    required this.icon,
    required this.color,
  });
}

class _PDVResumo {
  final String pdvNome;
  double entradas;
  double saidas;

  _PDVResumo({
    required this.pdvNome,
  })  : entradas = 0.0,
        saidas = 0.0;
}

