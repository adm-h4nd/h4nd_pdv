import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/core/auth_service.dart';
import '../../../main.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../presentation/screens/auth/login_screen.dart';

/// Interceptor para adicionar token de autenticação nas requisições
class AuthInterceptor extends Interceptor {
  final AuthService _authService;

  AuthInterceptor(this._authService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    debugPrint('🔵 AuthInterceptor.onRequest: ${options.method} ${options.path}');
    
    // Ignora endpoints de autenticação (não precisam de token)
    if (_isAuthEndpoint(options.path)) {
      debugPrint('   ⏭️ Ignorando endpoint de auth (não precisa token)');
      handler.next(options);
      return;
    }
    
    // Obtém o token atual do AuthService compartilhado
    final token = await _authService.getToken();
    
    if (token != null && token.isNotEmpty) {
      // Adiciona o token no header Authorization
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('   ✅ Token adicionado ao header');
      
      // Obtém a empresa selecionada e adiciona no header X-Company-Id
      final selectedEmpresa = await _authService.getSelectedEmpresa();
      if (selectedEmpresa != null && selectedEmpresa.isNotEmpty) {
        options.headers['X-Company-Id'] = selectedEmpresa;
        debugPrint('   ✅ X-Company-Id adicionado: $selectedEmpresa');
      }
    } else {
      // Log para debug se não houver token
      debugPrint('   ⚠️ Token não encontrado para requisição ${options.path}');
    }
    
    handler.next(options);
  }
  
  /// Verifica se o endpoint é de autenticação (não precisa de token)
  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
           path.contains('/auth/refresh') ||
           path.contains('/auth/revoke') ||
           path.contains('/auth/validate') ||
           path.contains('/auth/health');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;
    
    debugPrint('🔍 AuthInterceptor.onError: Status=$statusCode, Path=$path');
    debugPrint('   Error type: ${err.type}');
    debugPrint('   Error message: ${err.message}');
    debugPrint('   Response data: ${err.response?.data}');
    
    // Verifica se tem response e status code
    if (err.response == null) {
      debugPrint('   ⚠️ Sem response, propagando erro normalmente');
      handler.next(err);
      return;
    }
    
    // Se for endpoint de refresh e retornar 401, não tenta fazer refresh novamente (evita loop)
    if (_isAuthEndpoint(path) && statusCode == 401) {
      debugPrint('⚠️ AuthInterceptor: Endpoint de auth retornou 401, não tentando refresh (evita loop)');
      handler.next(err);
      return;
    }
    
    // Se receber 401 (Unauthorized), SEMPRE tenta renovar o token primeiro
    if (statusCode == 401) {
      debugPrint('🚨 AuthInterceptor: Recebeu 401 (Unauthorized)');
      debugPrint('   Path: ${err.requestOptions.path}');
      debugPrint('   Method: ${err.requestOptions.method}');
      
      // Verifica se tem refresh token antes de tentar renovar
      final refreshToken = await _authService.getRefreshToken();
      debugPrint('   🔍 Verificando refresh token...');
      debugPrint('   Refresh token é null: ${refreshToken == null}');
      debugPrint('   Refresh token está vazio: ${refreshToken?.isEmpty ?? true}');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        debugPrint('   Refresh token length: ${refreshToken.length}');
        debugPrint('   Refresh token preview: ${refreshToken.substring(0, refreshToken.length > 30 ? 30 : refreshToken.length)}...');
      }
      
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('   ⚠️ Não há refresh token disponível, fazendo logout...');
        await _handleLogout();
        final loginError = DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: 'Sessão expirada. Faça login novamente.',
        );
        handler.next(loginError);
        return;
      }
      
      debugPrint('   ✅ Refresh token encontrado, tentando renovar...');
      
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
  
  /// Faz logout e navega para tela de login
  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      debugPrint('✅ AuthInterceptor: Logout realizado com sucesso');
      
      // Aguarda um frame para garantir que o estado foi atualizado
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Navega para tela de login usando navigatorKey global
      // Usa addPostFrameCallback para garantir que a navegação aconteça após o frame atual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        debugPrint('🔍 AuthInterceptor: Verificando navigator...');
        debugPrint('   navigatorKey.currentContext: ${navigatorKey.currentContext}');
        debugPrint('   navigatorKey.currentState: $navigator');
        
        if (navigator != null) {
          debugPrint('   ✅ Navigator disponível, navegando para tela de login...');
          try {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AdaptiveLayout(
                  child: LoginScreen(),
                ),
              ),
              (route) => false, // Remove todas as rotas anteriores
            );
            debugPrint('✅ AuthInterceptor: Navegação para login concluída');
          } catch (navError) {
            debugPrint('❌ AuthInterceptor: Erro ao navegar: $navError');
            // Tenta novamente após um pequeno delay
            Future.delayed(const Duration(milliseconds: 500), () {
              final retryNavigator = navigatorKey.currentState;
              if (retryNavigator != null) {
                debugPrint('   🔄 Tentando navegação novamente...');
                retryNavigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const AdaptiveLayout(
                      child: LoginScreen(),
                    ),
                  ),
                  (route) => false,
                );
                debugPrint('✅ AuthInterceptor: Navegação concluída na segunda tentativa');
              } else {
                debugPrint('❌ AuthInterceptor: Navigator ainda não disponível na segunda tentativa');
              }
            });
          }
        } else {
          debugPrint('⚠️ AuthInterceptor: Navigator não disponível para navegar para login');
          debugPrint('   Tentando novamente após delay...');
          // Tenta novamente após um delay maior
          Future.delayed(const Duration(milliseconds: 500), () {
            final retryNavigator = navigatorKey.currentState;
            if (retryNavigator != null) {
              debugPrint('   ✅ Navigator disponível na segunda tentativa, navegando...');
              retryNavigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const AdaptiveLayout(
                    child: LoginScreen(),
                  ),
                ),
                (route) => false,
              );
              debugPrint('✅ AuthInterceptor: Navegação concluída na segunda tentativa');
            } else {
              debugPrint('❌ AuthInterceptor: Navigator ainda não disponível após delay');
            }
          });
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ AuthInterceptor: Erro ao fazer logout: $e');
      debugPrint('   StackTrace: $stackTrace');
    }
  }
  
}



