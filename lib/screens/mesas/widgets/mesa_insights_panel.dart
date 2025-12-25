import 'package:flutter/material.dart';
import '../../../data/models/mesa_alerta.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Painel de insights de alertas de mesas
/// Sempre visível, com legenda fixa e área expansível para lista de alertas
class MesaInsightsPanel extends StatefulWidget {
  final List<MesaAlerta> alertas;
  final bool isDesktop;

  const MesaInsightsPanel({
    super.key,
    required this.alertas,
    this.isDesktop = true,
  });

  @override
  State<MesaInsightsPanel> createState() => _MesaInsightsPanelState();
}

class _MesaInsightsPanelState extends State<MesaInsightsPanel> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final temAlertas = widget.alertas.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header fixo
          _buildHeader(temAlertas),
          
          // Legenda sempre visível
          _buildLegenda(),
          
          // Área expansível
          if (_expandido) _buildAreaExpansivel(temAlertas),
        ],
      ),
    );
  }

  Widget _buildHeader(bool temAlertas) {
    final contador = widget.alertas.length;
    final texto = temAlertas 
        ? '$contador ${contador == 1 ? 'alerta ativo' : 'alertas ativos'}'
        : 'Nenhum alerta no momento';

    return InkWell(
      onTap: () {
        setState(() {
          _expandido = !_expandido;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: temAlertas 
              ? Colors.orange.shade50 
              : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              size: 20,
              color: temAlertas 
                  ? Colors.orange.shade700 
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Insights de Mesas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: temAlertas 
                    ? Colors.orange.shade700 
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _expandido ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegenda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legenda:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildItemLegenda(
                icon: Icons.access_time,
                label: 'Tempo sem pedir',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildItemLegenda(
                icon: Icons.restaurant,
                label: 'Itens aguardando',
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemLegenda({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAreaExpansivel(bool temAlertas) {
    if (temAlertas) {
      return _buildListaAlertas();
    } else {
      return _buildMensagemExplicativa();
    }
  }

  Widget _buildListaAlertas() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.alertas.map((alerta) => _buildItemAlerta(alerta)),
        ],
      ),
    );
  }

  Widget _buildItemAlerta(MesaAlerta alerta) {
    final cor = alerta.tipo == TipoAlertaMesa.tempoSemPedir
        ? Colors.orange
        : Colors.red;
    
    final icon = alerta.tipo == TipoAlertaMesa.tempoSemPedir
        ? Icons.access_time
        : Icons.restaurant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: cor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mesa ${alerta.numeroMesa}: ${alerta.descricao}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMensagemExplicativa() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Esta área monitora alertas importantes:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemExplicacao(
            '• Mesas ocupadas sem pedir há muito tempo',
          ),
          _buildItemExplicacao(
            '• Itens de pedido aguardando entrega há muito tempo',
          ),
          const SizedBox(height: 8),
          Text(
            'Os alertas aparecem automaticamente quando detectados.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemExplicacao(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

