/// Model para alertas de mesa
class MesaAlerta {
  final String mesaId; // String para corresponder ao tipo de mesa.id
  final String numeroMesa;
  final TipoAlertaMesa tipo;
  final Duration tempoDecorrido;
  final String? detalhes; // Ex: "3 itens aguardando"
  final DateTime ultimaAtualizacao;

  MesaAlerta({
    required this.mesaId,
    required this.numeroMesa,
    required this.tipo,
    required this.tempoDecorrido,
    this.detalhes,
    DateTime? ultimaAtualizacao,
  }) : ultimaAtualizacao = ultimaAtualizacao ?? DateTime.now();

  /// Formata o tempo decorrido de forma legível
  String get tempoFormatado {
    final minutos = tempoDecorrido.inMinutes;
    final horas = tempoDecorrido.inHours;
    
    if (horas > 0) {
      final minutosRestantes = minutos % 60;
      if (minutosRestantes > 0) {
        return '${horas}h ${minutosRestantes}min';
      }
      return '${horas}h';
    }
    return '${minutos}min';
  }

  /// Descrição do alerta
  String get descricao {
    switch (tipo) {
      case TipoAlertaMesa.tempoSemPedir:
        return 'Sem pedir há $tempoFormatado';
      case TipoAlertaMesa.itensAguardando:
        return detalhes ?? 'Itens aguardando há $tempoFormatado';
    }
  }
}

enum TipoAlertaMesa {
  tempoSemPedir,      // Mesa há muito tempo sem fazer pedido
  itensAguardando,    // Itens de pedido aguardando há muito tempo
}

