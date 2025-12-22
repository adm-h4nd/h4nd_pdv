/// Modelo de empresa disponível para o usuário
class Empresa {
  final String id;
  final String nome;

  Empresa({
    required this.id,
    required this.nome,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
    };
  }
}



