import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Tipos de toast disponíveis
enum AppToastType {
  success,
  error,
  info,
  warning,
}

/// Componente global de toast/notificação que aparece e desaparece automaticamente
class AppToast {
  static OverlayEntry? _overlayEntry;
  static OverlayState? _overlayState;
  static bool _isShowing = false;

  /// Mostra um toast de sucesso
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(context, message, AppToastType.success, duration: duration);
  }

  /// Mostra um toast de erro
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context, message, AppToastType.error, duration: duration);
  }

  /// Mostra um toast de informação
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(context, message, AppToastType.info, duration: duration);
  }

  /// Mostra um toast de aviso
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(context, message, AppToastType.warning, duration: duration);
  }

  static void _show(
    BuildContext context,
    String message,
    AppToastType type, {
    required Duration duration,
  }) {
    // Remove toast anterior se existir
    if (_isShowing) {
      _hide();
    }

    _overlayState = Overlay.of(context);
    if (_overlayState == null) return;

    _isShowing = true;

    // Determinar cores e ícone baseado no tipo
    Color backgroundColor;
    Color textColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case AppToastType.success:
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        iconColor = Colors.white;
        break;
      case AppToastType.error:
        backgroundColor = Colors.red;
        textColor = Colors.white;
        icon = Icons.error;
        iconColor = Colors.white;
        break;
      case AppToastType.warning:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.warning;
        iconColor = Colors.white;
        break;
      case AppToastType.info:
        backgroundColor = AppTheme.primaryColor;
        textColor = Colors.white;
        icon = Icons.info;
        iconColor = Colors.white;
        break;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        icon: icon,
        iconColor: iconColor,
        onDismiss: _hide,
      ),
    );

    _overlayState!.insert(_overlayEntry!);

    // Auto-dismiss após a duração especificada
    Future.delayed(duration, () {
      if (_isShowing) {
        _hide();
      }
    });
  }

  static void _hide() {
    if (!_isShowing || _overlayEntry == null) return;

    _overlayEntry!.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.padding.top;

    return Positioned(
      top: safePadding + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        color: widget.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) {
                        widget.onDismiss();
                      });
                    },
                    child: Icon(
                      Icons.close,
                      color: widget.textColor.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}





