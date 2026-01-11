import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../widgets/app_header.dart';
import '../../../data/models/core/caixa/ciclo_caixa_dto.dart';
import '../../../data/models/core/caixa/tipo_movimentacao.dart';
import '../../../presentation/providers/services_provider.dart';
import 'fechar_caixa_screen.dart';
import 'reforco_caixa_screen.dart';
import 'sangria_caixa_screen.dart';

/// Tela para visualizar informações do caixa aberto e realizar operações
class CaixaAbertoScreen extends StatefulWidget {
  final CicloCaixaDto cicloCaixa;

  const CaixaAbertoScreen({
    super.key,
    required this.cicloCaixa,
  });

  @override
  State<CaixaAbertoScreen> createState() => _CaixaAbertoScreenState();
}

class _CaixaAbertoScreenState extends State<CaixaAbertoScreen> {
  bool _isLoading = false;
  bool _isLoadingConfiguracao = true;
  bool _exibirValoresApurados = true; // Padrão: exibir
  CicloCaixaDto? _cicloCaixaAtualizado;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracaoRestaurante();
    _atualizarCicloCaixa();
  }

  /// Carrega a configuração do restaurante para verificar se deve exibir valores apurados
  Future<void> _carregarConfiguracaoRestaurante() async {
    setState(() {
      _isLoadingConfiguracao = true;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final config = servicesProvider.configuracaoRestaurante;
      
      if (mounted) {
        setState(() {
          _exibirValoresApurados = config?.exibirValoresFechamentoCaixa ?? true;
          _isLoadingConfiguracao = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar configuração do restaurante: $e');
      if (mounted) {
        setState(() {
          _isLoadingConfiguracao = false;
          _exibirValoresApurados = true; // Padrão: exibir
        });
      }
    }
  }

  /// Busca o ciclo de caixa atualizado
  Future<void> _atualizarCicloCaixa() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final cicloCaixaService = servicesProvider.cicloCaixaService;

      final response = await cicloCaixaService.getCicloAbertoPorCaixa(
        widget.cicloCaixa.caixaId,
      );

      if (response.success && response.data != null) {
        setState(() {
          _cicloCaixaAtualizado = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar ciclo de caixa: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  CicloCaixaDto get _cicloCaixa => _cicloCaixaAtualizado ?? widget.cicloCaixa;

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoading || _isLoadingConfiguracao) {
      return Scaffold(
        appBar: AppHeader(
          title: 'Caixa Aberto',
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ciclo = _cicloCaixa;
    final dataAbertura = DateTime.tryParse(ciclo.dataHoraAbertura);
    final dataFormatada = dataAbertura != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(dataAbertura.toLocal())
        : 'Data não disponível';

    // Calcular valores das movimentações
    final valorInicial = ciclo.valorInicial;
    final dinheiroApuradoVendas = ciclo.valorDinheiroEsperado ?? 0.0;
    
    // Calcular total de reforços (TODAS as entradas que não são de vendas - têm ContaOrigemId mas não têm PagamentoVendaId)
    // Inclui a movimentação inicial de abertura, pois ela também é um reforço
    final totalReforcosBruto = ciclo.movimentacoes
        .where((m) => 
            m.tipo == TipoMovimentacao.entrada && 
            m.pagamentoVendaId == null && 
            m.contaOrigemId != null)
        .fold(0.0, (sum, m) => sum + m.valor);
    
    // Total de reforços para exibição (descontando o valor inicial, pois ele já tem seu próprio campo)
    final totalReforcosExibicao = totalReforcosBruto - valorInicial;
    
    // Calcular total de sangrias (todas as saídas)
    final totalSangrias = ciclo.movimentacoes
        .where((m) => m.tipo == TipoMovimentacao.saida)
        .fold(0.0, (sum, m) => sum + m.valor);
    
    // Saldo disponível com vendas = Reforços (já inclui valor inicial) + Dinheiro Apurado das Vendas - Sangrias
    // Não somamos valorInicial novamente, pois ele já está incluído no totalReforcosBruto
    final saldoDisponivelComVendas = totalReforcosBruto + dinheiroApuradoVendas - totalSangrias;
    
    // Saldo sem apuração de vendas = Reforços (já inclui valor inicial) - Sangrias
    final saldoSemApuracao = totalReforcosBruto - totalSangrias;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppHeader(
        title: 'Caixa Aberto',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _atualizarCicloCaixa,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final useGrid = !adaptive.isMobile && isWide;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(adaptive.isMobile ? 16.0 : 24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: adaptive.isMobile ? double.infinity : 1200,
                ),
                child: useGrid
                    ? _buildWideLayout(adaptive, ciclo, dataFormatada, valorInicial, totalReforcosExibicao, dinheiroApuradoVendas, totalSangrias, saldoDisponivelComVendas, saldoSemApuracao)
                    : _buildMobileLayout(adaptive, ciclo, dataFormatada, valorInicial, totalReforcosExibicao, dinheiroApuradoVendas, totalSangrias, saldoDisponivelComVendas, saldoSemApuracao),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(
    AdaptiveLayoutProvider adaptive,
    CicloCaixaDto ciclo,
    String dataFormatada,
    double valorInicial,
    double totalReforcos,
    double dinheiroApuradoVendas,
    double totalSangrias,
    double saldoDisponivelComVendas,
    double saldoSemApuracao,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                // Card de informações do ciclo
                Container(
                  padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: AppTheme.successColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Caixa: ${ciclo.caixaNome}',
                                  style: GoogleFonts.inter(
                                    fontSize: adaptive.isMobile ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: Aberto',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        adaptive,
                        'Aberto por',
                        ciclo.usuarioAberturaNome,
                        Icons.person,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        adaptive,
                        'Data de Abertura',
                        dataFormatada,
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 16),
                      Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Resumo Financeiro',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        adaptive,
                        'Saldo Inicial',
                        _formatCurrency(valorInicial),
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        adaptive,
                        'Total de Reforços',
                        _formatCurrency(totalReforcos),
                        Icons.add_circle,
                        color: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 12),
                      if (_exibirValoresApurados)
                        _buildInfoRow(
                          adaptive,
                          'Dinheiro Apurado das Vendas',
                          _formatCurrency(dinheiroApuradoVendas),
                          Icons.money,
                        ),
                      if (_exibirValoresApurados) const SizedBox(height: 12),
                      _buildInfoRow(
                        adaptive,
                        'Total de Sangrias',
                        _formatCurrency(totalSangrias),
                        Icons.remove_circle,
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 16),
                      Divider(),
                      const SizedBox(height: 16),
                      // Alerta quando não exibe valores apurados
                      if (!_exibirValoresApurados)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.warningColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'O saldo exibido não contempla o valor de vendas apuradas',
                                  style: GoogleFonts.inter(
                                    fontSize: adaptive.isMobile ? 12 : 13,
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _exibirValoresApurados
                                  ? 'Saldo Disponível (Dinheiro Físico)'
                                  : 'Saldo em Caixa',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 12 : 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCurrency(_exibirValoresApurados ? saldoDisponivelComVendas : saldoSemApuracao),
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 24 : 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _exibirValoresApurados
                                  ? 'Valor Inicial + Reforços + Vendas - Sangrias'
                                  : 'Valor Inicial + Reforços - Sangrias',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: adaptive.isMobile ? 24 : 32),

                // Botões de ação
                Text(
                  'Operações',
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: adaptive.isMobile ? 12 : 16),

                // Botão de Reforço
                _buildActionButton(
                  adaptive,
                  title: 'Reforço (Crédito)',
                  subtitle: 'Adicionar dinheiro ao caixa',
                  icon: Icons.add_circle,
                  color: const Color(0xFF059669),
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdaptiveLayout(
                          child: ReforcoCaixaScreen(
                            cicloCaixa: ciclo,
                          ),
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      _atualizarCicloCaixa();
                    }
                  },
                ),
                SizedBox(height: adaptive.isMobile ? 12 : 16),

                // Botão de Sangria
                _buildActionButton(
                  adaptive,
                  title: 'Sangria (Débito)',
                  subtitle: 'Retirar dinheiro do caixa',
                  icon: Icons.remove_circle,
                  color: const Color(0xFFDC2626),
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdaptiveLayout(
                          child: SangriaCaixaScreen(
                            cicloCaixa: ciclo,
                          ),
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      _atualizarCicloCaixa();
                    }
                  },
                ),
                SizedBox(height: adaptive.isMobile ? 12 : 16),

                // Botão de Fechar
                _buildActionButton(
                  adaptive,
                  title: 'Fechar Caixa',
                  subtitle: 'Finalizar o ciclo de caixa',
                  icon: Icons.lock,
                  color: AppTheme.primaryColor,
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdaptiveLayout(
                          child: FecharCaixaScreen(
                            cicloCaixa: ciclo,
                          ),
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
    );
  }

  Widget _buildWideLayout(
    AdaptiveLayoutProvider adaptive,
    CicloCaixaDto ciclo,
    String dataFormatada,
    double valorInicial,
    double totalReforcos,
    double dinheiroApuradoVendas,
    double totalSangrias,
    double saldoDisponivelComVendas,
    double saldoSemApuracao,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card de informações do ciclo (lado esquerdo)
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Caixa: ${ciclo.caixaNome}',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: Aberto',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.successColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      adaptive,
                      'Aberto por',
                      ciclo.usuarioAberturaNome,
                      Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      adaptive,
                      'Data de Abertura',
                      dataFormatada,
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Card de resumo financeiro (lado direito)
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo Financeiro',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      adaptive,
                      'Saldo Inicial',
                      _formatCurrency(valorInicial),
                      Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      adaptive,
                      'Total de Reforços',
                      _formatCurrency(totalReforcos),
                      Icons.add_circle,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 12),
                    if (_exibirValoresApurados)
                      _buildInfoRow(
                        adaptive,
                        'Dinheiro Apurado das Vendas',
                        _formatCurrency(dinheiroApuradoVendas),
                        Icons.money,
                      ),
                    if (_exibirValoresApurados) const SizedBox(height: 12),
                    _buildInfoRow(
                      adaptive,
                      'Total de Sangrias',
                      _formatCurrency(totalSangrias),
                      Icons.remove_circle,
                      color: const Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 16),
                    Divider(),
                    const SizedBox(height: 16),
                    // Alerta quando não exibe valores apurados
                    if (!_exibirValoresApurados)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'O saldo exibido não contempla o valor de vendas apuradas',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _exibirValoresApurados
                                ? 'Saldo Disponível (Dinheiro Físico)'
                                : 'Saldo em Caixa',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(_exibirValoresApurados ? saldoDisponivelComVendas : saldoSemApuracao),
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _exibirValoresApurados
                                ? 'Valor Inicial + Reforços + Vendas - Sangrias'
                                : 'Valor Inicial + Reforços - Sangrias',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: adaptive.isMobile ? 24 : 32),
        // Botões de ação
        Text(
          'Operações',
          style: GoogleFonts.inter(
            fontSize: adaptive.isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: adaptive.isMobile ? 12 : 16),
        // Grid de botões em layout wide
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                adaptive,
                title: 'Reforço (Crédito)',
                subtitle: 'Adicionar dinheiro ao caixa',
                icon: Icons.add_circle,
                color: const Color(0xFF059669),
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdaptiveLayout(
                        child: ReforcoCaixaScreen(
                          cicloCaixa: ciclo,
                        ),
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    _atualizarCicloCaixa();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                adaptive,
                title: 'Sangria (Débito)',
                subtitle: 'Retirar dinheiro do caixa',
                icon: Icons.remove_circle,
                color: const Color(0xFFDC2626),
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdaptiveLayout(
                        child: SangriaCaixaScreen(
                          cicloCaixa: ciclo,
                        ),
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    _atualizarCicloCaixa();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                adaptive,
                title: 'Fechar Caixa',
                subtitle: 'Finalizar o ciclo de caixa',
                icon: Icons.lock,
                color: AppTheme.primaryColor,
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdaptiveLayout(
                        child: FecharCaixaScreen(
                          cicloCaixa: ciclo,
                        ),
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(AdaptiveLayoutProvider adaptive, String label, String value, IconData icon, {Color? color}) {
    final iconColor = color ?? AppTheme.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    AdaptiveLayoutProvider adaptive, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

