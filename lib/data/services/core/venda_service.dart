import '../../../core/network/api_client.dart';
import '../../../core/payment/payment_transaction_data.dart';
import '../../models/core/api_response.dart';
import '../../models/core/vendas/venda_dto.dart';
import '../../models/core/vendas/pagamento_venda_dto.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciamento de vendas
class VendaService {
  final ApiClient _apiClient;
  
  VendaService({required ApiClient apiClient}) : _apiClient = apiClient;
  
  /// Registra um pagamento em uma venda
  /// 
  /// POST /api/vendas/{vendaId}/pagamentos
  /// 
  /// NOTA: Este endpoint precisa ser criado no backend, pois atualmente
  /// só existe endpoint para pagamentos de Pedido (/api/pedidos/{id}/pagamentos).
  /// O pagamento deve ser registrado na Venda, não no Pedido individual.
  Future<ApiResponse<PagamentoVendaDto>> registrarPagamento({
    required String vendaId,
    required double valor,
    required String formaPagamento,
    required int tipoFormaPagamento, // TipoFormaPagamento enum
    int numeroParcelas = 1,
    String? bandeiraCartao,
    String? identificadorTransacao,
    List<Map<String, dynamic>>? produtos, // Lista opcional de produtos para nota fiscal (restaurante)
    PaymentTransactionData? transactionData, // Dados padronizados da transação
  }) async {
    try {
      debugPrint('📤 Registrando pagamento: Venda=$vendaId, Valor=$valor, Forma=$formaPagamento');
      
      final payload = {
        'valor': valor,
        'formaPagamento': formaPagamento,
        'tipoFormaPagamento': tipoFormaPagamento,
        'numeroParcelas': numeroParcelas,
        if (bandeiraCartao != null) 'bandeiraCartao': bandeiraCartao,
        // identificadorTransacaoPIX só para PIX, não para cartão
        // Para cartão, usa os campos de transação padronizados
        if (identificadorTransacao != null && tipoFormaPagamento == 4) 
          'identificadorTransacaoPIX': identificadorTransacao,
        if (produtos != null && produtos.isNotEmpty) 'produtos': produtos,
        
        // Campos de transação padronizados (se disponíveis)
        if (transactionData != null) ...transactionData.toMap(),
        
        // Campos legados para compatibilidade (usar cardBrandName se disponível)
        if (transactionData?.cardBrandName != null && bandeiraCartao == null) 
          'bandeiraCartao': transactionData!.cardBrandName,
      };
      
      debugPrint('📤 Payload do pagamento: $payload');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/$vendaId/pagamentos',
        data: payload,
      );
      
      if (response.data == null) {
        return ApiResponse<PagamentoVendaDto>.error(
          message: 'Erro ao registrar pagamento',
        );
      }
      
      final data = response.data!;
      final pagamentoData = data['data'] as Map<String, dynamic>?;
      
      if (pagamentoData == null) {
        return ApiResponse<PagamentoVendaDto>.error(
          message: data['message'] as String? ?? 'Erro ao registrar pagamento',
        );
      }
      
      final pagamento = PagamentoVendaDto.fromJson(pagamentoData);
      debugPrint('✅ Pagamento registrado com sucesso: ${pagamento.id}');
      
      return ApiResponse<PagamentoVendaDto>.success(
        data: pagamento,
        message: data['message'] as String? ?? 'Pagamento registrado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao registrar pagamento: $e');
      return ApiResponse<PagamentoVendaDto>.error(
        message: 'Erro ao registrar pagamento: ${e.toString()}',
      );
    }
  }
  
  /// Busca uma venda por ID
  Future<ApiResponse<VendaDto>> getVendaById(String vendaId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/vendas/$vendaId',
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Venda não encontrada',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Venda não encontrada',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda encontrada',
      );
    } catch (e) {
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao buscar venda: ${e.toString()}',
      );
    }
  }

  /// Busca venda aberta por comanda (se existir)
  /// 
  /// GET /api/vendas/por-comanda/{comandaId}
  Future<ApiResponse<VendaDto?>> getVendaAbertaPorComanda(String comandaId) async {
    try {
      debugPrint('🔍 Buscando venda aberta da comanda: $comandaId');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/vendas/por-comanda/$comandaId',
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto?>.error(
          message: 'Erro ao buscar venda',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        // Venda não encontrada (pode ser null se não houver venda aberta)
        debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
        return ApiResponse<VendaDto?>.success(
          data: null,
          message: data['message'] as String? ?? 'Nenhuma venda aberta encontrada',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Venda aberta encontrada: ${venda.id}, MesaId: ${venda.mesaId}');
      
      return ApiResponse<VendaDto?>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda encontrada',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar venda aberta da comanda: $e');
      return ApiResponse<VendaDto?>.error(
        message: 'Erro ao buscar venda: ${e.toString()}',
      );
    }
  }

  /// Conclui uma venda (emite nota fiscal final)
  /// 
  /// POST /api/vendas/{vendaId}/concluir
  Future<ApiResponse<VendaDto>> concluirVenda(String vendaId) async {
    try {
      debugPrint('📤 Concluindo venda: Venda=$vendaId');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/$vendaId/concluir',
        data: {},
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Erro ao concluir venda',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Erro ao concluir venda',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Venda concluída com sucesso: ${venda.id}');
      
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda concluída com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao concluir venda: $e');
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao concluir venda: ${e.toString()}',
      );
    }
  }
}

