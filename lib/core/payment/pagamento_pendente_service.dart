import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/local/pagamento_pendente_local.dart';
import '../../data/repositories/pagamento_pendente_repository.dart';
import '../../data/services/core/venda_service.dart';
import '../../core/events/app_event_bus.dart';

/// Serviço para gerenciar pagamentos pendentes de registro
class PagamentoPendenteService {
  final PagamentoPendenteRepository _repository;
  final VendaService _vendaService;
  
  PagamentoPendenteService({
    required PagamentoPendenteRepository repository,
    required VendaService vendaService,
  })  : _repository = repository,
        _vendaService = vendaService;

  /// Salva um pagamento pendente localmente
  Future<PagamentoPendenteLocal> salvarPagamentoPendente({
    required String vendaId,
    required double valor,
    required String formaPagamento,
    required int tipoFormaPagamento,
    int numeroParcelas = 1,
    String? bandeiraCartao,
    String? identificadorTransacao,
    String? rotaOrigem,
  }) async {
    final pagamento = PagamentoPendenteLocal(
      id: const Uuid().v4(),
      vendaId: vendaId,
      valor: valor,
      formaPagamento: formaPagamento,
      tipoFormaPagamento: tipoFormaPagamento,
      numeroParcelas: numeroParcelas,
      bandeiraCartao: bandeiraCartao,
      identificadorTransacao: identificadorTransacao,
      dataPagamento: DateTime.now(),
      dataCriacao: DateTime.now(),
      tentativas: 0,
      rotaOrigem: rotaOrigem,
    );

    await _repository.upsert(pagamento);
    debugPrint('💾 Pagamento pendente salvo: ${pagamento.id}');
    
    return pagamento;
  }

  /// Tenta registrar um pagamento pendente no backend
  /// 
  /// Retorna true se sucesso, false se erro
  /// Incrementa contador de tentativas automaticamente
  Future<bool> tentarRegistrarPagamento(PagamentoPendenteLocal pagamento) async {
    // Incrementa tentativas
    final pagamentoAtualizado = pagamento.copyWith(
      tentativas: pagamento.tentativas + 1,
    );

    try {
      debugPrint('🔄 Tentando registrar pagamento ${pagamento.id} (tentativa ${pagamentoAtualizado.tentativas})');
      
      final response = await _vendaService.registrarPagamento(
        vendaId: pagamento.vendaId,
        valor: pagamento.valor,
        formaPagamento: pagamento.formaPagamento,
        tipoFormaPagamento: pagamento.tipoFormaPagamento,
        numeroParcelas: pagamento.numeroParcelas,
        bandeiraCartao: pagamento.bandeiraCartao,
        identificadorTransacao: pagamento.identificadorTransacao,
      );

      if (response.success) {
        // Sucesso - remove do local
        await _repository.delete(pagamento.id);
        debugPrint('✅ Pagamento ${pagamento.id} registrado com sucesso e removido do local');
        
        // Busca venda para obter mesaId e comandaId para o evento
        final vendaResponse = await _vendaService.getVendaById(pagamento.vendaId);
        final venda = vendaResponse.data;
        
        // Dispara evento de pagamento processado
        AppEventBus.instance.dispararPagamentoProcessado(
          vendaId: pagamento.vendaId,
          valor: pagamento.valor,
          mesaId: venda?.mesaId,
          comandaId: venda?.comandaId,
        );
        
        debugPrint('📢 [PagamentoPendenteService] Evento pagamentoProcessado disparado para venda ${pagamento.vendaId}');
        
        return true;
      } else {
        // Erro - atualiza com mensagem de erro
        await _repository.upsert(pagamentoAtualizado.copyWith(
          ultimoErro: response.message,
        ));
        debugPrint('❌ Erro ao registrar pagamento ${pagamento.id}: ${response.message}');
        return false;
      }
    } catch (e) {
      // Erro de exceção - atualiza com mensagem de erro
      await _repository.upsert(pagamentoAtualizado.copyWith(
        ultimoErro: e.toString(),
      ));
      debugPrint('❌ Exceção ao registrar pagamento ${pagamento.id}: $e');
      return false;
    }
  }

  /// Cancela um pagamento pendente (remove do local)
  Future<void> cancelarPagamento(String pagamentoId) async {
    await _repository.delete(pagamentoId);
    debugPrint('🚫 Pagamento pendente cancelado: $pagamentoId');
  }

  /// Busca todos os pagamentos pendentes
  Future<List<PagamentoPendenteLocal>> getPagamentosPendentes() async {
    return await _repository.getAll();
  }

  /// Busca um pagamento pendente por ID
  Future<PagamentoPendenteLocal?> getPagamentoPendente(String id) async {
    return await _repository.getById(id);
  }
}
