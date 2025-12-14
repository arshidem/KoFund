import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showBackground;
  final Color backgroundColor;
  final bool loopAnimation;

  const AnimatedLogo({
    Key? key,
    this.size = 150,
    this.showBackground = false,
    this.backgroundColor = Colors.transparent,
    this.loopAnimation = true,
  }) : super(key: key);

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> poly1;
  late Animation<double> poly2;
  late Animation<double> poly3;
  late Animation<double> scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    poly1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    poly2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    poly3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    if (widget.loopAnimation) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 600), () {
            _controller.reset();
            _controller.forward();
          });
        }
      });
    }
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Transform.scale(
            scale: scale.value,
            child: CustomPaint(
              painter: _SvgLogoPainter(
                poly1: poly1.value,
                poly2: poly2.value,
                poly3: poly3.value,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 🎨 SVG Painter (1:1 with your SVG)
class _SvgLogoPainter extends CustomPainter {
  final double poly1;
  final double poly2;
  final double poly3;

  _SvgLogoPainter({
    required this.poly1,
    required this.poly2,
    required this.poly3,
  });

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
      const Color(0xFF052224).withOpacity(poly1),
      Offset(0, 10 * (1 - poly1)),
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
      Colors.white.withOpacity(poly2),
      Offset(5 * (1 - poly2), 5 * (1 - poly2)),
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
      Colors.white.withOpacity(poly3),
      Offset(-5 * (1 - poly3), -8 * (1 - poly3)),
    );
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> points,
    Color color,
    Offset offset,
  ) {
    final paint = Paint()..color = color;
    final path = Path()..moveTo(points.first.dx + offset.dx, points.first.dy + offset.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx + offset.dx, points[i].dy + offset.dy);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SvgLogoPainter oldDelegate) => true;
}
