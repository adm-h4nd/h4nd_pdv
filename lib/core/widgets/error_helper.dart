import 'package:flutter/material.dart';

/// Helper unificado para exibir mensagens de erro
/// Garante consistência em todo o sistema
class ErrorHelper {
  /// Mostra uma mensagem de erro usando SnackBar
  /// [context] - Contexto do widget
  /// [mensagem] - Mensagem de erro a ser exibida
  /// [duracao] - Duração do SnackBar (padrão: 4 segundos)
  /// [backgroundColor] - Cor de fundo (padrão: Colors.red)
  static void show(
    BuildContext context,
    String mensagem, {
    Duration duracao = const Duration(seconds: 4),
    Color backgroundColor = Colors.red,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: backgroundColor,
        duration: duracao,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mostra uma mensagem de sucesso usando SnackBar
  /// [context] - Contexto do widget
  /// [mensagem] - Mensagem de sucesso a ser exibida
  /// [duracao] - Duração do SnackBar (padrão: 3 segundos)
  static void showSuccess(
    BuildContext context,
    String mensagem, {
    Duration duracao = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
        duration: duracao,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mostra uma mensagem de informação usando SnackBar
  /// [context] - Contexto do widget
  /// [mensagem] - Mensagem de informação a ser exibida
  /// [duracao] - Duração do SnackBar (padrão: 3 segundos)
  static void showInfo(
    BuildContext context,
    String mensagem, {
    Duration duracao = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.blue,
        duration: duracao,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mostra uma mensagem de aviso usando SnackBar
  /// [context] - Contexto do widget
  /// [mensagem] - Mensagem de aviso a ser exibida
  /// [duracao] - Duração do SnackBar (padrão: 4 segundos)
  static void showWarning(
    BuildContext context,
    String mensagem, {
    Duration duracao = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.orange,
        duration: duracao,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

