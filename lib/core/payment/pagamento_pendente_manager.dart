import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/local/pagamento_pendente_local.dart';
import '../../data/repositories/pagamento_pendente_repository.dart';
import '../../data/services/core/venda_service.dart';
import 'pagamento_pendente_service.dart';
import '../widgets/pagamento_pendente_dialog.dart';
import 'payment_service.dart';
import '../../screens/mesas/detalhes_produtos_mesa_screen.dart';
import '../../models/mesas/entidade_produtos.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';

/// Gerenciador global de pagamentos pendentes
/// 
/// Responsável por:
/// - Salvar pagamentos pendentes quando receber callback
/// - Mostrar dialog bloqueante quando necessário
/// - Verificar pagamentos pendentes ao iniciar app
class PagamentoPendenteManager {
  static PagamentoPendenteManager? _instance;
  static PagamentoPendenteManager get instance => _instance ??= PagamentoPendenteManager._();
  
  PagamentoPendenteManager._();
  
  PagamentoPendenteService? _service;
  GlobalKey<NavigatorState>? _navigatorKey;
  VendaService? _vendaService;
  MesaService? _mesaService;
  ComandaService? _comandaService;
  bool _isProcessing = false;
  
  /// Configura o serviço e navigator key
  void initialize({
    required PagamentoPendenteService service,
    required GlobalKey<NavigatorState> navigatorKey,
    VendaService? vendaService,
    MesaService? mesaService,
    ComandaService? comandaService,
  }) {
    _service = service;
    _navigatorKey = navigatorKey;
    _vendaService = vendaService;
    _mesaService = mesaService;
    _comandaService = comandaService;
    debugPrint('✅ PagamentoPendenteManager inicializado');
  }
  
  /// Verifica se está inicializado
  bool get isInitialized => _service != null && _navigatorKey != null;
  
  /// Processa um pagamento aprovado
  /// 
  /// Salva localmente e abre dialog bloqueante para registrar
  Future<void> processarPagamentoAprovado({
    required String vendaId,
    required double valor,
    required String? paymentType,
    String? brand,
    int? installments,
    String? transactionId,
  }) async {
    if (!isInitialized) {
      debugPrint('⚠️ PagamentoPendenteManager não inicializado');
      return;
    }
    
    if (_isProcessing) {
      debugPrint('⚠️ Já existe um pagamento sendo processado');
      return;
    }
    
    _isProcessing = true;
    
    try {
      // Converte tipo de pagamento para formato do backend
      final formaPagamento = _formatPaymentType(paymentType, brand);
      final tipoFormaPagamento = _getTipoFormaPagamento(paymentType, brand);
      
      // Salva localmente
      final pagamento = await _service!.salvarPagamentoPendente(
        vendaId: vendaId,
        valor: valor,
        formaPagamento: formaPagamento,
        tipoFormaPagamento: tipoFormaPagamento,
        numeroParcelas: installments ?? 1,
        bandeiraCartao: brand,
        identificadorTransacao: transactionId,
      );
      
      debugPrint('💾 Pagamento pendente salvo: ${pagamento.id}');
      
      // Aguarda um pouco para garantir que o app está pronto
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Abre dialog bloqueante
      await _mostrarDialogRegistro(pagamento);
    } catch (e) {
      debugPrint('❌ Erro ao processar pagamento aprovado: $e');
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Mostra dialog bloqueante para registro de pagamento
  Future<void> _mostrarDialogRegistro(PagamentoPendenteLocal pagamento) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('⚠️ Context não disponível para mostrar dialog');
      return;
    }
    
    await PagamentoPendenteDialog.show(
      context: context,
      pagamento: pagamento,
      onTentarRegistrar: () => _service!.tentarRegistrarPagamento(pagamento),
      onCancelar: () => _service!.cancelarPagamento(pagamento.id),
      onSucesso: () => _navegarParaTelaOrigem(pagamento.vendaId),
    );
  }
  
  /// Navega de volta para a tela de origem (mesa ou comanda) após sucesso
  Future<void> _navegarParaTelaOrigem(String vendaId) async {
    if (_vendaService == null) {
      debugPrint('⚠️ VendaService não disponível para navegação');
      return;
    }
    
    try {
      // Busca a venda para obter mesaId/comandaId
      final response = await _vendaService!.getVendaById(vendaId);
      
      if (response.success && response.data != null) {
        final venda = response.data!;
        final navigator = _navigatorKey?.currentState;
        
        if (navigator == null) {
          debugPrint('⚠️ Navigator não disponível');
          return;
        }
        
        // Navega para a tela de detalhes da mesa ou comanda
        if (venda.mesaId != null) {
          debugPrint('📍 Navegando para detalhes da mesa: ${venda.mesaId}');
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => AdaptiveLayout(
                child: DetalhesProdutosMesaScreen(
                  entidade: MesaComandaInfo(
                    id: venda.mesaId!,
                    tipo: TipoEntidade.mesa,
                    numero: venda.mesaNome ?? '',
                    status: 'Em Uso',
                    descricao: null,
                    codigoBarras: null,
                  ),
                ),
              ),
            ),
            (route) => route.isFirst, // Mantém apenas a primeira rota (home)
          );
        } else if (venda.comandaId != null && _comandaService != null) {
          debugPrint('📍 Navegando para detalhes da comanda: ${venda.comandaId}');
          
          // Busca dados da comanda para obter número e status
          final comandaResponse = await _comandaService!.getComandaById(venda.comandaId!);
          if (comandaResponse.success && comandaResponse.data != null) {
            final comanda = comandaResponse.data!;
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesProdutosMesaScreen(
                    entidade: MesaComandaInfo(
                      id: venda.comandaId!,
                      tipo: TipoEntidade.comanda,
                      numero: comanda.numero,
                      status: comanda.status,
                      descricao: comanda.descricao,
                      codigoBarras: comanda.codigoBarras,
                    ),
                  ),
                ),
              ),
              (route) => route.isFirst,
            );
          }
        } else {
          debugPrint('⚠️ Venda sem mesaId ou comandaId');
        }
      } else {
        debugPrint('⚠️ Não foi possível buscar venda para navegação');
      }
    } catch (e) {
      debugPrint('❌ Erro ao navegar para tela de origem: $e');
    }
  }
  
  /// Verifica se há pagamentos pendentes ao iniciar app
  /// 
  /// Deve ser chamado após login bem-sucedido
  Future<void> verificarPagamentosPendentes() async {
    if (!isInitialized) {
      debugPrint('⚠️ PagamentoPendenteManager não inicializado');
      return;
    }
    
    try {
      final pendentes = await _service!.getPagamentosPendentes();
      
      if (pendentes.isEmpty) {
        debugPrint('ℹ️ Nenhum pagamento pendente encontrado');
        return;
      }
      
      debugPrint('🔍 Encontrados ${pendentes.length} pagamento(s) pendente(s)');
      
      // Processa cada pagamento pendente (um por vez)
      for (final pagamento in pendentes) {
        await _mostrarDialogRegistro(pagamento);
        // Aguarda o dialog ser fechado antes de processar o próximo
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar pagamentos pendentes: $e');
    }
  }
  
  /// Converte forma de pagamento para TipoFormaPagamento enum
  int _getTipoFormaPagamento(String? paymentType, String? brand) {
    if (paymentType == null) return 1; // Dinheiro como padrão
    
    switch (paymentType.toLowerCase()) {
      case 'credit':
      case 'credito':
        return 2; // Cartão de Crédito
      case 'debit':
      case 'debito':
        return 3; // Cartão de Débito
      case 'pix':
        return 4; // PIX
      case 'cash':
      case 'dinheiro':
        return 1; // Dinheiro
      default:
        return 1; // Dinheiro como padrão
    }
  }
  
  /// Formata o tipo de pagamento para exibição
  String _formatPaymentType(String? paymentType, String? brand) {
    if (paymentType == null) return 'Dinheiro';
    
    switch (paymentType.toLowerCase()) {
      case 'credit':
      case 'credito':
        return brand != null ? 'Cartão de Crédito $brand' : 'Cartão de Crédito';
      case 'debit':
      case 'debito':
        return brand != null ? 'Cartão de Débito $brand' : 'Cartão de Débito';
      case 'pix':
        return 'PIX';
      case 'cash':
      case 'dinheiro':
        return 'Dinheiro';
      default:
        return paymentType;
    }
  }
}
