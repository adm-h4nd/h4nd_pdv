/// Modelo de resposta de refresh token
class RefreshTokenResponse {
  final bool success;
  final String message;
  final RefreshTokenData data;
  final List<String> errors;
  final String timestamp;

  RefreshTokenResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.errors,
    required this.timestamp,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: RefreshTokenData.fromJson(json['data'] ?? {}),
      errors: List<String>.from(json['errors'] ?? []),
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class RefreshTokenData {
  final String token;
  final String refreshToken;
  final String expiresAt;
  final String refreshExpiresAt;

  RefreshTokenData({
    required this.token,
    required this.refreshToken,
    required this.expiresAt,
    required this.refreshExpiresAt,
  });

  factory RefreshTokenData.fromJson(Map<String, dynamic> json) {
    return RefreshTokenData(
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      expiresAt: json['expiresAt'] ?? '',
      refreshExpiresAt: json['refreshExpiresAt'] ?? '',
    );
  }
}



