import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/payment/payment_service.dart';
import '../../core/payment/payment_method_option.dart';
import '../../core/payment/payment_provider.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/vendas/produto_nota_fiscal_dto.dart';
import '../../data/services/core/venda_service.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/events/app_event_bus.dart';

/// Tela de pagamento específica para restaurante (mesas/comandas)
/// Permite selecionar produtos para pagar com nota fiscal ou fazer pagamento de reserva
class PagamentoRestauranteScreen extends StatefulWidget {
  final VendaDto venda;
  final List<ProdutoAgrupado> produtosAgrupados;
  /// Callback chamado quando um pagamento é processado com sucesso (mesmo que parcial)
  final VoidCallback? onPagamentoProcessado;
  /// Callback chamado quando a venda é concluída/finalizada
  final VoidCallback? onVendaConcluida;
  final bool isModal; // Indica se deve ser exibido como modal

  const PagamentoRestauranteScreen({
    super.key,
    required this.venda,
    required this.produtosAgrupados,
    this.onPagamentoProcessado,
    this.onVendaConcluida,
    this.isModal = false,
  });

  /// Mostra o pagamento de forma adaptativa:
  /// - Mobile: Tela cheia (Navigator.push)
  /// - Desktop/Tablet: Modal (showDialog)
  static Future<bool?> show(
    BuildContext context, {
    required VendaDto venda,
    required List<ProdutoAgrupado> produtosAgrupados,
    VoidCallback? onPagamentoProcessado,
    VoidCallback? onVendaConcluida,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    
    // Mobile: usa tela cheia
    if (adaptive?.isMobile ?? true) {
      return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: PagamentoRestauranteScreen(
              venda: venda,
              produtosAgrupados: produtosAgrupados,
              onPagamentoProcessado: onPagamentoProcessado,
              onVendaConcluida: onVendaConcluida,
              isModal: false,
            ),
          ),
        ),
      );
    }
    
    // Desktop/Tablet: usa modal
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveLayout(
        child: PagamentoRestauranteScreen(
          venda: venda,
          produtosAgrupados: produtosAgrupados,
          onPagamentoProcessado: onPagamentoProcessado,
          onVendaConcluida: onVendaConcluida,
          isModal: true,
        ),
      ),
    );
  }

  @override
  State<PagamentoRestauranteScreen> createState() => _PagamentoRestauranteScreenState();
}

class _PagamentoRestauranteScreenState extends State<PagamentoRestauranteScreen> {
  PaymentService? _paymentService;
  List<PaymentMethodOption> _paymentMethods = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  PaymentMethodOption? _selectedMethod;
  final TextEditingController _valorController = TextEditingController();
  
  // Emitir nota parcial: se true, permite selecionar produtos para pagamento parcial com nota fiscal
  bool _emitirNotaParcial = false;
  
  // Produtos selecionados para pagamento (quando emitirNotaParcial = true)
  final Map<String, double> _produtosSelecionados = {}; // produtoId -> quantidade selecionada
  
  // Venda atualizada (para refletir mudanças após pagamentos)
  VendaDto? _vendaAtualizada;

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
      _paymentMethods = _paymentService!.getAvailablePaymentMethods();
      
      if (_paymentMethods.isNotEmpty) {
        _selectedMethod = _paymentMethods.first;
      }
    } catch (e) {
      AppToast.showError(context, 'Erro ao inicializar pagamento: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Usa venda atualizada se disponível, senão usa a venda original
  VendaDto get _vendaAtual => _vendaAtualizada ?? widget.venda;
  
  double get _valorTotal => _vendaAtual.valorTotal;
  double get _totalPago => _vendaAtual.totalPago;
  double get _saldoRestante => _vendaAtual.saldoRestante;

  double? get _valorDigitado {
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    return valor;
  }

  /// Calcula o valor total dos produtos selecionados
  double _calcularValorProdutosSelecionados() {
    double total = 0.0;
    for (final produto in widget.produtosAgrupados) {
      final quantidadeSelecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
      if (quantidadeSelecionada > 0) {
        total += produto.precoUnitario * quantidadeSelecionada;
      }
    }
    return total;
  }

  /// Verifica se há produtos selecionados
  bool get _temProdutosSelecionados {
    return _produtosSelecionados.values.any((qtd) => qtd > 0);
  }

  /// Quantidade disponível de um produto (quantidade total - já selecionada)
  double _quantidadeDisponivel(ProdutoAgrupado produto) {
    final selecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
    return produto.quantidadeTotal - selecionada;
  }

  /// Seleciona/deseleciona quantidade de um produto
  void _selecionarProduto(ProdutoAgrupado produto, double quantidade) {
    setState(() {
      if (quantidade <= 0) {
        _produtosSelecionados.remove(produto.produtoId);
      } else {
        final maxQuantidade = produto.quantidadeTotal.toDouble();
        _produtosSelecionados[produto.produtoId] = quantidade > maxQuantidade ? maxQuantidade : quantidade;
      }
      
      // Atualiza valor do campo se emitir nota parcial estiver marcado
      if (_emitirNotaParcial) {
        final valorProdutos = _calcularValorProdutosSelecionados();
        if (valorProdutos > 0) {
          _valorController.text = valorProdutos.toStringAsFixed(2);
        } else {
          _valorController.text = _saldoRestante.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> _processarPagamento() async {
    if (_selectedMethod == null) {
      AppToast.showError(context, 'Selecione uma forma de pagamento');
      return;
    }

    // Validação baseada na opção de emitir nota parcial
    if (_emitirNotaParcial) {
      // Modo nota parcial: deve ter produtos selecionados
      if (!_temProdutosSelecionados) {
        AppToast.showError(context, 'Selecione pelo menos um produto para pagar');
        return;
      }
      
      final valorProdutos = _calcularValorProdutosSelecionados();
      final valor = _valorDigitado ?? valorProdutos;
      
      if (valor <= 0) {
        AppToast.showError(context, 'Digite um valor válido');
        return;
      }
      
      // Valida se o valor digitado corresponde ao valor dos produtos selecionados
      if ((valor - valorProdutos).abs() > 0.01) {
        final confirm = await AppDialog.showConfirm(
          context: context,
          title: 'Valor diferente dos produtos',
          message: 'O valor digitado (R\$ ${valor.toStringAsFixed(2)}) é diferente do valor dos produtos selecionados (R\$ ${valorProdutos.toStringAsFixed(2)}). Deseja continuar?',
        );
        if (confirm != true) return;
      }
    } else {
      // Modo normal: apenas valida valor
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
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final valor = _valorDigitado ?? _calcularValorProdutosSelecionados();
      
      // Determina provider key e dados adicionais baseado no método selecionado
      String providerKey = _selectedMethod!.providerKey ?? 'cash';
      Map<String, dynamic>? additionalData;

      if (_selectedMethod!.type == PaymentType.cash) {
        providerKey = 'cash';
        additionalData = {
          'valorRecebido': valor,
        };
      } else if (_selectedMethod!.type == PaymentType.pos) {
        providerKey = _selectedMethod!.providerKey ?? 'cash';
        // Determina tipo de transação baseado no label do método selecionado
        final tipoTransacao = _selectedMethod!.label.toLowerCase().contains('débito') || 
                             _selectedMethod!.label.toLowerCase().contains('debito')
            ? 'debit'
            : 'credit';
        additionalData = {
          'tipoTransacao': tipoTransacao,
          'parcelas': 1,
          'imprimirRecibo': false,
        };
      } else {
        providerKey = 'cash';
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
        Navigator.of(context).pop();
      }

      if (result.success) {
        // Prepara lista de produtos para nota fiscal (se emitir nota parcial)
        List<Map<String, dynamic>>? produtosParaNota;
        if (_emitirNotaParcial && _temProdutosSelecionados) {
          produtosParaNota = _produtosSelecionados.entries
              .where((e) => e.value > 0)
              .map((e) => ProdutoNotaFiscalDto(
                    produtoId: e.key,
                    quantidade: e.value,
                  ).toJson())
              .toList();
        }

        // Registra pagamento imediatamente (cash e POS sempre registram imediatamente)
        if (_selectedMethod!.type == PaymentType.cash || 
            _selectedMethod!.type == PaymentType.pos ||
            !(result.metadata?['pending'] == true)) {
          // Determina tipo de forma de pagamento baseado apenas no PaymentType e label
          final tipoFormaPagamento = _determinarTipoFormaPagamento(_selectedMethod!);
          
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
            formaPagamento: _selectedMethod!.label,
            tipoFormaPagamento: tipoFormaPagamento,
            bandeiraCartao: bandeiraCartao,
            identificadorTransacao: identificadorTransacao,
            produtos: produtosParaNota, // Passa produtos se houver
            transactionData: result.transactionData, // Dados padronizados da transação
          );
          
          if (response.success) {
            AppToast.showSuccess(context, 'Pagamento realizado com sucesso!');
            
            // Dispara evento de pagamento processado
            // O provider reage ao evento e atualiza localmente (sem ir no servidor)
            AppEventBus.instance.dispararPagamentoProcessado(
              vendaId: widget.venda.id,
              valor: valor,
              mesaId: widget.venda.mesaId,
              comandaId: widget.venda.comandaId,
            );
            
            // Limpa seleção de produtos
            _produtosSelecionados.clear();
            
            // Chama onPagamentoProcessado quando um pagamento é processado (mesmo que parcial)
            // Isso permite que o chamador saiba que houve um pagamento e pode reagir
            if (widget.onPagamentoProcessado != null) {
              widget.onPagamentoProcessado!();
            }
            
            // Busca venda atualizada do servidor para refletir o novo pagamento
            // Isso garante que temos os dados corretos (incluindo o pagamento recém-criado)
            final vendaResponse = await _vendaService.getVendaById(widget.venda.id);
            
            if (vendaResponse.success && vendaResponse.data != null) {
              setState(() {
                _vendaAtualizada = vendaResponse.data!;
                _valorController.text = _saldoRestante > 0.01 
                    ? _saldoRestante.toStringAsFixed(2) 
                    : '0.00';
              });
              
              // Se saldo zerou, a UI será atualizada automaticamente para mostrar botão "Concluir Venda"
              // Não fecha a tela - deixa o usuário escolher se quer concluir
              if (_saldoRestante > 0.01) {
                // Ainda há saldo - fecha tela para permitir novo pagamento
                Navigator.of(context).pop(true);
              }
              // Se saldo zerou, mantém a tela aberta mostrando o botão "Concluir Venda"
            } else {
              // Se não conseguir buscar venda atualizada, calcula localmente
              final saldoAnterior = widget.venda.saldoRestante;
              final novoSaldo = saldoAnterior - valor;
              
              if (novoSaldo <= 0.01) {
                // Saldo zerou - oferece conclusão (fallback)
                _oferecerConclusaoVenda();
              } else {
                Navigator.of(context).pop(true);
              }
            }
          } else {
            AppToast.showError(context, 'Erro ao registrar pagamento no servidor');
          }
        }
      } else {
        // Fecha diálogo se estiver aberto (para qualquer tipo POS)
        if (_selectedMethod!.type == PaymentType.pos && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        AppToast.showError(context, result.errorMessage ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      AppToast.showError(context, 'Erro ao processar pagamento: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Determina o tipo de forma de pagamento baseado apenas no PaymentType e label
  /// Não depende de provider específico
  int _determinarTipoFormaPagamento(PaymentMethodOption method) {
    switch (method.type) {
      case PaymentType.cash:
        return 1; // Dinheiro
      case PaymentType.pos:
        // Para POS, verifica se é débito ou crédito baseado no label
        final isDebito = method.label.toLowerCase().contains('débito') || 
                        method.label.toLowerCase().contains('debito');
        return isDebito ? 3 : 2; // 3 = Débito, 2 = Crédito
      case PaymentType.tef:
        return 2; // Cartão (padrão)
    }
  }

  /// Oferece opção de concluir venda quando saldo zerar
  Future<void> _oferecerConclusaoVenda() async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Concluir Venda',
      message: 'O saldo foi totalmente pago. Deseja concluir a venda e emitir a nota fiscal final?',
      confirmText: 'Concluir',
      cancelText: 'Depois',
      icon: Icons.check_circle_outline,
      iconColor: AppTheme.primaryColor,
      confirmColor: AppTheme.primaryColor,
    );

    if (confirm == true) {
      await _concluirVenda();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// Conclui a venda (emite nota fiscal final)
  Future<void> _concluirVenda() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await _vendaService.concluirVenda(widget.venda.id);

      if (response.success) {
        AppToast.showSuccess(context, 'Venda concluída com sucesso!');
        
        // Dispara evento de venda finalizada
        if (widget.venda.mesaId != null) {
          AppEventBus.instance.dispararVendaFinalizada(
            vendaId: widget.venda.id,
            mesaId: widget.venda.mesaId!,
            comandaId: widget.venda.comandaId,
          );
        }
        
        // Chama onVendaConcluida quando a venda é realmente concluída/finalizada
        // Isso é diferente de onPagamentoProcessado que é chamado a cada pagamento
        if (widget.onVendaConcluida != null) {
          widget.onVendaConcluida!();
        }
        
        Navigator.of(context).pop(true);
      } else {
        AppToast.showError(context, response.message ?? 'Erro ao concluir venda');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro ao concluir venda: $e');
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Text(
                    'Aguardando Cartão',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aproxime ou insira o cartão no leitor',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
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

    // Conteúdo comum (reutilizado em ambos os modos)
    Widget buildContent() {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      
      final saldoZero = _saldoRestante <= 0.01;
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resumo da venda
          _buildResumoVenda(adaptive),
          
          // Opção de emitir nota parcial (apenas se houver saldo)
          if (!saldoZero)
            _buildOpcaoNotaParcial(adaptive),
          
          // Lista de produtos (se emitir nota parcial estiver marcado)
          if (!saldoZero && _emitirNotaParcial)
            widget.isModal
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: _buildListaProdutos(adaptive),
                  )
                : Expanded(
                    child: _buildListaProdutos(adaptive),
                  ),
          
          // Formulário de pagamento
          _buildFormularioPagamento(adaptive),
        ],
      );
    }

    // Modal: usa Dialog
    if (widget.isModal) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: adaptive.isDesktop ? 100 : 50,
          vertical: adaptive.isDesktop ? 40 : 20,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: adaptive.isDesktop ? 800 : 600,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header do modal
              Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    SizedBox(width: adaptive.isMobile ? 12 : 16),
                    Expanded(
                      child: Text(
                        'Pagamento',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              // Conteúdo com scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                  child: buildContent(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tela cheia: usa Scaffold (mobile)
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
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: buildContent(),
      ),
    );
  }

  Widget _buildResumoVenda(AdaptiveLayoutProvider adaptive) {
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, padding, padding, 0),
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: adaptive.isMobile ? 18 : 22,
        ),
        child: Row(
          children: [
            // Total da Venda
            Expanded(
              child: _buildResumoItem(
                label: 'Total',
                valor: _valorTotal,
                color: AppTheme.textPrimary,
                icon: Icons.receipt_long,
                adaptive: adaptive,
              ),
            ),
            // Divisor vertical
            _buildDivider(),
            // Total Pago
            Expanded(
              child: _buildResumoItem(
                label: 'Pago',
                valor: _totalPago,
                color: AppTheme.successColor,
                icon: Icons.check_circle,
                adaptive: adaptive,
              ),
            ),
            // Divisor vertical
            _buildDivider(),
            // Saldo Restante
            Expanded(
              child: _buildResumoItem(
                label: 'Saldo',
                valor: _saldoRestante,
                color: _saldoRestante > 0 ? AppTheme.errorColor : AppTheme.successColor,
                icon: _saldoRestante > 0 ? Icons.pending : Icons.check_circle_outline,
                adaptive: adaptive,
                isHighlight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey.shade200,
    );
  }

  Widget _buildResumoItem({
    required String label,
    required double valor,
    required Color color,
    required IconData icon,
    required AdaptiveLayoutProvider adaptive,
    bool isHighlight = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: isHighlight ? 19 : 17,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOpcaoNotaParcial(AdaptiveLayoutProvider adaptive) {
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _emitirNotaParcial ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade200,
          width: _emitirNotaParcial ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _emitirNotaParcial = !_emitirNotaParcial;
            if (!_emitirNotaParcial) {
              // Limpa seleção de produtos ao desmarcar
              _produtosSelecionados.clear();
              _valorController.text = _saldoRestante.toStringAsFixed(2);
            } else {
              // Atualiza valor baseado nos produtos selecionados (se houver)
              final valorProdutos = _calcularValorProdutosSelecionados();
              if (valorProdutos > 0) {
                _valorController.text = valorProdutos.toStringAsFixed(2);
              }
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Checkbox customizado
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _emitirNotaParcial ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: _emitirNotaParcial ? AppTheme.primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _emitirNotaParcial
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Texto e descrição
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emitir Nota Parcial',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagamento parcial com emissão de notas fiscais. Será necessário marcar os produtos que serão pagos.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaProdutos(AdaptiveLayoutProvider adaptive) {
    if (widget.produtosAgrupados.isEmpty) {
      return Center(
        child: Text(
          'Nenhum produto disponível',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(padding, 12, padding, padding),
      itemCount: widget.produtosAgrupados.length,
      itemBuilder: (context, index) {
        final produto = widget.produtosAgrupados[index];
        final quantidadeSelecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
        final quantidadeDisponivel = _quantidadeDisponivel(produto);
        
        return _buildProdutoCard(produto, quantidadeSelecionada, quantidadeDisponivel, adaptive);
      },
    );
  }

  Widget _buildProdutoCard(
    ProdutoAgrupado produto,
    double quantidadeSelecionada,
    double quantidadeDisponivel,
    AdaptiveLayoutProvider adaptive,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: quantidadeSelecionada > 0
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.produtoNome,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (produto.produtoVariacaoNome != null && produto.produtoVariacaoNome!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        produto.produtoVariacaoNome!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${produto.precoUnitario.toStringAsFixed(2)} cada',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Disponível: ${produto.quantidadeTotal.toInt()}x',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (quantidadeSelecionada > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Selecionado: ${quantidadeSelecionada.toInt()}x',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: quantidadeSelecionada > 0
                      ? () => _selecionarProduto(produto, quantidadeSelecionada - 1)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Menos'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quantidadeSelecionada.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: quantidadeDisponivel > 0
                      ? () => _selecionarProduto(produto, quantidadeSelecionada + 1)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Mais'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPagamento(AdaptiveLayoutProvider adaptive) {
    final valorProdutos = _emitirNotaParcial ? _calcularValorProdutosSelecionados() : 0.0;
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    final saldoZero = _saldoRestante <= 0.01;
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, 12, padding, padding),
      padding: EdgeInsets.all(padding),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Se saldo é zero, mostra mensagem e botão de concluir
          if (saldoZero) ...[
            Container(
              padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.successColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saldo Totalmente Pago',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos os pagamentos foram realizados. Conclua a venda para finalizar.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _concluirVenda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Concluir Venda',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Valor dos produtos selecionados (se emitir nota parcial)
            if (_emitirNotaParcial && _temProdutosSelecionados) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Valor Selecionado',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'R\$ ${valorProdutos.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            
            // Campo de valor
            TextField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor do Pagamento',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 16 : 20,
                  vertical: adaptive.isMobile ? 16 : 18,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 15 : 16,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            
            const SizedBox(height: 16),
            
            // Métodos de pagamento
            if (_paymentMethods.isNotEmpty) ...[
              Text(
                'Forma de Pagamento',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // Métodos de pagamento com scroll horizontal para não ultrapassar a tela
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = _paymentMethods[index];
                    final isSelected = _selectedMethod == method;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(method.icon, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              method.label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedMethod = method;
                          });
                        },
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 12),
            
            // Botão de pagar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processarPagamento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: adaptive.isMobile ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        'Pagar',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
