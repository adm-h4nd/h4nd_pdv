import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/adaptive_layout/adaptive_layout.dart';
import '../core/theme/app_theme.dart';

/// Componente padronizado de cabeçalho/AppBar para toda a aplicação
/// 
/// Suporta diferentes variações:
/// - AppBar padrão com título simples
/// - Header customizado com subtítulo e badges
/// - Header com ações (botões, ícones)
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Título principal do cabeçalho
  final String title;
  
  /// Subtítulo opcional (ex: "Em edição", status, etc)
  final String? subtitle;
  
  /// Cor de fundo do cabeçalho
  final Color? backgroundColor;
  
  /// Cor do texto e ícones
  final Color? foregroundColor;
  
  /// Se deve mostrar botão de voltar
  final bool showBackButton;
  
  /// Callback quando o botão de voltar é pressionado
  final VoidCallback? onBackPressed;
  
  /// Widgets adicionais no final do cabeçalho (ações, badges, etc)
  final List<Widget>? actions;
  
  /// Widgets customizados antes do título (ex: ícones, avatares)
  final Widget? leading;
  
  /// Se deve usar estilo compacto (menor altura)
  final bool compact;
  
  /// Badges/tags customizados para exibir após o subtítulo
  final List<Widget>? badges;
  
  /// Se deve usar estilo de AppBar padrão (mais simples) ou customizado (mais detalhado)
  final bool useSimpleStyle;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.backgroundColor,
    this.foregroundColor,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.compact = false,
    this.badges,
    this.useSimpleStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    // Padrão: fundo branco e texto escuro para consistência visual
    final bgColor = backgroundColor ?? Colors.white;
    final fgColor = foregroundColor ?? AppTheme.textPrimary;
    
    if (useSimpleStyle) {
      return _buildSimpleAppBar(context, bgColor, fgColor);
    }
    
    return _buildCustomHeader(context, adaptive, bgColor, fgColor);
  }

  Widget _buildSimpleAppBar(BuildContext context, Color bgColor, Color fgColor) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      leading: showBackButton && onBackPressed != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
              color: fgColor,
            )
          : null,
      actions: actions,
    );
  }

  Widget _buildCustomHeader(
    BuildContext context,
    AdaptiveLayoutProvider? adaptive,
    Color bgColor,
    Color fgColor,
  ) {
    final padding = adaptive?.getPadding() ?? 16.0;
    final height = compact ? 70.0 : 76.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              // Leading (botão voltar estilizado ou widget customizado)
              if (showBackButton || leading != null)
                leading ??
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBackPressed ?? () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
              if (showBackButton || leading != null) SizedBox(width: compact ? 10 : 14),
              
              // Conteúdo principal (título e subtítulo)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: compact ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: fgColor,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: compact ? 4 : 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Row(
                          children: [
                            if (subtitle!.toLowerCase().contains('edição') ||
                                subtitle!.toLowerCase().contains('sincronizando'))
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(subtitle!),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusColor(subtitle!).withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            if (subtitle!.toLowerCase().contains('edição') ||
                                subtitle!.toLowerCase().contains('sincronizando'))
                              const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subtitle!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: compact ? 12 : 13,
                                  color: fgColor.withOpacity(0.75),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Badges customizados
                    if (badges != null && badges!.isNotEmpty) ...[
                      SizedBox(height: compact ? 4 : 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: badges!,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions (botões, ícones, etc)
              if (actions != null && actions!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!
                      .map((action) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: action,
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String subtitle) {
    if (subtitle.toLowerCase().contains('edição') ||
        subtitle.toLowerCase().contains('sincronizando')) {
      return Colors.green;
    }
    if (subtitle.toLowerCase().contains('erro') ||
        subtitle.toLowerCase().contains('falha')) {
      return Colors.red;
    }
    if (subtitle.toLowerCase().contains('pendente')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  @override
  Size get preferredSize {
    if (useSimpleStyle) {
      return const Size.fromHeight(kToolbarHeight);
    }
    return Size.fromHeight(compact ? 70.0 : 76.0);
  }
}
