import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela de listagem de pedidos
/// Esta tela será substituída por telas específicas por setor:
/// - restaurante/pedidos_restaurante_list_screen.dart
/// - varejo/pedidos_varejo_list_screen.dart
class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeader(
        title: 'Pedidos',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.varejoColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Text(
            'Tela de Pedidos\n(Em desenvolvimento)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
