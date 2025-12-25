/// DTOs de sincronização de mesas e comandas para PDV
/// Contém apenas dados básicos (ID e numeração) necessários para seleção offline

class MesaPdvSyncDto {
  final String id;
  final String numero;
  final String? descricao;
  final bool isAtiva;

  MesaPdvSyncDto({
    required this.id,
    required this.numero,
    this.descricao,
    required this.isAtiva,
  });

  factory MesaPdvSyncDto.fromJson(Map<String, dynamic> json) {
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

    return MesaPdvSyncDto(
      id: id,
      numero: numero,
      descricao: json['descricao'] as String?,
      isAtiva: isAtiva,
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
}

class ComandaPdvSyncDto {
  final String id;
  final String numero;
  final String? codigoBarras;
  final String? descricao;
  final bool isAtiva;

  ComandaPdvSyncDto({
    required this.id,
    required this.numero,
    this.codigoBarras,
    this.descricao,
    required this.isAtiva,
  });

  factory ComandaPdvSyncDto.fromJson(Map<String, dynamic> json) {
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

    return ComandaPdvSyncDto(
      id: id,
      numero: numero,
      codigoBarras: json['codigoBarras'] as String?,
      descricao: json['descricao'] as String?,
      isAtiva: isAtiva,
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
}

class MesaComandaPdvSyncResponseDto {
  final List<MesaPdvSyncDto> mesas;
  final List<ComandaPdvSyncDto> comandas;

  MesaComandaPdvSyncResponseDto({
    required this.mesas,
    required this.comandas,
  });

  factory MesaComandaPdvSyncResponseDto.fromJson(Map<String, dynamic> json) {
    // Converter mesas de forma segura
    List<MesaPdvSyncDto> mesas = [];
    final mesasData = json['mesas'] ?? json['Mesas'];
    if (mesasData != null && mesasData is List) {
      mesas = mesasData
          .map((item) {
            if (item is Map<String, dynamic>) {
              return MesaPdvSyncDto.fromJson(item);
            }
            return null;
          })
          .whereType<MesaPdvSyncDto>()
          .toList();
    }

    // Converter comandas de forma segura
    List<ComandaPdvSyncDto> comandas = [];
    final comandasData = json['comandas'] ?? json['Comandas'];
    if (comandasData != null && comandasData is List) {
      comandas = comandasData
          .map((item) {
            if (item is Map<String, dynamic>) {
              return ComandaPdvSyncDto.fromJson(item);
            }
            return null;
          })
          .whereType<ComandaPdvSyncDto>()
          .toList();
    }

    return MesaComandaPdvSyncResponseDto(
      mesas: mesas,
      comandas: comandas,
    );
  }
}

