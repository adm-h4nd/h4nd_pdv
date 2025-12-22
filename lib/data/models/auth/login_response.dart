/// Modelo de resposta de login
class LoginResponse {
  final bool success;
  final String message;
  final LoginData data;
  final List<String> errors;
  final String timestamp;

  LoginResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.errors,
    required this.timestamp,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: LoginData.fromJson(json['data'] ?? {}),
      errors: List<String>.from(json['errors'] ?? []),
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class LoginData {
  final String token;
  final String refreshToken;
  final String nome;
  final String email;
  final bool isSuperAdmin;
  final List<String> areasDisponiveis;
  final String expiresAt;
  final String refreshExpiresAt;
  final String tenantId;
  final String organizacaoNome;

  LoginData({
    required this.token,
    required this.refreshToken,
    required this.nome,
    required this.email,
    required this.isSuperAdmin,
    required this.areasDisponiveis,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.tenantId,
    required this.organizacaoNome,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      isSuperAdmin: json['isSuperAdmin'] ?? false,
      areasDisponiveis: List<String>.from(json['areasDisponiveis'] ?? []),
      expiresAt: json['expiresAt'] ?? '',
      refreshExpiresAt: json['refreshExpiresAt'] ?? '',
      tenantId: json['tenantId'] ?? '',
      organizacaoNome: json['organizacaoNome'] ?? '',
    );
  }
}



