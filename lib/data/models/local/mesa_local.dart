import 'package:hive/hive.dart';

part 'mesa_local.g.dart';

/// Modelo local simplificado de Mesa para uso offline
/// Contém apenas dados necessários para seleção (ID e numeração)
/// Status não é sincronizado, apenas dados básicos
@HiveType(typeId: 21)
class MesaLocal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String numero; // Identificação da mesa (ex: "Mesa 04", "A1", etc)

  @HiveField(2)
  String? descricao;

  @HiveField(3)
  bool isAtiva;

  @HiveField(4)
  DateTime ultimaSincronizacao;

  MesaLocal({
    required this.id,
    required this.numero,
    this.descricao,
    required this.isAtiva,
    required this.ultimaSincronizacao,
  });

  factory MesaLocal.fromJson(Map<String, dynamic> json) {
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

    return MesaLocal(
      id: id,
      numero: numero,
      descricao: json['descricao'] as String?,
      isAtiva: isAtiva,
      ultimaSincronizacao: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'descricao': descricao,
      'isAtiva': isAtiva,
    };
  }

  /// Converte para MesaListItemDto (com status padrão "Livre")
  /// Usado quando precisa exibir em telas que esperam MesaListItemDto
  Map<String, dynamic> toListItemJson() {
    return {
      'id': id,
      'numero': numero,
      'descricao': descricao,
      'status': 'Livre', // Status padrão para mesas offline
      'ativa': isAtiva,
      'isAtiva': isAtiva,
      'permiteReserva': false, // Valor padrão
    };
  }
}

