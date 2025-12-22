import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/home/home_widget_type.dart';
import '../../data/models/home/home_widget_config.dart';

/// Tile/widget reutilizável para a home personalizável
class HomeWidgetTile extends StatelessWidget {
  final HomeWidgetType type;
  final VoidCallback onTap;
  final int? badgeCount; // Para mostrar badge de notificação
  final HomeWidgetSize size; // Tamanho do widget

  const HomeWidgetTile({
    super.key,
    required this.type,
    required this.onTap,
    this.badgeCount,
    this.size = HomeWidgetSize.medio,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    final config = _getWidgetConfig(type);
    final isMobile = adaptive?.isMobile ?? true;

    // Define dimensões baseado no tamanho
    final dimensions = _getDimensions(size, isMobile);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (config['color'] as Color).withOpacity(0.1),
        highlightColor: (config['color'] as Color).withOpacity(0.05),
        child: Container(
          width: isMobile ? double.infinity : dimensions['width'],
          height: dimensions['height'],
          padding: EdgeInsets.all(isMobile ? 20 : dimensions['padding'] as double),
          decoration: BoxDecoration(
            color: (config['color'] as Color).withOpacity(0.15), // Cor vibrante com opacidade
            border: Border.all(
              color: config['color'] as Color,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (config['color'] as Color).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: _buildContent(config, isMobile, dimensions),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> config, bool isMobile, Map<String, dynamic> dimensions) {
    final isGrande = size == HomeWidgetSize.grande;
    final isPequeno = size == HomeWidgetSize.pequeno;

    if (isGrande && !isMobile) {
      // Layout vertical para widgets grandes
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone grande
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (config['color'] as Color).withOpacity(0.2),
                ),
                child: Icon(
                  config['icon'] as IconData,
                  color: config['color'] as Color,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                config['title'] as String,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                config['subtitle'] as String,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Badge
          if (badgeCount != null && badgeCount! > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                ),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    // Layout horizontal para widgets pequenos e médios
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            // Ícone
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : (isPequeno ? 12 : 16)),
              decoration: BoxDecoration(
                color: (config['color'] as Color).withOpacity(0.2),
              ),
              child: Icon(
                config['icon'] as IconData,
                color: config['color'] as Color,
                size: isMobile ? 28 : (isPequeno ? 24 : 32),
              ),
            ),
            SizedBox(width: isMobile ? 20 : (isPequeno ? 16 : 24)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    config['title'] as String,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 18 : (isPequeno ? 16 : 20),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isPequeno) ...[
                    SizedBox(height: isMobile ? 8 : 10),
                    Text(
                      config['subtitle'] as String,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Seta
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: isMobile ? 16 : (isPequeno ? 14 : 18),
            ),
          ],
        ),
        // Badge de notificação
        if (badgeCount != null && badgeCount! > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ],
    );
  }

  Map<String, dynamic> _getDimensions(HomeWidgetSize size, bool isMobile) {
    if (isMobile) {
      return {'width': null, 'height': null, 'padding': 22.0};
    }

    switch (size) {
      case HomeWidgetSize.pequeno:
        return {'width': null, 'height': 120.0, 'padding': 18.0};
      case HomeWidgetSize.medio:
        return {'width': null, 'height': 140.0, 'padding': 22.0};
      case HomeWidgetSize.grande:
        return {'width': null, 'height': 280.0, 'padding': 28.0};
    }
  }

  Map<String, dynamic> _getWidgetConfig(HomeWidgetType type) {
    switch (type) {
      case HomeWidgetType.sincronizarProdutos:
        return {
          'title': 'Sincronizar Produtos',
          'subtitle': 'Atualizar produtos locais',
          'icon': Icons.sync,
          'color': AppTheme.primaryColor,
        };
      case HomeWidgetType.sincronizarVendas:
        return {
          'title': 'Sincronização de Pedidos',
          'subtitle': 'Pedidos pendentes',
          'icon': Icons.sync_problem,
          'color': AppTheme.warningColor,
        };
      case HomeWidgetType.mesas:
        return {
          'title': 'Mesas',
          'subtitle': 'Visualizar mesas',
          'icon': Icons.table_restaurant,
          'color': AppTheme.restauranteColor,
        };
      case HomeWidgetType.comandas:
        return {
          'title': 'Comandas',
          'subtitle': 'Gerenciar comandas',
          'icon': Icons.receipt_long,
          'color': AppTheme.infoColor,
        };
      case HomeWidgetType.configuracoes:
        return {
          'title': 'Configurações',
          'subtitle': 'Ajustes do sistema',
          'icon': Icons.settings,
          'color': AppTheme.textSecondary,
        };
      case HomeWidgetType.perfil:
        return {
          'title': 'Perfil',
          'subtitle': 'Meus dados',
          'icon': Icons.person,
          'color': AppTheme.primaryColor,
        };
      case HomeWidgetType.realizarPedido:
        return {
          'title': 'Realizar Pedido',
          'subtitle': 'Nova venda rápida',
          'icon': Icons.add_shopping_cart,
          'color': AppTheme.successColor,
        };
      case HomeWidgetType.patio:
        return {
          'title': 'Pátio',
          'subtitle': 'Visualizar pátio',
          'icon': Icons.directions_car,
          'color': AppTheme.oficinaColor,
        };
      case HomeWidgetType.pedidos:
        return {
          'title': 'Pedidos',
          'subtitle': 'Listar pedidos',
          'icon': Icons.receipt_long,
          'color': AppTheme.varejoColor,
        };
    }
  }
}

