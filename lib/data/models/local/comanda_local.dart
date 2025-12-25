import 'package:hive/hive.dart';

part 'comanda_local.g.dart';

/// Modelo local simplificado de Comanda para uso offline
/// Contém apenas dados necessários para seleção (ID e numeração)
/// Status não é sincronizado, apenas dados básicos
@HiveType(typeId: 22)
class ComandaLocal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String numero;

  @HiveField(2)
  String? codigoBarras;

  @HiveField(3)
  String? descricao;

  @HiveField(4)
  bool isAtiva;

  @HiveField(5)
  DateTime ultimaSincronizacao;

  ComandaLocal({
    required this.id,
    required this.numero,
    this.codigoBarras,
    this.descricao,
    required this.isAtiva,
    required this.ultimaSincronizacao,
  });

  factory ComandaLocal.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final numeroValue = json['numero'];
    final numero = numeroValue == null
        ? ''
        : (numeroValue is String
            ? numeroValue.trim()
            : numeroValue.toString().trim());

    final isAtiva = json['isAtiva'] is bool
        ? json['isAtiva'] as bool
        : (json['isAtiva']?.toString().toLowerCase() == 'true') ||
            (json['ativa'] is bool
                ? json['ativa'] as bool
                : (json['ativa']?.toString().toLowerCase() == 'true'));

    return ComandaLocal(
      id: id,
      numero: numero,
      codigoBarras: json['codigoBarras'] as String?,
      descricao: json['descricao'] as String?,
      isAtiva: isAtiva,
      ultimaSincronizacao: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'codigoBarras': codigoBarras,
      'descricao': descricao,
      'isAtiva': isAtiva,
    };
  }

  /// Converte para ComandaListItemDto (com status padrão "Livre")
  /// Usado quando precisa exibir em telas que esperam ComandaListItemDto
  Map<String, dynamic> toListItemJson() {
    return {
      'id': id,
      'numero': numero,
      'codigoBarras': codigoBarras,
      'descricao': descricao,
      'status': 'Livre', // Status padrão para comandas offline
      'ativa': isAtiva,
      'isAtiva': isAtiva,
      'totalPedidosAtivos': 0,
      'valorTotalPedidosAtivos': 0.0,
    };
  }
}

