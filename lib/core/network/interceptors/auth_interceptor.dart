import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/core/auth_service.dart';

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
    // Se receber 401 (Unauthorized), SEMPRE tenta renovar o token primeiro
    if (err.response?.statusCode == 401) {
      debugPrint('AuthInterceptor: Recebeu 401, tentando refresh token...');
      
      try {
        // Tenta renovar o token (sempre tenta, mesmo que pareça válido)
        final refreshed = await _authService.refreshToken();
        
        if (refreshed) {
          debugPrint('AuthInterceptor: Token renovado com sucesso, repetindo requisição...');
          
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
              final response = await _authService.dio.fetch(opts);
              debugPrint('AuthInterceptor: Requisição repetida com sucesso após refresh');
              return handler.resolve(response);
            } catch (retryError) {
              debugPrint('AuthInterceptor: Erro ao repetir requisição após refresh: $retryError');
              // Se ainda der erro após refresh, propaga o erro
              handler.next(err);
              return;
            }
          } else {
            debugPrint('AuthInterceptor: Token não disponível após refresh, fazendo logout...');
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
          debugPrint('AuthInterceptor: Falha ao renovar token, fazendo logout...');
          await _authService.logout();
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
      } catch (e) {
        debugPrint('AuthInterceptor: Exceção ao tentar refresh token: $e');
        // Se falhar ao renovar, faz logout
        await _authService.logout();
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
    
    // Para outros erros, propaga normalmente
    handler.next(err);
  }
}



