import '../../core/vendas/venda_dto.dart';
import '../../core/vendas/pagamento_venda_dto.dart';

/// Item de lista de comanda
class ComandaListItemDto {
  final String id;
  final String numero;
  final String? codigoBarras;
  final String? descricao;
  final String status; // Livre, Em Uso (baseado na sessão)
  final bool ativa;
  final int totalPedidosAtivos;
  final double valorTotalPedidosAtivos;
  
  // Campo de venda atual
  final String? vendaAtualId; // ID da venda atual da comanda
  final VendaDto? vendaAtual; // Venda completa com pagamentos
  
  // Pagamentos da venda atual (quando houver)
  final List<PagamentoVendaDto> pagamentos;

  ComandaListItemDto({
    required this.id,
    required this.numero,
    this.codigoBarras,
    this.descricao,
    required this.status,
    required this.ativa,
    required this.totalPedidosAtivos,
    required this.valorTotalPedidosAtivos,
    this.vendaAtualId,
    this.vendaAtual,
    this.pagamentos = const [],
  });

  factory ComandaListItemDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final numeroValue = json['numero'];
    final numero = numeroValue == null 
        ? '' 
        : (numeroValue is String ? numeroValue.trim() : numeroValue.toString().trim());

    // Status da comanda: usa o status do backend
    // StatusComanda: 1=Livre, 2=EmUso
    final vendaAtualIdValue = json['vendaAtualId'];
    final vendaAtualId = vendaAtualIdValue?.toString();
    
    final statusValue = json['status'];
    String status = 'Livre';
    
    // Converte status para int (pode vir como int ou string)
    int? statusInt;
    if (statusValue is int) {
      statusInt = statusValue;
    } else if (statusValue != null) {
      // Tenta converter string para int
      statusInt = int.tryParse(statusValue.toString());
    }
    
    // Mapeia status baseado no valor numérico
    if (statusInt != null) {
      switch (statusInt) {
        case 1:
          status = 'Livre';
          break;
        case 2:
          status = 'Em Uso';
          break;
        default:
          status = 'Livre';
      }
    } else if (statusValue is String) {
      // Se não conseguiu converter e é string, usa diretamente
      final statusLower = statusValue.toLowerCase();
      if (statusLower == 'livre' || statusLower == 'em uso') {
        status = statusValue; // Mantém capitalização original
      } else {
        // Fallback: determina pela venda
        status = (vendaAtualId != null && vendaAtualId.isNotEmpty) ? 'Em Uso' : 'Livre';
      }
    } else {
      // Fallback: determina pela venda se não vier status
      status = (vendaAtualId != null && vendaAtualId.isNotEmpty) ? 'Em Uso' : 'Livre';
    }
    
    // Validação final: garante consistência entre status e venda
    final temVenda = vendaAtualId != null && vendaAtualId.isNotEmpty;
    if (temVenda && status.toLowerCase() == 'livre') {
      status = 'Em Uso'; // Corrige se tem venda mas status está Livre
    } else if (!temVenda && status.toLowerCase() == 'em uso') {
      status = 'Livre'; // Corrige se não tem venda mas status está Em Uso
    }

    final ativa = json['isAtiva'] is bool 
        ? json['isAtiva'] as bool 
        : (json['isAtiva']?.toString().toLowerCase() == 'true') ||
          (json['ativa'] is bool 
              ? json['ativa'] as bool 
              : (json['ativa']?.toString().toLowerCase() == 'true'));

    final totalPedidosAtivos = json['totalPedidosAtivos'] is int
        ? json['totalPedidosAtivos'] as int
        : int.tryParse(json['totalPedidosAtivos']?.toString() ?? '0') ?? 0;

    final valorTotalPedidosAtivos = json['valorTotalPedidosAtivos'] is num
        ? (json['valorTotalPedidosAtivos'] as num).toDouble()
        : double.tryParse(json['valorTotalPedidosAtivos']?.toString() ?? '0') ?? 0.0;

    // Processa pagamentos se existirem
    List<PagamentoVendaDto> pagamentos = [];
    if (json['pagamentos'] != null && json['pagamentos'] is List) {
      pagamentos = (json['pagamentos'] as List)
          .map((item) => PagamentoVendaDto.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ComandaListItemDto(
      id: id,
      numero: numero,
      codigoBarras: json['codigoBarras'] as String?,
      descricao: json['descricao'] as String?,
      status: status,
      ativa: ativa,
      totalPedidosAtivos: totalPedidosAtivos,
      valorTotalPedidosAtivos: valorTotalPedidosAtivos,
      vendaAtualId: vendaAtualId,
      pagamentos: pagamentos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'codigoBarras': codigoBarras,
      'descricao': descricao,
      'status': status,
      'isAtiva': ativa,
      'totalPedidosAtivos': totalPedidosAtivos,
      'valorTotalPedidosAtivos': valorTotalPedidosAtivos,
      'vendaAtualId': vendaAtualId,
      'vendaAtual': vendaAtual?.toJson(),
      'pagamentos': pagamentos.map((p) => p.toJson()).toList(),
    };
  }
  
  /// Verifica se a comanda tem venda ativa
  bool get temVendaAtiva => vendaAtualId != null && vendaAtualId!.isNotEmpty;
}
