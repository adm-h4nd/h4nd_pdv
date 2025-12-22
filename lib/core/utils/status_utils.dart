import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/mesas/entidade_produtos.dart';

/// Utilitários para cores e formatação de status
class StatusUtils {
  /// Retorna a cor apropriada para o status de uma entidade (mesa ou comanda)
  static Color getStatusColor(String status, TipoEntidade tipo) {
    if (tipo == TipoEntidade.mesa) {
      switch (status.toLowerCase()) {
        case 'livre':
          return AppTheme.successColor;
        case 'ocupada':
          return AppTheme.warningColor;
        case 'reservada':
          return AppTheme.infoColor;
        case 'manutencao':
        case 'suspensa':
          return AppTheme.errorColor;
        default:
          return Colors.grey;
      }
    } else {
      // Comanda: Livre ou Em Uso
      switch (status.toLowerCase()) {
        case 'livre':
          return AppTheme.successColor;
        case 'em uso':
          return AppTheme.warningColor;
        default:
          return Colors.grey;
      }
    }
  }
}
