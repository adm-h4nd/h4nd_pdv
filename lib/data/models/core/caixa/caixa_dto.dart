/// DTO para listagem de caixa (cadastro)
class CaixaListItemDto {
  final String id;
  final String empresaId;
  final String empresaNome;
  final String nome;
  final String? codigo;
  final String? descricao;
  final bool isActive;

  CaixaListItemDto({
    required this.id,
    required this.empresaId,
    required this.empresaNome,
    required this.nome,
    this.codigo,
    this.descricao,
    required this.isActive,
  });

  factory CaixaListItemDto.fromJson(Map<String, dynamic> json) {
    // Converter IDs (podem vir como Guid ou String)
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';
    
    final empresaIdValue = json['empresaId'];
    final empresaId = empresaIdValue is String ? empresaIdValue : empresaIdValue?.toString() ?? '';
    
    return CaixaListItemDto(
      id: id,
      empresaId: empresaId,
      empresaNome: json['empresaNome'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      codigo: json['codigo'] as String?,
      descricao: json['descricao'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'nome': nome,
      'codigo': codigo,
      'descricao': descricao,
      'isActive': isActive,
    };
  }
}

/// DTO completo de caixa (cadastro)
class CaixaDto extends CaixaListItemDto {
  final String createdAt;
  final String? updatedAt;

  CaixaDto({
    required super.id,
    required super.empresaId,
    required super.empresaNome,
    required super.nome,
    super.codigo,
    super.descricao,
    required super.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory CaixaDto.fromJson(Map<String, dynamic> json) {
    return CaixaDto(
      id: json['id'] as String,
      empresaId: json['empresaId'] as String,
      empresaNome: json['empresaNome'] as String? ?? '',
      nome: json['nome'] as String,
      codigo: json['codigo'] as String?,
      descricao: json['descricao'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

