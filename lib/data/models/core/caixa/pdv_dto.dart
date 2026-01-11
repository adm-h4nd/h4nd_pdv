/// DTO para listagem de PDV
class PDVListItemDto {
  final String id;
  final String empresaId;
  final String empresaNome;
  final String nome;
  final String? codigo;
  final String? localizacao;
  final bool isActive;
  final bool temCaixaAberto;
  final String? deviceId;
  final String? observacoesVinculacao;

  PDVListItemDto({
    required this.id,
    required this.empresaId,
    required this.empresaNome,
    required this.nome,
    this.codigo,
    this.localizacao,
    required this.isActive,
    required this.temCaixaAberto,
    this.deviceId,
    this.observacoesVinculacao,
  });

  /// Indica se o PDV está vinculado a um dispositivo
  bool get estaVinculado => deviceId != null && deviceId!.isNotEmpty;

  factory PDVListItemDto.fromJson(Map<String, dynamic> json) {
    // Converter IDs (podem vir como Guid ou String)
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';
    
    final empresaIdValue = json['empresaId'];
    final empresaId = empresaIdValue is String ? empresaIdValue : empresaIdValue?.toString() ?? '';
    
    return PDVListItemDto(
      id: id,
      empresaId: empresaId,
      empresaNome: json['empresaNome'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      codigo: json['codigo'] as String?,
      localizacao: json['localizacao'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      temCaixaAberto: json['temCaixaAberto'] as bool? ?? false,
      deviceId: json['deviceId'] as String?,
      observacoesVinculacao: json['observacoesVinculacao'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'nome': nome,
      'codigo': codigo,
      'localizacao': localizacao,
      'isActive': isActive,
      'temCaixaAberto': temCaixaAberto,
      'deviceId': deviceId,
      'observacoesVinculacao': observacoesVinculacao,
    };
  }
}

/// DTO completo de PDV
class PDVDto extends PDVListItemDto {
  final String? descricao;
  final String? configuracoes;
  final String createdAt;
  final String? updatedAt;

  PDVDto({
    required super.id,
    required super.empresaId,
    required super.empresaNome,
    required super.nome,
    super.codigo,
    super.localizacao,
    required super.isActive,
    required super.temCaixaAberto,
    super.deviceId,
    super.observacoesVinculacao,
    this.descricao,
    this.configuracoes,
    required this.createdAt,
    this.updatedAt,
  });

  factory PDVDto.fromJson(Map<String, dynamic> json) {
    // Converter IDs (podem vir como Guid ou String)
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';
    
    final empresaIdValue = json['empresaId'];
    final empresaId = empresaIdValue is String ? empresaIdValue : empresaIdValue?.toString() ?? '';
    
    return PDVDto(
      id: id,
      empresaId: empresaId,
      empresaNome: json['empresaNome'] as String? ?? '',
      nome: json['nome'] as String,
      codigo: json['codigo'] as String?,
      localizacao: json['localizacao'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      temCaixaAberto: json['temCaixaAberto'] as bool? ?? false,
      deviceId: json['deviceId'] as String?,
      observacoesVinculacao: json['observacoesVinculacao'] as String?,
      descricao: json['descricao'] as String?,
      configuracoes: json['configuracoes'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'descricao': descricao,
      'configuracoes': configuracoes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

