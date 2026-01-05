import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/core/auth_service.dart';
import '../../../main.dart';
import '../../../core/widgets/app_dialog.dart';

/// Interceptor para adicionar token de autenticação nas requisições
class AuthInterceptor extends Interceptor {
  final AuthService _authService;

  AuthInterceptor(this._authService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Obtém o token atual do AuthService compartilhado
    final token = await _authService.getToken();
    
    if (token != null && token.isNotEmpty) {
      // Adiciona o token no header Authorization
      options.headers['Authorization'] = 'Bearer $token';
      
      // Obtém a empresa selecionada e adiciona no header X-Company-Id
      final selectedEmpresa = await _authService.getSelectedEmpresa();
      if (selectedEmpresa != null && selectedEmpresa.isNotEmpty) {
        options.headers['X-Company-Id'] = selectedEmpresa;
      }
    } else {
      // Log para debug se não houver token
      debugPrint('AuthInterceptor: Token não encontrado para requisição ${options.path}');
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    debugPrint('🔍 AuthInterceptor.onError: Status=${err.response?.statusCode}, Path=${err.requestOptions.path}');
    
    // Se receber 401 (Unauthorized), SEMPRE tenta renovar o token primeiro
    if (err.response?.statusCode == 401) {
      debugPrint('🚨 AuthInterceptor: Recebeu 401 (Unauthorized)');
      debugPrint('   Path: ${err.requestOptions.path}');
      debugPrint('   Method: ${err.requestOptions.method}');
      debugPrint('   Tentando refresh token...');
      
      try {
        // Tenta renovar o token (sempre tenta, mesmo que pareça válido)
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          debugPrint('✅ AuthInterceptor: Token renovado com sucesso!');
          debugPrint('   Repetindo requisição original...');
          
          // Repete a requisição original com o novo token
          final opts = err.requestOptions;
          final token = await _authService.getToken();
          
          if (token != null && token.isNotEmpty) {
            opts.headers['Authorization'] = 'Bearer $token';
            
            // Adiciona empresa selecionada novamente
            final selectedEmpresa = await _authService.getSelectedEmpresa();
            if (selectedEmpresa != null && selectedEmpresa.isNotEmpty) {
              opts.headers['X-Company-Id'] = selectedEmpresa;
            }
            
            // Remove o header de erro anterior se existir
            opts.headers.remove('error');
            
            try {
              debugPrint('   Fazendo requisição: ${opts.method} ${opts.path}');
              final response = await _authService.dio.fetch(opts);
              debugPrint('✅ AuthInterceptor: Requisição repetida com sucesso após refresh (Status: ${response.statusCode})');
              return handler.resolve(response);
            } catch (retryError) {
              debugPrint('❌ AuthInterceptor: Erro ao repetir requisição após refresh: $retryError');
              if (retryError is DioException) {
                debugPrint('   Status do retry: ${retryError.response?.statusCode}');
              }
              // Se ainda der erro após refresh, propaga o erro
              handler.next(err);
              return;
            }
          } else {
            debugPrint('❌ AuthInterceptor: Token não disponível após refresh, fazendo logout...');
            await _authService.logout();
            // Cria um erro específico para indicar que precisa fazer login
            final loginError = DioException(
              requestOptions: opts,
              response: err.response,
              type: DioExceptionType.badResponse,
              error: 'Sessão expirada. Faça login novamente.',
            );
            handler.next(loginError);
            return;
          }
        } else {
          debugPrint('❌ AuthInterceptor: Falha ao renovar token, fazendo logout...');
          await _handleLogout();
          // Cria um erro específico para indicar que precisa fazer login
          final loginError = DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: 'Sessão expirada. Faça login novamente.',
          );
          handler.next(loginError);
          return;
        }
      } catch (e, stackTrace) {
        debugPrint('❌ AuthInterceptor: Exceção ao tentar refresh token: $e');
        debugPrint('   StackTrace: $stackTrace');
        // Se falhar ao renovar, faz logout
        await _handleLogout();
        // Cria um erro específico para indicar que precisa fazer login
        final loginError = DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: 'Sessão expirada. Faça login novamente.',
        );
        handler.next(loginError);
        return;
      }
    }
    
    // Se receber 403 (Forbidden), mostra dialog com mensagem da API
    if (err.response?.statusCode == 403) {
      debugPrint('AuthInterceptor: Recebeu 403, exibindo dialog de acesso negado...');
      _handleForbiddenError(err);
      // Não propaga o erro, apenas mostra o dialog
      handler.next(err);
      return;
    }
    
    // Para outros erros, propaga normalmente
    handler.next(err);
  }
  
  /// Extrai mensagem de erro da resposta da API
  String _extractErrorMessage(DioException err) {
    try {
      final responseData = err.response?.data;
      if (responseData is Map<String, dynamic>) {
        // Tenta obter a mensagem do campo 'message'
        if (responseData['message'] != null && responseData['message'] is String) {
          return responseData['message'] as String;
        }
        // Se não tiver message, tenta obter do primeiro erro
        if (responseData['errors'] != null && responseData['errors'] is List) {
          final errors = responseData['errors'] as List;
          if (errors.isNotEmpty) {
            return errors.first.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('AuthInterceptor: Erro ao extrair mensagem: $e');
    }
    return 'Você não tem permissão para realizar esta operação.';
  }
  
  /// Trata erro 403 (Forbidden) - mostra dialog
  void _handleForbiddenError(DioException err) {
    final message = _extractErrorMessage(err);
    
    // Usa navigatorKey global para mostrar dialog mesmo sem context
    final context = navigatorKey.currentContext;
    if (context != null) {
      AppDialog.showError(
        context: context,
        title: 'Acesso Negado',
        message: message,
        buttonText: 'OK',
      );
    } else {
      debugPrint('AuthInterceptor: Não foi possível mostrar dialog 403 - context não disponível');
      debugPrint('Mensagem de erro: $message');
    }
  }
  
  /// Faz logout (a navegação será tratada pelo AuthProvider ou pela tela que detectar o logout)
  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      debugPrint('AuthInterceptor: Logout realizado com sucesso');
      // A navegação para login será tratada pelo sistema quando detectar que não há mais usuário autenticado
    } catch (e) {
      debugPrint('AuthInterceptor: Erro ao fazer logout: $e');
    }
  }
  
}



