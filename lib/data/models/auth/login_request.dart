/// Modelo de requisição de login
class LoginRequest {
  final String email;
  final String senha;
  final bool lembrame;
  final String? ipAddress;

  LoginRequest({
    required this.email,
    required this.senha,
    this.lembrame = false,
    this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,  // camelCase (padrão do ASP.NET Core)
      'senha': senha,
      'lembrame': lembrame,
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }
}



