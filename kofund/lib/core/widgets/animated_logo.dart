import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showBackground;
  final Color backgroundColor;
  final bool loopAnimation;

  const AnimatedLogo({
    super.key,
    this.size = 90,
    this.showBackground = false,
    this.backgroundColor = Colors.transparent,
    this.loopAnimation = true,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800), // Snappier pop entrance
      vsync: this,
    );

    // ⭐ Scale effect: starts at 80% and goes to 100%
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack, // Gives it that slight premium 'bounce' feel
      ),
    );

    // ⭐ Opacity: fades from invisible to fully visible
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: CustomPaint(
            painter: const _SvgLogoPainter(),
          ),
        ),
      ),
    );
  }
}

/// 🎨 Static SVG Painter
class _SvgLogoPainter extends CustomPainter {
  const _SvgLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    /// 🔷 Polygon 1 (Dark)
    _drawPolygon(
      canvas,
      [
        Offset(89.84 / 96 * w, 0),
        Offset(23.76 / 96 * w, 66.63 / 90.59 * h),
        Offset(0, 90.59 / 90.59 * h),
        Offset(0, 15.9 / 90.59 * h),
        Offset(23.76 / 96 * w, 15.9 / 90.59 * h),
        Offset(23.76 / 96 * w, 47.01 / 90.59 * h),
        Offset(89.84 / 96 * w, 0),
      ],
      const Color(0xFF052224),
      Offset.zero,
    );

    /// ⚪ Polygon 2 (Bottom White)
    _drawPolygon(
      canvas,
      [
        Offset(84.66 / 96 * w, h),
        Offset(52.18 / 96 * w, h),
        Offset(31.7 / 96 * w, 69.71 / 90.59 * h),
        Offset(48.04 / 96 * w, 53.24 / 90.59 * h),
        Offset(84.66 / 96 * w, h),
      ],
      Colors.white,
      Offset.zero,
    );

    /// ⚪ Polygon 3 (Top White)
    _drawPolygon(
      canvas,
      [
        Offset(96 / 96 * w, 4.88 / 90.59 * h),
        Offset(67.69 / 96 * w, 60.18 / 90.59 * h),
        Offset(54.5 / 96 * w, 46.73 / 90.59 * h),
        Offset(96 / 96 * w, 4.88 / 90.59 * h),
      ],
      Colors.white,
      Offset.zero,
    );
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> points,
    Color color,
    Offset offset,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()..moveTo(points.first.dx + offset.dx, points.first.dy + offset.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx + offset.dx, points[i].dy + offset.dy);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SvgLogoPainter oldDelegate) => false;
}

