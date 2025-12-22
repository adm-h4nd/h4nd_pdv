import 'package:flutter/foundation.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/models/auth/user.dart';
import '../../data/models/auth/login_response.dart';

/// Provider para gerenciamento de estado de autenticação
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._authService) {
    _loadUser();
  }

  /// Usuário atual
  User? get user => _user;

  /// Se está carregando
  bool get isLoading => _isLoading;

  /// Erro atual
  String? get error => _error;

  /// Se está autenticado
  bool get isAuthenticated => _user != null;

  /// Se é SuperAdmin
  bool get isSuperAdmin => _user?.isSuperAdmin ?? false;

  /// Realiza o login
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      if (response.success) {
        _user = _authService.getCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message.isNotEmpty
            ? response.message
            : 'Erro ao realizar login';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Extrai mensagem de erro mais amigável
      String errorMessage = 'Erro ao realizar login';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifica se está autenticado
  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        _user = _authService.getCurrentUser();
      } else {
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
      return isAuth;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _user = null;
      notifyListeners();
      return false;
    }
  }

  /// Carrega o usuário atual
  void _loadUser() {
    _user = _authService.getCurrentUser();
    notifyListeners();
  }

  /// Limpa o erro
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Obtém o setor da organização
  Future<int?> getSetorOrganizacao() async {
    return await _authService.getSetorOrganizacao();
  }

  /// Obtém o nome da empresa selecionada
  Future<String?> getSelectedEmpresaNome() async {
    try {
      final empresas = await _authService.getEmpresas();
      final selectedEmpresaId = await _authService.getSelectedEmpresa();
      if (selectedEmpresaId != null && empresas.isNotEmpty) {
        final empresa = empresas.firstWhere(
          (e) => e.id == selectedEmpresaId,
          orElse: () => empresas.first,
        );
        return empresa.nome;
      }
      return empresas.isNotEmpty ? empresas.first.nome : null;
    } catch (e) {
      return null;
    }
  }
}



