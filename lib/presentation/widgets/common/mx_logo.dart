import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show BackdropFilter, ImageFilter;

/// Widget da logo MX animada (igual ao frontend)
class MXLogo extends StatefulWidget {
  final double size;
  final bool animated;

  const MXLogo({
    super.key,
    this.size = 120,
    this.animated = true,
  });

  @override
  State<MXLogo> createState() => _MXLogoState();
}

class _MXLogoState extends State<MXLogo> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _particleController;
  late Animation<double> _glowAnimation;
  late List<Animation<double>> _particleAnimations;

  @override
  void initState() {
    super.initState();

    if (widget.animated) {
      // Animação de brilho do círculo
      _glowController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(begin: 0.4, end: 0.6).animate(
        CurvedAnimation(
          parent: _glowController,
          curve: Curves.easeInOut,
        ),
      );

      // Animação das partículas
      _particleController = AnimationController(
        duration: const Duration(seconds: 4),
        vsync: this,
      )..repeat();

      _particleAnimations = List.generate(3, (index) {
        final start = (index * 0.33).clamp(0.0, 1.0);
        final end = ((index * 0.33) + 0.5).clamp(0.0, 1.0); // Garante que end <= 1.0
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _particleController,
            curve: Interval(
              start,
              end,
              curve: Curves.easeInOut,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _glowController.dispose();
      _particleController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleSize = widget.size;
    final innerSize = circleSize * 0.8;
    final fontSize = circleSize * 0.25;

    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Partículas animadas
          if (widget.animated)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _particleAnimations[index],
                builder: (context, child) {
                  final progress = _particleAnimations[index].value;
                  final offsetY = math.sin(progress * math.pi * 2) * 8;
                  final scale = 1.0 + (math.sin(progress * math.pi * 2) * 0.2);
                  final opacity = 0.7 + (math.sin(progress * math.pi * 2) * 0.3);

                  // Posições das partículas
                  Offset position;
                  switch (index) {
                    case 0:
                      position = Offset(
                        circleSize * 0.3,
                        circleSize * 0.2,
                      );
                      break;
                    case 1:
                      position = Offset(
                        circleSize * 0.7,
                        circleSize * 0.5,
                      );
                      break;
                    default:
                      position = Offset(
                        circleSize * 0.25,
                        circleSize * 0.75,
                      );
                  }

                  return Positioned(
                    left: position.dx - 2,
                    top: position.dy + offsetY - 2,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00A8E8),
                                Color(0xFF0077B6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Círculo externo com gradiente
          AnimatedBuilder(
            animation: widget.animated ? _glowController : const AlwaysStoppedAnimation(0.5),
            builder: (context, child) {
              return Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00A8E8),
                      Color(0xFF0077B6),
                      Color(0xFF8BC34A),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(
                        widget.animated ? _glowAnimation.value : 0.5,
                      ),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                    child: Center(
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: innerSize,
                            height: innerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF00A8E8),
                                    Color(0xFF0077B6),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'MX',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}


