import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Tipos de diálogo disponíveis
enum AppDialogType {
  alert,
  confirm,
  success,
  error,
  info,
}

/// Componente genérico de diálogo para padronizar o sistema
class AppDialog {
  /// Mostra um diálogo de alerta
  static Future<bool?> showAlert({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AppDialogWidget(
        type: AppDialogType.alert,
        title: title,
        message: message,
        buttonText: buttonText ?? 'OK',
        icon: icon ?? Icons.info_outline,
        iconColor: iconColor ?? AppTheme.primaryColor,
      ),
    );
  }

  /// Mostra um diálogo de confirmação
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    IconData? icon,
    Color? iconColor,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppDialogWidget(
        type: AppDialogType.confirm,
        title: title,
        message: message,
        confirmText: confirmText ?? 'Confirmar',
        cancelText: cancelText ?? 'Cancelar',
        icon: icon ?? Icons.help_outline,
        iconColor: iconColor ?? Colors.orange,
        confirmColor: confirmColor ?? Colors.red,
      ),
    );
  }

  /// Mostra um diálogo de sucesso
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    String? message,
    String? buttonText,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppDialogWidget(
        type: AppDialogType.success,
        title: title,
        message: message,
        buttonText: buttonText ?? 'OK',
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Mostra um diálogo de erro
  static Future<void> showError({
    required BuildContext context,
    required String title,
    String? message,
    String? buttonText,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppDialogWidget(
        type: AppDialogType.error,
        title: title,
        message: message,
        buttonText: buttonText ?? 'OK',
        icon: Icons.error_outline,
        iconColor: Colors.red,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Mostra um diálogo de informação
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    String? message,
    String? buttonText,
    IconData? icon,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppDialogWidget(
        type: AppDialogType.info,
        title: title,
        message: message,
        buttonText: buttonText ?? 'OK',
        icon: icon ?? Icons.info_outline,
        iconColor: AppTheme.primaryColor,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _AppDialogWidget extends StatelessWidget {
  final AppDialogType type;
  final String title;
  final String? message;
  final String? buttonText;
  final String? confirmText;
  final String? cancelText;
  final IconData icon;
  final Color iconColor;
  final Color? confirmColor;
  final VoidCallback? onDismiss;

  const _AppDialogWidget({
    required this.type,
    required this.title,
    this.message,
    this.buttonText,
    this.confirmText,
    this.cancelText,
    required this.icon,
    required this.iconColor,
    this.confirmColor,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirm = type == AppDialogType.confirm;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      // Limita largura máxima para não ficar muito largo em telas grandes
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),
            
            // Título
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Mensagem
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Botões
            if (isConfirm)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText ?? 'Cancelar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        onDismiss?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: confirmColor ?? Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText ?? 'Confirmar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDismiss?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText ?? 'OK',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}



