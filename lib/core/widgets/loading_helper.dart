import 'package:flutter/material.dart';
import '../../widgets/h4nd_loading.dart';

/// Helper unificado para exibir e ocultar loading dialogs
/// Garante consistência em todo o sistema
class LoadingHelper {
  /// Mostra um loading dialog usando rootNavigator
  /// [context] - Contexto do widget
  /// [barrierDismissible] - Se o loading pode ser fechado ao tocar fora (padrão: false)
  static void show(
    BuildContext context, {
    bool barrierDismissible = false,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (dialogContext) => const Center(
        child: H4ndLoading(size: 60),
      ),
    );
  }

  /// Esconde o loading dialog usando rootNavigator
  /// [context] - Contexto do widget
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    
    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('⚠️ [LoadingHelper] Erro ao esconder loading: $e');
    }
  }

  /// Executa uma função assíncrona mostrando loading durante a execução
  /// [context] - Contexto do widget
  /// [action] - Função assíncrona a ser executada
  /// [barrierDismissible] - Se o loading pode ser fechado ao tocar fora (padrão: false)
  /// Retorna o resultado da função [action]
  static Future<T?> withLoading<T>(
    BuildContext context,
    Future<T> Function() action, {
    bool barrierDismissible = false,
  }) async {
    show(context, barrierDismissible: barrierDismissible);
    
    try {
      final result = await action();
      return result;
    } finally {
      hide(context);
    }
  }
}

