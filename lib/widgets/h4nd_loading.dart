import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

/// Widget de loading personalizado com logo H4ND
/// 
/// Características:
/// - Logo H4ND centralizada (4 verde, resto azul)
/// - Anel circular girando (azul → verde)
/// - Letras com pulso sequencial
/// - O "4" verde com brilho pulsante mais forte
/// - "solutions" aparece com fade-in suave
class H4ndLoading extends StatefulWidget {
  /// Tamanho do loading (padrão: 80)
  final double size;
  
  /// Cor azul para as letras (padrão: AppTheme.infoColor)
  final Color? blueColor;
  
  /// Cor verde para o "4" (padrão: AppTheme.accentColor)
  final Color? greenColor;
  
  /// Se deve mostrar o texto "solutions" abaixo (padrão: true)
  final bool showSolutions;
  
  /// Mensagem opcional abaixo do loading
  final String? message;

  const H4ndLoading({
    super.key,
    this.size = 80,
    this.blueColor,
    this.greenColor,
    this.showSolutions = true,
    this.message,
  });

  @override
  State<H4ndLoading> createState() => _H4ndLoadingState();
}

class _H4ndLoadingState extends State<H4ndLoading>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _lettersAppearController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Controller para rotação do anel
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Controller para pulso sequencial das letras
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Controller para fade-in do "solutions"
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    // Controller para brilho pulsante do "4"
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Controller para animação de letras aparecendo sequencialmente
    _lettersAppearController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Animação de pulso
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Animação de fade-in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );

    // Animação de brilho do "4"
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    _lettersAppearController.dispose();
    super.dispose();
  }

  /// Calcula o delay para cada letra no pulso sequencial
  double _getLetterDelay(int index) {
    // H=0, 4=1, N=2, D=3
    return index * 0.25; // Cada letra pulsa com 25% de delay
  }

  /// Calcula a opacidade e escala para cada letra aparecer sequencialmente
  double _getLetterAppearOpacity(int index) {
    final delay = index * 0.2; // Cada letra aparece com 20% de delay
    final progress = (_lettersAppearController.value + delay) % 1.0;
    
    if (progress < 0.3) {
      // Aparece: 0 → 1 em 30% do tempo
      return (progress / 0.3).clamp(0.0, 1.0);
    } else {
      // Fica visível no resto
      return 1.0;
    }
  }

  double _getLetterAppearScale(int index) {
    final delay = index * 0.2;
    final progress = (_lettersAppearController.value + delay) % 1.0;
    
    if (progress < 0.3) {
      // Escala de 0.5 → 1.0 enquanto aparece
      return 0.5 + ((progress / 0.3) * 0.5);
    } else {
      return 1.0;
    }
  }

  /// Calcula o valor de pulso para cada letra
  double _getLetterPulse(int index) {
    final delay = _getLetterDelay(index);
    final progress = (_pulseController.value + delay) % 1.0;
    
    // Pulso mais suave: vai de 0.95 a 1.0 e volta (reduzido para evitar overflow)
    if (progress < 0.5) {
      return 0.95 + (progress * 0.1); // 0.95 → 1.0
    } else {
      return 1.0 - ((progress - 0.5) * 0.1); // 1.0 → 0.95
    }
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = widget.blueColor ?? AppTheme.infoColor;
    final greenColor = widget.greenColor ?? AppTheme.accentColor;
    final fontSize = widget.size * 0.28; // Reduzido ainda mais para garantir que caiba
    final solutionsFontSize = widget.size * 0.15;

    // Círculo principal (sempre renderizado)
    final circleWidget = SizedBox(
      width: widget.size,
      height: widget.size,
      child: OverflowBox(
        maxWidth: widget.size,
        maxHeight: widget.size,
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              // Anel circular girando (azul → verde)
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return ClipRect(
                  clipBehavior: Clip.hardEdge,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _RotatingRingPainter(
                      progress: _rotationController.value,
                      blueColor: blueColor,
                      greenColor: greenColor,
                    ),
                  ),
                );
                },
              ),

              // Logo H4ND com pulso sequencial e aparecimento sequencial
              AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _lettersAppearController]),
                builder: (context, child) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.all(widget.size * 0.15), // Padding aumentado
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      // H
                      _buildLetterWithAppear(
                        'H',
                        blueColor,
                        _getLetterPulse(0),
                        fontSize,
                        0,
                      ),
                      // 4 (verde com brilho)
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return _buildLetterWithAppear(
                            '4',
                            greenColor,
                            _getLetterPulse(1) * (1.0 + _glowAnimation.value * 0.08),
                            fontSize,
                            1,
                            glowIntensity: _glowAnimation.value,
                          );
                        },
                      ),
                      // N
                      _buildLetterWithAppear(
                        'N',
                        blueColor,
                        _getLetterPulse(2),
                        fontSize,
                        2,
                      ),
                      // D
                      _buildLetterWithAppear(
                        'D',
                        blueColor,
                        _getLetterPulse(3),
                        fontSize,
                        3,
                      ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    // Se não tem conteúdo extra, retorna apenas o círculo
    if (!widget.showSolutions && widget.message == null) {
      return circleWidget;
    }

    // Se tem conteúdo extra, usa Column com FittedBox para garantir que nunca ultrapasse
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          circleWidget,

          // Texto "solutions" com fade-in
          if (widget.showSolutions) ...[
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'solutions',
                style: GoogleFonts.inter(
                  fontSize: solutionsFontSize,
                  fontWeight: FontWeight.w500,
                  color: blueColor.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],

          // Mensagem opcional
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                widget.message!,
                style: GoogleFonts.inter(
                  fontSize: widget.size * 0.12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Constrói uma letra com pulso
  Widget _buildLetter(
    String letter,
    Color color,
    double scale,
    double fontSize, {
    double glowIntensity = 0.0,
  }) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Container(
        decoration: glowIntensity > 0
            ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(glowIntensity * 0.5),
                        blurRadius: 4 * glowIntensity, // Reduzido de 8 para 4
                        spreadRadius: 0, // Removido spreadRadius para evitar overflow
                      ),
                    ],
              )
            : null,
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w600, // Reduzido de w900 para w600
            color: color,
            letterSpacing: 0, // Ajustado de -1 para 0
            height: 1.0,
          ),
        ),
      ),
      ),
    );
  }

  /// Constrói uma letra com pulso e animação de aparecimento sequencial
  Widget _buildLetterWithAppear(
    String letter,
    Color color,
    double scale,
    double fontSize,
    int index, {
    double glowIntensity = 0.0,
  }) {
    final appearOpacity = _getLetterAppearOpacity(index);
    final appearScale = _getLetterAppearScale(index);
    
    return Opacity(
      opacity: appearOpacity,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: Transform.scale(
          scale: scale * appearScale,
          alignment: Alignment.center,
          child: Text(
            letter,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0,
              height: 1.0,
              shadows: glowIntensity > 0
                  ? [
                      Shadow(
                        color: color.withOpacity(glowIntensity * 0.6),
                        blurRadius: 6 * glowIntensity,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter para o anel circular girando
class _RotatingRingPainter extends CustomPainter {
  final double progress;
  final Color blueColor;
  final Color greenColor;

  _RotatingRingPainter({
    required this.progress,
    required this.blueColor,
    required this.greenColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Garantir que não desenhamos fora dos limites
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final center = Offset(size.width / 2, size.height / 2);
    // Aumentado o anel: reduzido de -2 para -1, mas garantindo que não ultrapasse
    // Usamos strokeWidth/2 para garantir que o anel fique dentro dos limites
    final strokeWidth = 3.5;
    final radius = size.width / 2 - strokeWidth / 2 - 2; // Margem extra para garantir que fique dentro

    // Cria gradiente que gira
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Calcula posições do gradiente baseado no progresso
    final startAngle = progress * 2 * 3.14159;
    final sweepAngle = 3.14159; // 180 graus

    // Cria arco com gradiente azul → verde → azul
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Primeira metade: azul → verde
    paint.shader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        blueColor,
        greenColor,
      ],
      tileMode: TileMode.clamp,
    ).createShader(rect);
    
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Segunda metade: verde → azul
    paint.shader = SweepGradient(
      startAngle: startAngle + sweepAngle,
      endAngle: startAngle + 2 * sweepAngle,
      colors: [
        greenColor,
        blueColor,
      ],
      tileMode: TileMode.clamp,
    ).createShader(rect);
    
    canvas.drawArc(
      rect,
      startAngle + sweepAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RotatingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.blueColor != blueColor ||
        oldDelegate.greenColor != greenColor;
  }
}

/// Overlay de loading fullscreen com fundo embaçado
/// 
/// Similar ao GlobalLoadingOverlay do Angular, mas usando H4ND loading
/// 
/// Uso:
/// ```dart
/// Stack(
///   children: [
///     // Seu conteúdo aqui
///     H4ndLoadingOverlay(show: isLoading, message: 'Carregando...'),
///   ],
/// )
/// ```
class H4ndLoadingOverlay extends StatelessWidget {
  /// Se deve mostrar o overlay
  final bool show;
  
  /// Mensagem opcional abaixo do loading
  final String? message;
  
  /// Cor de fundo do overlay (padrão: rgba(0, 0, 0, 0.5))
  final Color? backgroundColor;
  
  /// Se deve aplicar blur no fundo (padrão: true)
  final bool blurBackground;
  
  /// Tamanho do loading (padrão: 80)
  final double size;

  const H4ndLoadingOverlay({
    super.key,
    required this.show,
    this.message,
    this.backgroundColor,
    this.blurBackground = true,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: backgroundColor ?? Colors.black.withOpacity(0.5),
        child: blurBackground
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: _buildContent(),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: H4ndLoading(
          size: size,
          showSolutions: true,
          message: message,
        ),
      ),
    );
  }
}

/// Versão compacta do loading para uso em botões e espaços pequenos
/// 
/// Não mostra "solutions" e tem tamanho menor
class H4ndLoadingCompact extends StatelessWidget {
  /// Tamanho do loading (padrão: 24)
  final double size;
  
  /// Cor azul para as letras (padrão: AppTheme.infoColor)
  final Color? blueColor;
  
  /// Cor verde para o "4" (padrão: AppTheme.accentColor)
  final Color? greenColor;

  const H4ndLoadingCompact({
    super.key,
    this.size = 24,
    this.blueColor,
    this.greenColor,
  });

  @override
  Widget build(BuildContext context) {
    return H4ndLoading(
      size: size,
      blueColor: blueColor,
      greenColor: greenColor,
      showSolutions: false,
    );
  }
}

