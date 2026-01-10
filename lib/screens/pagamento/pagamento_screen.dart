import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/payment/payment_service.dart';
import '../../core/payment/payment_method_option.dart';
import '../../core/payment/payment_provider.dart';
import '../../data/models/core/caixa/tipo_forma_pagamento.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/services/core/venda_service.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';

/// Tela de pagamento de venda
class PagamentoScreen extends StatefulWidget {
  final VendaDto venda;
  final VoidCallback? onPaymentSuccess;

  const PagamentoScreen({
    super.key,
    required this.venda,
    this.onPaymentSuccess,
  });

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  PaymentService? _paymentService;
  List<PaymentMethodOption> _paymentMethods = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  PaymentMethodOption? _selectedMethod;
  final TextEditingController _valorController = TextEditingController();

  VendaService get _vendaService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.vendaService;
  }

  @override
  void initState() {
    super.initState();
    _initializePayment();
    _valorController.text = widget.venda.saldoRestante.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _paymentService = await PaymentService.getInstance();
      
      // Obtém serviços necessários
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final formaPagamentoService = servicesProvider.formaPagamentoService;
      final authService = servicesProvider.authService;
      
      // Busca formas de pagamento do backend
      _paymentMethods = await _paymentService!.getAvailablePaymentMethods(
        formaPagamentoService: formaPagamentoService,
        authService: authService,
      );
      
      if (_paymentMethods.isNotEmpty) {
        _selectedMethod = _paymentMethods.first;
      }
    } catch (e) {
      debugPrint('❌ Erro ao inicializar pagamento: $e');
      AppToast.showError(context, 'Erro ao carregar formas de pagamento: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _valorTotal => widget.venda.valorTotal;
  double get _totalPago => widget.venda.totalPago;
  double get _saldoRestante => widget.venda.saldoRestante;

  double? get _valorDigitado {
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    return valor;
  }

  Future<void> _processarPagamento() async {
    if (_selectedMethod == null) {
      AppToast.showError(context, 'Selecione uma forma de pagamento');
      return;
    }

    final valor = _valorDigitado;
    if (valor == null || valor <= 0) {
      AppToast.showError(context, 'Digite um valor válido');
      return;
    }

    if (valor > _saldoRestante) {
      final confirm = await AppDialog.showConfirm(
        context: context,
        title: 'Valor maior que o saldo',
        message: 'O valor digitado (R\$ ${valor.toStringAsFixed(2)}) é maior que o saldo restante (R\$ ${_saldoRestante.toStringAsFixed(2)}). Deseja continuar?',
      );
      if (confirm != true) return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Determina provider key e dados adicionais baseado no método selecionado
      String providerKey = _selectedMethod!.providerKey;
      Map<String, dynamic>? additionalData;

      // Verifica se é pagamento manual (providerKey começa com "manual_")
      final isManual = providerKey.startsWith('manual_');
      
      if (_selectedMethod!.type == PaymentType.cash || 
          (isManual && _selectedMethod!.tipoFormaPagamento == TipoFormaPagamento.dinheiro)) {
        // Dinheiro (cash ou manual dinheiro)
        providerKey = 'cash';
        additionalData = {
          'valorRecebido': valor,
        };
      } else if (_selectedMethod!.type == PaymentType.pos && !isManual) {
        // POS integrado (SDK)
        providerKey = _selectedMethod!.providerKey;
        // Determina tipo de transação baseado no tipo de forma de pagamento
        final isDebito = _selectedMethod!.tipoFormaPagamento == TipoFormaPagamento.cartaoDebito;
        additionalData = {
          'tipoTransacao': isDebito ? 'debit' : 'credit',
          'parcelas': 1,
          'imprimirRecibo': false,
        };
      } else if (isManual) {
        // Pagamento manual não integrado (cartão, PIX, etc.)
        // Não precisa de additionalData especial, apenas processa
        providerKey = _selectedMethod!.providerKey;
        additionalData = {};
      } else {
        // Fallback: usa providerKey do método
        providerKey = _selectedMethod!.providerKey;
        additionalData = {};
      }

      // Se for pagamento via POS (SDK), mostra diálogo informativo
      if (_selectedMethod!.type == PaymentType.pos) {
        _mostrarDialogAguardandoCartao(context);
      }

      final result = await _paymentService!.processPayment(
        providerKey: providerKey,
        amount: valor,
        vendaId: widget.venda.id,
        additionalData: additionalData,
      );

      // Fecha o diálogo se estiver aberto (para qualquer tipo POS)
      if (_selectedMethod!.type == PaymentType.pos && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Fecha o diálogo de aguardando cartão
      }

      if (result.success) {
        // Registra pagamento imediatamente (cash e POS sempre registram imediatamente)
        if (_selectedMethod!.type == PaymentType.cash || 
            _selectedMethod!.type == PaymentType.pos ||
            !(result.metadata?['pending'] == true)) {
          // Usa o TipoFormaPagamento do backend (vem do PaymentMethodOption)
          final tipoFormaPagamento = _selectedMethod!.tipoFormaPagamento.toValue();
          
          // Extrai dados de transação do resultado padronizado
          String? bandeiraCartao;
          String? identificadorTransacao;
          
          if (result.transactionData != null) {
            final txData = result.transactionData!;
            bandeiraCartao = txData.cardBrandName ?? txData.cardBrand;
            identificadorTransacao = txData.initiatorTransactionKey ?? 
                                    txData.transactionReference ?? 
                                    result.transactionId;
          } else if (result.transactionId != null) {
            // Fallback: usa transactionId se não houver transactionData
            identificadorTransacao = result.transactionId;
          }
          
          final response = await _vendaService.registrarPagamento(
            vendaId: widget.venda.id,
            valor: valor,
            formaPagamentoId: _selectedMethod!.formaPagamentoId, // 🆕 ID da forma de pagamento
            tipoFormaPagamento: tipoFormaPagamento,
            bandeiraCartao: bandeiraCartao,
            identificadorTransacao: identificadorTransacao,
            transactionData: result.transactionData, // Dados padronizados da transação
          );
          
          if (response.success) {
            AppToast.showSuccess(context, 'Pagamento realizado com sucesso!');
            
            if (widget.onPaymentSuccess != null) {
              widget.onPaymentSuccess!();
            }
            
            Navigator.of(context).pop(true);
          } else {
            AppToast.showError(context, response.message ?? 'Erro ao registrar pagamento no servidor');
          }
        }
      } else {
        // Fecha o diálogo se houver erro (para qualquer tipo POS)
        if (_selectedMethod!.type == PaymentType.pos && Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Fecha o diálogo de aguardando cartão
        }
        AppToast.showError(context, result.errorMessage ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      // Fecha o diálogo se houver exceção
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Fecha o diálogo de aguardando cartão se estiver aberto
      }
      AppToast.showError(context, 'Erro ao processar pagamento: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  /// Mostra diálogo informativo para pagamento via SDK
  void _mostrarDialogAguardandoCartao(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Não permite fechar clicando fora
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Não permite voltar enquanto processa
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone de cartão
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Título
                  Text(
                    'Aguardando Cartão',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Instruções
                  Text(
                    'Por favor, insira ou aproxime o cartão no dispositivo POS.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Siga as instruções na tela do dispositivo.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Indicador de carregamento
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          'Pagamento',
          style: GoogleFonts.inter(
            fontSize: adaptive.isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Resumo da venda
                  _buildResumoVenda(adaptive),
                  const SizedBox(height: 24),
                  
                  // Valor do pagamento
                  _buildValorPagamento(adaptive),
                  const SizedBox(height: 24),
                  
                  // Formas de pagamento
                  _buildFormasPagamento(adaptive),
                  const SizedBox(height: 32),
                  
                  // Botão de pagar
                  _buildBotaoPagar(adaptive),
                ],
              ),
            ),
    );
  }

  Widget _buildResumoVenda(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumo da Venda',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildResumoItem('Total', _valorTotal, AppTheme.textPrimary),
          const SizedBox(height: 8),
          _buildResumoItem('Total Pago', _totalPago, AppTheme.successColor),
          const Divider(height: 24),
          _buildResumoItem('Saldo Restante', _saldoRestante, AppTheme.primaryColor, isBold: true),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, double valor, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildValorPagamento(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Valor do Pagamento',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valorController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildValorRapido('Total', _valorTotal),
              _buildValorRapido('Saldo', _saldoRestante),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValorRapido(String label, double valor) {
    return OutlinedButton(
      onPressed: () {
        _valorController.text = valor.toStringAsFixed(2);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: R\$ ${valor.toStringAsFixed(2)}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildFormasPagamento(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Forma de Pagamento',
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_paymentMethods.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nenhuma forma de pagamento disponível',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._paymentMethods.map((method) => _buildMetodoPagamento(method, adaptive)),
        ],
      ),
    );
  }

  Widget _buildMetodoPagamento(PaymentMethodOption method, AdaptiveLayoutProvider adaptive) {
    final isSelected = _selectedMethod?.type == method.type && 
                       _selectedMethod?.providerKey == method.providerKey;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              method.icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method.label,
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 15 : 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoPagar(AdaptiveLayoutProvider adaptive) {
    final valor = _valorDigitado ?? 0;
    final canPay = _selectedMethod != null && valor > 0 && !_isProcessing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canPay ? _processarPagamento : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: adaptive.isMobile ? 16 : 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
          ),
          elevation: 2,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Pagar R\$ ${valor.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

