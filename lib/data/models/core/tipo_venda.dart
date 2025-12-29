/// Enum que representa os diferentes tipos de venda no sistema
/// 
/// - `balcao`: Venda balcão - requer conexão, fluxo de pagamento gerenciado pela BalcaoScreen
/// - `controlada`: Venda controlada (mesa/comanda) - pode usar Hive se offline, fluxo normal
enum TipoVenda {
  /// Venda balcão (venda direta no balcão)
  /// Requer conexão obrigatória e tem fluxo de pagamento específico gerenciado pela BalcaoScreen
  balcao,

  /// Venda controlada (mesa/comanda)
  /// Pode usar Hive como fallback se offline, segue fluxo normal de sincronização
  controlada,
}

/// Extensão para facilitar uso do enum
extension TipoVendaExtension on TipoVenda {
  /// Retorna true se o tipo de venda requer conexão obrigatória
  /// (não pode usar Hive como fallback)
  bool get requerConexao {
    switch (this) {
      case TipoVenda.balcao:
        return true; // Balcão sempre requer conexão
      case TipoVenda.controlada:
        return false; // Controlada pode usar Hive se offline
    }
  }

  /// Retorna o nome legível do tipo de venda
  String get nome {
    switch (this) {
      case TipoVenda.balcao:
        return 'Balcão';
      case TipoVenda.controlada:
        return 'Controlada';
    }
  }
}

