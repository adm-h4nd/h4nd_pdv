import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/venda_balcao_pendente_service.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../core/events/app_event_bus.dart';
import 'services_provider.dart';
import 'package:provider/provider.dart';

/// Provider para gerenciar estado e lógica de venda balcão
/// Centraliza toda a lógica relacionada a vendas balcão para facilitar manutenção
/// e preparar o sistema para outros segmentos
class VendaBalcaoProvider extends ChangeNotifier {
  String? _vendaIdPendente;
  bool _isVerificando = false;
  bool _isBuscandoVenda = false;

  /// ID da venda pendente de pagamento
  String? get vendaIdPendente => _vendaIdPendente;

  /// Indica se existe venda pendente
  bool get temVendaPendente => _vendaIdPendente != null;

  /// Indica se está verificando venda pendente
  bool get isVerificando => _isVerificando;

  /// Indica se está buscando dados da venda
  bool get isBuscandoVenda => _isBuscandoVenda;

  VendaBalcaoProvider() {
    _carregarVendaPendente();
  }

  /// Carrega venda pendente do armazenamento local
  void _carregarVendaPendente() {
    _vendaIdPendente = VendaBalcaoPendenteService.obterVendaPendente();
    notifyListeners();
  }

  /// Salva venda pendente (persiste localmente) e dispara evento
  Future<void> salvarVendaPendente(String vendaId) async {
    await VendaBalcaoPendenteService.salvarVendaPendente(vendaId);
    _vendaIdPendente = vendaId;
    notifyListeners();
    debugPrint('✅ [VendaBalcaoProvider] VendaId salvo como pendente: $vendaId');
    
    // Dispara evento para notificar que uma venda balcão pendente foi criada
    // A BalcaoScreen escuta esse evento e abre o pagamento automaticamente
    debugPrint('📢 [VendaBalcaoProvider] Disparando evento vendaBalcaoPendenteCriada: $vendaId');
    AppEventBus.instance.dispararVendaBalcaoPendenteCriada(vendaId: vendaId);
    debugPrint('✅ [VendaBalcaoProvider] Evento disparado com sucesso');
  }

  /// Limpa venda pendente (remove do armazenamento)
  Future<void> limparVendaPendente() async {
    await VendaBalcaoPendenteService.limparVendaPendente();
    _vendaIdPendente = null;
    notifyListeners();
    debugPrint('✅ [VendaBalcaoProvider] Venda pendente limpa');
  }

  /// Busca venda atualizada pelo ID
  /// Retorna VendaDto se sucesso, null caso contrário
  Future<VendaDto?> buscarVendaAtualizada(BuildContext context, String vendaId) async {
    if (!context.mounted) return null;

    _isBuscandoVenda = true;
    notifyListeners();

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final vendaService = servicesProvider.vendaService;
      final vendaResponse = await vendaService.getVendaById(vendaId);

      if (vendaResponse.success && vendaResponse.data != null) {
        return vendaResponse.data!;
      }

      debugPrint('⚠️ [VendaBalcaoProvider] Erro ao buscar venda: ${vendaResponse.message}');
      return null;
    } catch (e) {
      debugPrint('❌ [VendaBalcaoProvider] Erro ao buscar venda: $e');
      return null;
    } finally {
      _isBuscandoVenda = false;
      notifyListeners();
    }
  }

  /// Verifica se há venda pendente e retorna o vendaId se existir
  /// Atualiza estado interno durante a verificação
  Future<String?> verificarVendaPendente() async {
    _isVerificando = true;
    notifyListeners();

    try {
      _vendaIdPendente = VendaBalcaoPendenteService.obterVendaPendente();
      return _vendaIdPendente;
    } finally {
      _isVerificando = false;
      notifyListeners();
    }
  }

  /// Busca e retorna venda pendente completa
  /// Retorna null se não houver venda pendente ou erro ao buscar
  Future<VendaDto?> obterVendaPendenteCompleta(BuildContext context) async {
    if (!context.mounted) return null;

    final vendaId = await verificarVendaPendente();
    if (vendaId == null) {
      return null;
    }

    return await buscarVendaAtualizada(context, vendaId);
  }
}

