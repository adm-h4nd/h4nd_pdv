import 'package:flutter/foundation.dart';
import '../../core/vendas/venda_dto.dart';

/// Item de lista de mesa
class MesaListItemDto {
  final String id;
  final String numero; // Identificação da mesa (SEMPRE String, ex: "Mesa 04", "A1", etc)
  final String? descricao;
  final String status; // Livre, Ocupada, Reservada, Suspensa
  final bool ativa;
  final bool permiteReserva;
  final String? layoutNome;
  final String? pedidoId; // ID do pedido vinculado se ocupada
  
  // Campo de venda atual
  final String? vendaAtualId; // ID da venda atual da mesa
  final VendaDto? vendaAtual; // Venda completa com pagamentos

  MesaListItemDto({
    required this.id,
    required this.numero,
    this.descricao,
    required this.status,
    required this.ativa,
    required this.permiteReserva,
    this.layoutNome,
    this.pedidoId,
    this.vendaAtualId,
    this.vendaAtual,
  });

  factory MesaListItemDto.fromJson(Map<String, dynamic> json) {
    // Converte id para String (pode vir como String ou Guid)
    final idValue = json['id'];
    final id = idValue is String 
        ? idValue 
        : idValue?.toString() ?? '';

    // Número da mesa é SEMPRE String (identificação da mesa, ex: "Mesa 04", "A1", etc)
    // NÃO é um número, é uma identificação textual
    // Aceita qualquer tipo e converte para String de forma explícita
    final numeroValue = json['numero'];
    final numero = numeroValue == null 
        ? '' 
        : (numeroValue is String 
            ? numeroValue.trim() 
            : numeroValue.toString().trim());

    // Converte status de int para String
    // StatusMesa: 1=Livre, 2=Ocupada, 3=Reservada, 4=Manutencao, 5=Suspensa, 6=AguardandoPagamento
    final statusValue = json['status'];
    String status = 'Livre';
    
    if (statusValue is int) {
      switch (statusValue) {
        case 1:
          status = 'Livre';
          break;
        case 2:
          status = 'Ocupada';
          break;
        case 3:
          status = 'Reservada';
          break;
        case 4:
          status = 'Manutencao';
          break;
        case 5:
          status = 'Suspensa';
          break;
        case 6:
          status = 'AguardandoPagamento';
          break;
        default:
          status = 'Livre';
      }
    } else if (statusValue is String) {
      status = statusValue;
    } else if (statusValue != null) {
      // Tenta converter string para int e depois mapear
      final intValue = int.tryParse(statusValue.toString());
      if (intValue != null) {
        switch (intValue) {
          case 1:
            status = 'Livre';
            break;
          case 2:
            status = 'Ocupada';
            break;
          case 3:
            status = 'Reservada';
            break;
          case 4:
            status = 'Manutencao';
            break;
          case 5:
            status = 'Suspensa';
            break;
          case 6:
            status = 'AguardandoPagamento';
            break;
          default:
            status = 'Livre';
        }
      } else {
        status = statusValue.toString();
      }
    }

    // Converte booleanos - backend usa isAtiva
    final ativa = json['isAtiva'] is bool 
        ? json['isAtiva'] as bool 
        : (json['isAtiva']?.toString().toLowerCase() == 'true') ||
          (json['ativa'] is bool 
              ? json['ativa'] as bool 
              : (json['ativa']?.toString().toLowerCase() == 'true'));

    final permiteReserva = json['permiteReserva'] is bool 
        ? json['permiteReserva'] as bool 
        : (json['permiteReserva']?.toString().toLowerCase() == 'true');

    // Backend retorna pedidoAtivoId
    final pedidoIdValue = json['pedidoAtivoId'] ?? json['pedidoId'];
    final pedidoId = pedidoIdValue?.toString();

    // Extrai campo de venda atual
    final vendaAtualIdValue = json['vendaAtualId'];
    final vendaAtualId = vendaAtualIdValue?.toString();

    // Extrai venda completa se disponível
    VendaDto? vendaAtual;
    final vendaAtualJson = json['vendaAtual'] as Map<String, dynamic>?;
    if (vendaAtualJson != null) {
      try {
        vendaAtual = VendaDto.fromJson(vendaAtualJson);
      } catch (e) {
        debugPrint('Erro ao parsear vendaAtual: $e');
      }
    }

    return MesaListItemDto(
      id: id,
      numero: numero,
      descricao: json['descricao'] as String?,
      status: status,
      ativa: ativa,
      permiteReserva: permiteReserva,
      layoutNome: json['layoutNome'] as String?,
      pedidoId: pedidoId,
      vendaAtualId: vendaAtualId,
      vendaAtual: vendaAtual,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero, // Já é String
      'descricao': descricao,
      'status': status,
      'ativa': ativa,
      'permiteReserva': permiteReserva,
      'layoutNome': layoutNome,
      'pedidoId': pedidoId,
      'vendaAtualId': vendaAtualId,
      'vendaAtual': vendaAtual?.toJson(),
    };
  }
  
  /// Verifica se a mesa tem venda ativa
  bool get temVendaAtiva => vendaAtualId != null && vendaAtualId!.isNotEmpty;
}

