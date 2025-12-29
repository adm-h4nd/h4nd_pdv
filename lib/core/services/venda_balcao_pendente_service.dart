import '../storage/preferences_service.dart';

/// Service para gerenciar venda balcão pendente de pagamento
/// Persiste apenas o ID da venda localmente (não usa Hive)
class VendaBalcaoPendenteService {
  static const String _key = 'venda_balcao_pendente_id';

  /// Salva o ID da venda pendente
  static Future<void> salvarVendaPendente(String vendaId) async {
    await PreferencesService.setString(_key, vendaId);
  }

  /// Obtém o ID da venda pendente (se existir)
  static String? obterVendaPendente() {
    return PreferencesService.getString(_key);
  }

  /// Verifica se existe venda pendente
  static bool temVendaPendente() {
    return PreferencesService.containsKey(_key) && 
           PreferencesService.getString(_key) != null;
  }

  /// Limpa a venda pendente (após finalizar pagamento)
  static Future<void> limparVendaPendente() async {
    await PreferencesService.remove(_key);
  }
}

