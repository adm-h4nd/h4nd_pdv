import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/core/venda_service.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import '../../data/models/core/vendas/produto_nota_fiscal_dto.dart';
import '../../core/payment/payment_service.dart';
import '../../core/payment/payment_method_option.dart';
import '../../core/payment/payment_provider.dart';
import '../../core/events/app_event_bus.dart';

/// Provider para gerenciar operações de venda (pagamento e conclusão)
/// 
/// Responsabilidades:
/// - Processar pagamentos (via PaymentService + registrar no servidor)
/// - Finalizar vendas (concluir e emitir nota fiscal)
/// - Buscar vendas (por ID ou por comanda)
/// - Calcular valores (saldo restante, totais)
/// - Escutar eventos relacionados a vendas
class VendaProvider extends ChangeNotifier {
  final VendaService _vendaService;
  PaymentService? _paymentService;

  VendaProvider({
    required VendaService vendaService,
  }) : _vendaService = vendaService {
    _initializePaymentService();
    _setupEventBusListener();
  }

  // ========== ESTADO DE PAGAMENTO ==========
  
  bool _processandoPagamento = false;
  String? _erroPagamento;
  String? _vendaIdPagamentoAtual; // Venda sendo processada no momento

  // ========== ESTADO DE CONCLUSÃO ==========
  
  bool _finalizandoVenda = false;
  String? _erroFinalizacao;
  String? _vendaIdFinalizacaoAtual; // Venda sendo finalizada no momento

  // ========== GETTERS ==========
  
  bool get processandoPagamento => _processandoPagamento;
  bool get finalizandoVenda => _finalizandoVenda;
  String? get erroPagamento => _erroPagamento;
  String? get erroFinalizacao => _erroFinalizacao;
  String? get vendaIdPagamentoAtual => _vendaIdPagamentoAtual;
  String? get vendaIdFinalizacaoAtual => _vendaIdFinalizacaoAtual;

  // ========== INICIALIZAÇÃO ==========

  /// Inicializa o PaymentService
  Future<void> _initializePaymentService() async {
    try {
      _paymentService = await PaymentService.getInstance();
      debugPrint('✅ [VendaProvider] PaymentService inicializado');
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao inicializar PaymentService: $e');
    }
  }

  // ========== MÉTODOS DE PAGAMENTO ==========

  /// Processa um pagamento completo
  /// 
  /// Fluxo:
  /// 1. Processa pagamento via PaymentService (SDK, PIX, etc)
  /// 2. Registra pagamento no servidor
  /// 3. Verifica se saldo zerou
  /// 4. Dispara eventos apropriados
  /// 
  /// Retorna true se pagamento foi processado com sucesso
  Future<bool> processarPagamento({
    required String vendaId,
    required double valor,
    required PaymentMethodOption metodo,
    List<ProdutoNotaFiscalDto>? produtosNotaParcial,
    Map<String, dynamic>? additionalData,
    String? mesaId, // Opcional: evita buscar venda se já temos esses dados
    String? comandaId, // Opcional: evita buscar venda se já temos esses dados
  }) async {
    if (_processandoPagamento) {
      debugPrint('⚠️ [VendaProvider] Já existe um pagamento em processamento');
      return false;
    }

    _processandoPagamento = true;
    _erroPagamento = null;
    _vendaIdPagamentoAtual = vendaId;
    notifyListeners();

    try {
      debugPrint('💳 [VendaProvider] Iniciando processamento de pagamento: Venda=$vendaId, Valor=$valor, Método=${metodo.label}');

      // 1. Inicializa PaymentService se necessário
      if (_paymentService == null) {
        await _initializePaymentService();
        if (_paymentService == null) {
          throw Exception('PaymentService não disponível');
        }
      }

      // 2. Determina provider key e dados adicionais
      String providerKey = metodo.providerKey;
      Map<String, dynamic>? paymentAdditionalData = additionalData ?? {};

      if (metodo.type == PaymentType.cash) {
        paymentAdditionalData['valorRecebido'] = valor;
      } else if (metodo.type == PaymentType.pos) {
        paymentAdditionalData.putIfAbsent('tipoTransacao', () => 'credit');
        paymentAdditionalData.putIfAbsent('parcelas', () => 1);
        paymentAdditionalData.putIfAbsent('imprimirRecibo', () => false);
      }

      // 3. Processa pagamento via PaymentService
      final paymentResult = await _paymentService!.processPayment(
        providerKey: providerKey,
        amount: valor,
        vendaId: vendaId,
        additionalData: paymentAdditionalData,
      );

      if (!paymentResult.success) {
        _erroPagamento = paymentResult.errorMessage ?? 'Erro ao processar pagamento';
        notifyListeners();
        return false;
      }

      // 4. Registra pagamento no servidor
      final sucessoRegistro = await registrarPagamento(
        vendaId: vendaId,
        valor: valor,
        formaPagamento: metodo.label,
        tipoFormaPagamento: metodo.type == PaymentType.cash ? 1 : 2,
        bandeiraCartao: paymentResult.metadata?['cardBrand'] as String?,
        identificadorTransacao: paymentResult.transactionId,
        produtos: produtosNotaParcial?.map((p) => p.toJson()).toList(),
      );

      if (!sucessoRegistro) {
        _processandoPagamento = false;
        _vendaIdPagamentoAtual = null;
        notifyListeners();
        return false;
      }

      // 6. Busca venda atualizada para verificar saldo
      final vendaAtualizada = await buscarVenda(vendaId);
      final saldoZerou = vendaAtualizada?.saldoRestante ?? 0.0 <= 0.01;

      // 7. Dispara evento de pagamento processado
      // Usa mesaId/comandaId passados como parâmetro se disponíveis, senão busca da venda
      final mesaIdParaEvento = mesaId ?? vendaAtualizada?.mesaId;
      final comandaIdParaEvento = comandaId ?? vendaAtualizada?.comandaId;
      
      AppEventBus.instance.dispararPagamentoProcessado(
        vendaId: vendaId,
        valor: valor,
        mesaId: mesaIdParaEvento,
        comandaId: comandaIdParaEvento,
      );

      _processandoPagamento = false;
      _vendaIdPagamentoAtual = null;
      notifyListeners();

      debugPrint('✅ [VendaProvider] Pagamento processado com sucesso. Saldo zerou: $saldoZerou');

      return true;
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao processar pagamento: $e');
      _erroPagamento = 'Erro ao processar pagamento: ${e.toString()}';
      _processandoPagamento = false;
      _vendaIdPagamentoAtual = null;
      notifyListeners();
      return false;
    }
  }

  /// Registra um pagamento no servidor
  /// 
  /// Chamado após PaymentService processar o pagamento
  Future<bool> registrarPagamento({
    required String vendaId,
    required double valor,
    required String formaPagamento,
    required int tipoFormaPagamento,
    int numeroParcelas = 1,
    String? bandeiraCartao,
    String? identificadorTransacao,
    List<Map<String, dynamic>>? produtos, // Produtos para nota fiscal parcial
  }) async {
    try {
      debugPrint('📤 [VendaProvider] Registrando pagamento no servidor: Venda=$vendaId, Valor=$valor');

      final response = await _vendaService.registrarPagamento(
        vendaId: vendaId,
        valor: valor,
        formaPagamento: formaPagamento,
        tipoFormaPagamento: tipoFormaPagamento,
        numeroParcelas: numeroParcelas,
        bandeiraCartao: bandeiraCartao,
        identificadorTransacao: identificadorTransacao,
        produtos: produtos,
      );

      if (response.success) {
        debugPrint('✅ [VendaProvider] Pagamento registrado com sucesso: ${response.data?.id}');
        return true;
      } else {
        debugPrint('❌ [VendaProvider] Erro ao registrar pagamento: ${response.message}');
        _erroPagamento = response.message ?? 'Erro ao registrar pagamento';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao registrar pagamento: $e');
      _erroPagamento = 'Erro ao registrar pagamento: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verifica se pode processar pagamento
  bool podeProcessarPagamento(String vendaId) {
    return !_processandoPagamento && _vendaIdPagamentoAtual != vendaId;
  }

  // ========== MÉTODOS DE CONCLUSÃO ==========

  /// Finaliza uma venda (conclui e emite nota fiscal final)
  /// 
  /// Fluxo:
  /// 1. Valida se pode finalizar
  /// 2. Chama API para concluir venda
  /// 3. Dispara evento de venda finalizada
  /// 4. Retorna sucesso/erro
  /// 
  /// Retorna true se venda foi finalizada com sucesso
  Future<bool> finalizarVenda({
    required String vendaId,
    String? mesaId,
    String? comandaId,
  }) async {
    if (_finalizandoVenda) {
      debugPrint('⚠️ [VendaProvider] Já existe uma venda sendo finalizada');
      return false;
    }

    _finalizandoVenda = true;
    _erroFinalizacao = null;
    _vendaIdFinalizacaoAtual = vendaId;
    notifyListeners();

    try {
      debugPrint('📋 [VendaProvider] Finalizando venda: Venda=$vendaId');

      final response = await _vendaService.concluirVenda(vendaId);

      if (response.success && response.data != null) {
        debugPrint('✅ [VendaProvider] Venda finalizada com sucesso: $vendaId');

        // Dispara evento de venda finalizada
        AppEventBus.instance.dispararVendaFinalizada(
          vendaId: vendaId,
          mesaId: mesaId,
          comandaId: comandaId,
        );

        _finalizandoVenda = false;
        _vendaIdFinalizacaoAtual = null;
        notifyListeners();

        return true;
      } else {
        debugPrint('❌ [VendaProvider] Erro ao finalizar venda: ${response.message}');
        _erroFinalizacao = response.message ?? 'Erro ao finalizar venda';
        _finalizandoVenda = false;
        _vendaIdFinalizacaoAtual = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao finalizar venda: $e');
      _erroFinalizacao = 'Erro ao finalizar venda: ${e.toString()}';
      _finalizandoVenda = false;
      _vendaIdFinalizacaoAtual = null;
      notifyListeners();
      return false;
    }
  }

  /// Verifica se pode finalizar uma venda
  bool podeFinalizarVenda(VendaDto venda) {
    // Pode finalizar se saldo está zerado ou muito próximo de zero
    return venda.saldoRestante <= 0.01;
  }

  /// Verifica se está processando finalização
  bool estaFinalizando(String vendaId) {
    return _finalizandoVenda && _vendaIdFinalizacaoAtual == vendaId;
  }

  // ========== MÉTODOS AUXILIARES ==========

  /// Busca uma venda por ID
  Future<VendaDto?> buscarVenda(String vendaId) async {
    try {
      final response = await _vendaService.getVendaById(vendaId);
      if (response.success && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao buscar venda: $e');
      return null;
    }
  }

  /// Busca venda aberta por comanda
  Future<VendaDto?> buscarVendaAbertaPorComanda(String comandaId) async {
    try {
      final response = await _vendaService.getVendaAbertaPorComanda(comandaId);
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [VendaProvider] Erro ao buscar venda aberta: $e');
      return null;
    }
  }

  /// Calcula saldo restante de uma venda
  double calcularSaldoRestante(VendaDto venda) {
    return venda.saldoRestante;
  }

  /// Verifica se saldo está zerado
  bool saldoZerado(VendaDto venda) {
    return venda.saldoRestante <= 0.01;
  }

  // ========== EVENTOS ==========

  /// Configura listeners de eventos
  void _setupEventBusListener() {
    final eventBus = AppEventBus.instance;

    // Escuta eventos de pagamento processado
    eventBus.on(TipoEvento.pagamentoProcessado).listen((evento) {
      debugPrint('📢 [VendaProvider] Evento: Pagamento processado para venda ${evento.vendaId}');
      // Limpa estado de erro se pagamento foi processado externamente
      if (_vendaIdPagamentoAtual == evento.vendaId) {
        _erroPagamento = null;
        notifyListeners();
      }
    });

    // Escuta eventos de venda finalizada
    eventBus.on(TipoEvento.vendaFinalizada).listen((evento) {
      debugPrint('📢 [VendaProvider] Evento: Venda ${evento.vendaId} finalizada');
      // Limpa estado se venda foi finalizada externamente
      if (_vendaIdFinalizacaoAtual == evento.vendaId) {
        _finalizandoVenda = false;
        _vendaIdFinalizacaoAtual = null;
        _erroFinalizacao = null;
        notifyListeners();
      }
    });
  }

  // ========== LIMPEZA ==========

  /// Limpa erros de pagamento
  void limparErroPagamento() {
    _erroPagamento = null;
    notifyListeners();
  }

  /// Limpa erros de finalização
  void limparErroFinalizacao() {
    _erroFinalizacao = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Limpa recursos se necessário
    super.dispose();
  }
}
