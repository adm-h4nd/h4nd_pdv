import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message_helper.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../widgets/app_header.dart';
import '../../../data/models/core/caixa/ciclo_caixa_dto.dart';
import '../../../data/services/core/ciclo_caixa_service.dart';
import '../../../presentation/providers/services_provider.dart';
import 'relatorio_fechamento_caixa_screen.dart';

/// Tela para fechar um ciclo de caixa
class FecharCaixaScreen extends StatefulWidget {
  final CicloCaixaDto cicloCaixa;

  const FecharCaixaScreen({
    super.key,
    required this.cicloCaixa,
  });

  @override
  State<FecharCaixaScreen> createState() => _FecharCaixaScreenState();
}

class _FecharCaixaScreenState extends State<FecharCaixaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorDinheiroController = TextEditingController();
  final _valorCartaoCreditoController = TextEditingController();
  final _valorCartaoDebitoController = TextEditingController();
  final _valorPIXController = TextEditingController();
  final _valorOutrosController = TextEditingController();
  final _observacoesController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  bool _exibirValoresApurados = true; // Padrão: exibir
  bool _isLoadingConfiguracao = true;
  bool _isLoadingCiclo = false;

  // Ciclo de caixa atualizado (pode ser diferente do widget.cicloCaixa inicial)
  CicloCaixaDto? _cicloCaixaAtualizado;

  // Valores para resumo auto-atualizável
  double _totalContado = 0.0;
  double _totalEsperado = 0.0;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracaoRestaurante();
    _atualizarCicloCaixa();
    _adicionarListeners();
    _calcularTotais();
  }

  /// Busca o ciclo de caixa atualizado do backend para obter os valores esperados atualizados
  Future<void> _atualizarCicloCaixa() async {
    setState(() {
      _isLoadingCiclo = true;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final cicloCaixaService = CicloCaixaService(
        apiClient: servicesProvider.authService.apiClient,
      );

      final response = await cicloCaixaService.getCicloAbertoPorCaixa(
        _cicloCaixa.caixaId,
      );

      if (response.success && response.data != null) {
        setState(() {
          _cicloCaixaAtualizado = response.data;
          _isLoadingCiclo = false;
        });
        // Recalcular totais com os novos valores
        _calcularTotais();
      } else {
        setState(() {
          _isLoadingCiclo = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar ciclo de caixa: $e');
      setState(() {
        _isLoadingCiclo = false;
      });
    }
  }

  /// Retorna o ciclo de caixa atualizado ou o inicial
  CicloCaixaDto get _cicloCaixa => _cicloCaixaAtualizado ?? widget.cicloCaixa;

  @override
  void dispose() {
    _removerListeners();
    _valorDinheiroController.dispose();
    _valorCartaoCreditoController.dispose();
    _valorCartaoDebitoController.dispose();
    _valorPIXController.dispose();
    _valorOutrosController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _adicionarListeners() {
    _valorDinheiroController.addListener(_calcularTotais);
    _valorCartaoCreditoController.addListener(_calcularTotais);
    _valorCartaoDebitoController.addListener(_calcularTotais);
    _valorPIXController.addListener(_calcularTotais);
    _valorOutrosController.addListener(_calcularTotais);
  }

  void _removerListeners() {
    _valorDinheiroController.removeListener(_calcularTotais);
    _valorCartaoCreditoController.removeListener(_calcularTotais);
    _valorCartaoDebitoController.removeListener(_calcularTotais);
    _valorPIXController.removeListener(_calcularTotais);
    _valorOutrosController.removeListener(_calcularTotais);
  }

  void _calcularTotais() {
    if (!mounted) return;
    
    final totalContado = (_parseValor(_valorDinheiroController.text) ?? 0.0) +
        (_parseValor(_valorCartaoCreditoController.text) ?? 0.0) +
        (_parseValor(_valorCartaoDebitoController.text) ?? 0.0) +
        (_parseValor(_valorPIXController.text) ?? 0.0) +
        (_parseValor(_valorOutrosController.text) ?? 0.0);

    final totalEsperado = (_cicloCaixa.valorDinheiroEsperado ?? 0.0) +
        (_cicloCaixa.valorCartaoCreditoEsperado ?? 0.0) +
        (_cicloCaixa.valorCartaoDebitoEsperado ?? 0.0) +
        (_cicloCaixa.valorPIXEsperado ?? 0.0) +
        (_cicloCaixa.valorOutrosEsperado ?? 0.0);

    setState(() {
      _totalContado = totalContado;
      _totalEsperado = totalEsperado;
    });
  }

  Future<void> _carregarConfiguracaoRestaurante() async {
    setState(() {
      _isLoadingConfiguracao = true;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final config = servicesProvider.configuracaoRestaurante;
      
      if (config != null) {
        setState(() {
          _exibirValoresApurados = config.exibirValoresFechamentoCaixa;
          _isLoadingConfiguracao = false;
        });
      } else {
        // Se não houver configuração, usar padrão (true)
        setState(() {
          _exibirValoresApurados = true;
          _isLoadingConfiguracao = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configuração do restaurante: $e');
      // Em caso de erro, usar padrão (true)
      setState(() {
        _exibirValoresApurados = true;
        _isLoadingConfiguracao = false;
      });
    }
  }

  double? _parseValor(String? text) {
    if (text == null || text.isEmpty) return null;
    final valor = double.tryParse(text.replaceAll(',', '.'));
    return valor != null && valor >= 0 ? valor : null;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  Future<void> _fecharCaixa() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final cicloCaixaService = servicesProvider.cicloCaixaService;

      final response = await cicloCaixaService.fecharCicloCaixa(
        cicloCaixaId: _cicloCaixa.id,
        valorDinheiroContado: _parseValor(_valorDinheiroController.text),
        valorCartaoCreditoContado: _parseValor(_valorCartaoCreditoController.text),
        valorCartaoDebitoContado: _parseValor(_valorCartaoDebitoController.text),
        valorPIXContado: _parseValor(_valorPIXController.text),
        valorOutrosContado: _parseValor(_valorOutrosController.text),
        observacoesFechamento: _observacoesController.text.isEmpty 
            ? null 
            : _observacoesController.text,
      );

      if (!mounted) return;

      if (!response.success || response.data == null) {
        setState(() {
          _errorMessage = ErrorMessageHelper.getErrorMessage(
            response,
            defaultMessage: 'Erro ao fechar caixa',
          );
          _isSaving = false;
        });
        return;
      }

      // Sucesso - navegar para tela de relatório
      if (mounted && response.data != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: RelatorioFechamentoCaixaScreen(
                cicloCaixa: response.data!,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao fechar caixa: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  Widget _buildCampoValor({
    required AdaptiveLayoutProvider adaptive,
    required String label,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    double? valorApurado,
    bool mostrarValorApurado = false,
  }) {
    final valorContado = _parseValor(controller.text) ?? 0.0;
    final valorApuradoCalculado = valorApurado ?? 0.0;
    final diferenca = valorContado - valorApuradoCalculado;
    final temDiferenca = diferenca != 0 && mostrarValorApurado && valorApuradoCalculado > 0;

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: temDiferenca 
              ? (diferenca > 0 ? AppTheme.infoColor : AppTheme.errorColor).withOpacity(0.3)
              : Colors.grey.shade200,
          width: temDiferenca ? 2 : 1,
        ),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: adaptive.isMobile ? 18 : 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
                      style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
                    if (mostrarValorApurado)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Apurado: ${_formatCurrency(valorApurado ?? 0.0)}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 11 : 12,
                  color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (temDiferenca)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (diferenca > 0 ? AppTheme.infoColor : AppTheme.errorColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        diferenca > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: diferenca > 0 ? AppTheme.infoColor : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatCurrency(diferenca.abs()),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: diferenca > 0 ? AppTheme.infoColor : AppTheme.errorColor,
                        ),
                      ),
                    ],
                ),
              ),
          ],
        ),
          SizedBox(height: adaptive.isMobile ? 8 : 10),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: '0,00',
            prefixText: 'R\$ ',
              prefixStyle: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2),
            ),
            filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: adaptive.isMobile ? 12 : 14,
                vertical: adaptive.isMobile ? 12 : 14,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final valor = double.tryParse(value.replaceAll(',', '.'));
              if (valor == null) {
                return 'Valor inválido';
              }
              if (valor < 0) {
                return 'O valor não pode ser negativo';
              }
            }
            return null;
          },
        ),
      ],
      ),
    );
  }

  Widget _buildResumoCompacto(AdaptiveLayoutProvider adaptive) {
    // Se não deve exibir valores apurados, mostra apenas o total contado
    if (!_exibirValoresApurados) {
      return Container(
        padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Total Contado: ',
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 13 : 14,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              _formatCurrency(_totalContado),
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 15 : 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    // Se deve exibir valores apurados, mostra esperado, contado e diferença
    final diferenca = _totalContado - _totalEsperado;
    final diferencaColor = diferenca == 0
        ? AppTheme.successColor
        : diferenca > 0
            ? AppTheme.infoColor
            : AppTheme.errorColor;

    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: diferencaColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: diferencaColor.withOpacity(0.2),
        ),
      ),
      child: adaptive.isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Esperado: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          _formatCurrency(_totalEsperado),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Contado: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _formatCurrency(_totalContado),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      diferenca == 0
                          ? Icons.check_circle
                          : diferenca > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                      size: 16,
                      color: diferencaColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Diferença: ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: diferencaColor,
                      ),
                    ),
                    Text(
                      _formatCurrency(diferenca),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: diferencaColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Esperado: ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      _formatCurrency(_totalEsperado),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Contado: ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _formatCurrency(_totalContado),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      diferenca == 0
                          ? Icons.check_circle
                          : diferenca > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                      size: 16,
                      color: diferencaColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Diferença: ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: diferencaColor,
                      ),
                    ),
                    Text(
                      _formatCurrency(diferenca),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: diferencaColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ciclo = _cicloCaixa;
    final dataAbertura = DateTime.tryParse(ciclo.dataHoraAbertura);
    final dataFormatada = dataAbertura != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(dataAbertura.toLocal())
        : 'Data não disponível';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppHeader(
        title: 'Fechar Caixa',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: (_isLoadingConfiguracao || _isLoadingCiclo)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
        child: SingleChildScrollView(
                    padding: EdgeInsets.all(adaptive.isMobile ? 12.0 : 16.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: adaptive.isMobile ? double.infinity : 1200,
                        ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Informações do ciclo
                Container(
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
                                        Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
                                        const SizedBox(width: 6),
                      Text(
                        'Informações do Ciclo',
                                          style: GoogleFonts.inter(
                                            fontSize: adaptive.isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (adaptive.isMobile)
                                      Column(
                                        children: [
                                          _buildInfoRow(adaptive, Icons.point_of_sale, 'Caixa', ciclo.caixaNome),
                                          _buildInfoRow(adaptive, Icons.person, 'Aberto por', ciclo.usuarioAberturaNome),
                                          _buildInfoRow(adaptive, Icons.calendar_today, 'Data/Hora', dataFormatada),
                                          _buildInfoRow(adaptive, Icons.account_balance_wallet, 'Valor Inicial', _formatCurrency(ciclo.valorInicial)),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _buildInfoRow(adaptive, Icons.point_of_sale, 'Caixa', ciclo.caixaNome),
                                                _buildInfoRow(adaptive, Icons.person, 'Aberto por', ciclo.usuarioAberturaNome),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _buildInfoRow(adaptive, Icons.calendar_today, 'Data/Hora', dataFormatada),
                                                _buildInfoRow(adaptive, Icons.account_balance_wallet, 'Valor Inicial', _formatCurrency(ciclo.valorInicial)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                    ],
                  ),
                ),
                              SizedBox(height: adaptive.isMobile ? 12 : 16),

                // Mensagem de erro
                if (_errorMessage != null) ...[
                  Container(
                                  padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.errorColor,
                                        size: adaptive.isMobile ? 20 : 24,
                        ),
                                      SizedBox(width: adaptive.isMobile ? 8 : 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                                          style: GoogleFonts.inter(
                                            fontSize: adaptive.isMobile ? 14 : 16,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                              SizedBox(height: adaptive.isMobile ? 12 : 16),
                ],

                // Título da seção de valores
                            Row(
                              children: [
                                Icon(Icons.calculate, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 6),
                Text(
                  'Valores Contados',
                                  style: GoogleFonts.inter(
                                    fontSize: adaptive.isMobile ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                              ],
                            ),
                              SizedBox(height: adaptive.isMobile ? 8 : 12),
                Text(
                  'Informe os valores contados para cada forma de pagamento',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 12 : 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                            SizedBox(height: adaptive.isMobile ? 12 : 16),

                              // Campos de valores - layout adaptativo
                              if (adaptive.isMobile)
                                Column(
                                  children: [
                _buildCampoValor(
                                      adaptive: adaptive,
                  label: 'Dinheiro',
                                      icon: Icons.money,
                                      color: const Color(0xFF4CAF50),
                  controller: _valorDinheiroController,
                                      valorApurado: ciclo.valorDinheiroEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                ),
                                    const SizedBox(height: 10),
                _buildCampoValor(
                                      adaptive: adaptive,
                  label: 'Cartão de Crédito',
                                      icon: Icons.credit_card,
                                      color: const Color(0xFF2196F3),
                  controller: _valorCartaoCreditoController,
                                      valorApurado: ciclo.valorCartaoCreditoEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                ),
                                    const SizedBox(height: 10),
                _buildCampoValor(
                                      adaptive: adaptive,
                  label: 'Cartão de Débito',
                                      icon: Icons.credit_card,
                                      color: const Color(0xFF9C27B0),
                  controller: _valorCartaoDebitoController,
                                      valorApurado: ciclo.valorCartaoDebitoEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                                    ),
                                    const SizedBox(height: 10),
                                    _buildCampoValor(
                                      adaptive: adaptive,
                                      label: 'PIX',
                                      icon: Icons.qr_code,
                                      color: const Color(0xFF32BCAD),
                                      controller: _valorPIXController,
                                      valorApurado: ciclo.valorPIXEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                ),
                                    const SizedBox(height: 10),
                _buildCampoValor(
                                      adaptive: adaptive,
                                      label: 'Outros',
                                      icon: Icons.more_horiz,
                                      color: const Color(0xFF757575),
                                      controller: _valorOutrosController,
                                      valorApurado: ciclo.valorOutrosEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                                    ),
                                  ],
                                )
                              else
                                // Layout em grid para telas maiores
                                Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildCampoValor(
                                            adaptive: adaptive,
                                            label: 'Dinheiro',
                                            icon: Icons.money,
                                            color: const Color(0xFF4CAF50),
                                            controller: _valorDinheiroController,
                                            valorApurado: ciclo.valorDinheiroEsperado,
                                            mostrarValorApurado: _exibirValoresApurados,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildCampoValor(
                                            adaptive: adaptive,
                                            label: 'Cartão de Crédito',
                                            icon: Icons.credit_card,
                                            color: const Color(0xFF2196F3),
                                            controller: _valorCartaoCreditoController,
                                            valorApurado: ciclo.valorCartaoCreditoEsperado,
                                            mostrarValorApurado: _exibirValoresApurados,
                                          ),
                                        ),
                                      ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildCampoValor(
                                    adaptive: adaptive,
                                    label: 'Cartão de Débito',
                                    icon: Icons.credit_card,
                                    color: const Color(0xFF9C27B0),
                                    controller: _valorCartaoDebitoController,
                                    valorApurado: ciclo.valorCartaoDebitoEsperado,
                                    mostrarValorApurado: _exibirValoresApurados,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildCampoValor(
                                    adaptive: adaptive,
                  label: 'PIX',
                                    icon: Icons.qr_code,
                                    color: const Color(0xFF32BCAD),
                  controller: _valorPIXController,
                                    valorApurado: ciclo.valorPIXEsperado,
                                    mostrarValorApurado: _exibirValoresApurados,
                                  ),
                                ),
                              ],
                ),
                            const SizedBox(height: 10),
                                    // Outros ocupa linha inteira
                _buildCampoValor(
                                      adaptive: adaptive,
                  label: 'Outros',
                                      icon: Icons.more_horiz,
                                      color: const Color(0xFF757575),
                  controller: _valorOutrosController,
                                      valorApurado: ciclo.valorOutrosEsperado,
                                      mostrarValorApurado: _exibirValoresApurados,
                                    ),
                                  ],
                ),
                              SizedBox(height: adaptive.isMobile ? 12 : 16),

                // Campo Observações
                              Row(
                                children: [
                                  Icon(Icons.note, color: AppTheme.primaryColor, size: 18),
                                  const SizedBox(width: 6),
                Text(
                  'Observações',
                                    style: GoogleFonts.inter(
                                      fontSize: adaptive.isMobile ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                                ],
                              ),
                              SizedBox(height: adaptive.isMobile ? 6 : 8),
                TextFormField(
                  controller: _observacoesController,
                                maxLines: adaptive.isMobile ? 2 : 3,
                  decoration: InputDecoration(
                    hintText: 'Observações sobre o fechamento (opcional)',
                                  prefixIcon: const Icon(Icons.note_outlined, size: 20),
                    border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: adaptive.isMobile ? 12 : 16,
                                    vertical: adaptive.isMobile ? 12 : 14,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: adaptive.isMobile ? 13 : 15,
                                ),
                              ),
                              SizedBox(height: adaptive.isMobile ? 12 : 16), // Espaço para rodapé fixo
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Rodapé fixo com resumo e botões
                Container(
                  padding: EdgeInsets.all(adaptive.isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Resumo compacto
                        _buildResumoCompacto(adaptive),
                        SizedBox(height: adaptive.isMobile ? 10 : 12),
                        // Botões
                        adaptive.isMobile
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _fecharCaixa,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.lock, size: 18),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Fechar Caixa',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.close, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Cancelar',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                  onPressed: _isSaving ? null : _fecharCaixa,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.lock, size: 18),
                                                const SizedBox(width: 6),
                                                Text(
                          'Fechar Caixa',
                                                  style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                          ),
                        ),
                ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        side: BorderSide(
                                          color: AppTheme.textSecondary.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.close, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                    'Cancelar',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildInfoRow(AdaptiveLayoutProvider adaptive, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.isMobile ? 8 : 12),
      child: Row(
        children: [
          Icon(icon, size: adaptive.isMobile ? 18 : 20, color: AppTheme.textSecondary),
          SizedBox(width: adaptive.isMobile ? 8 : 12),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 14 : 16,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
            value,
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
