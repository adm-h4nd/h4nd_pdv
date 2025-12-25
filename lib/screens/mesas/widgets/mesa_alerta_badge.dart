import 'package:flutter/material.dart';
import '../../../data/models/mesa_alerta.dart';
import '../../../core/theme/app_theme.dart';

/// Badge pequeno para indicar alertas nos cards de mesa
class MesaAlertaBadge extends StatelessWidget {
  final TipoAlertaMesa tipo;
  final String tooltip;
  final double size;

  const MesaAlertaBadge({
    super.key,
    required this.tipo,
    required this.tooltip,
    this.size = 20.0,
  });

  Color get _corAlerta {
    switch (tipo) {
      case TipoAlertaMesa.tempoSemPedir:
        return Colors.orange; // Laranja para tempo sem pedir
      case TipoAlertaMesa.itensAguardando:
        return Colors.red; // Vermelho para itens aguardando
    }
  }

  IconData get _iconAlerta {
    switch (tipo) {
      case TipoAlertaMesa.tempoSemPedir:
        return Icons.access_time;
      case TipoAlertaMesa.itensAguardando:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _corAlerta,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _corAlerta.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          _iconAlerta,
          size: size * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}

