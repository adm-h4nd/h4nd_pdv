import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF8FAFC),
                const Color(0xFFF1F5F9),
                Colors.white,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _BackgroundPainter(_controller.value),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animationValue;

  _BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Círculos animados de fundo
    final colors = [
      const Color(0xFF00A8E8).withValues(alpha: 0.03),
      const Color(0xFF10B981).withValues(alpha: 0.02),
      const Color(0xFFF59E0B).withValues(alpha: 0.02),
    ];

    for (var i = 0; i < 3; i++) {
      final offset = Offset(
        size.width * (0.2 + i * 0.3) +
            (size.width * 0.1 * (animationValue * 2 - 1)),
        size.height * (0.3 + i * 0.2) +
            (size.height * 0.1 * ((animationValue + i * 0.3) % 1 - 0.5)),
      );

      paint.color = colors[i % colors.length];
      canvas.drawCircle(offset, size.width * 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

