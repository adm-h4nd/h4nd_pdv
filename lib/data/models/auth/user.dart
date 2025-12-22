/// Modelo de usuário autenticado
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isSuperAdmin;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isSuperAdmin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isSuperAdmin: json['isSuperAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'isSuperAdmin': isSuperAdmin,
    };
  }
}



