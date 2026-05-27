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
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _breathController;
  
  late Animation<double> _scaleEntrance;
  late Animation<double> _opacityEntrance;
  
  late Animation<double> _breathScale;
  late Animation<double> _breathOpacity;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Animation
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleEntrance = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityEntrance = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeIn,
      ),
    );

    // 2. Continuous Breathing Animation (Subtle)
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _breathScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOutSine,
      ),
    );

    _breathOpacity = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOutSine,
      ),
    );

    _entranceController.forward().then((_) {
      if (widget.loopAnimation && mounted) {
        _breathController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double logoBgSize = widget.size * 1.888888; // 90 * 1.888888 = 170
    return SizedBox(
      width: widget.size * 5.0, // Much larger to ensure waves are not clipped
      height: widget.size * 5.0,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌊 Waves/Ripples (Only if loopAnimation is true)
            if (widget.loopAnimation)
              ...List.generate(3, (index) {
                return _WaveCircle(
                  delay: index * 0.4, // Staggered start
                  size: widget.showBackground ? logoBgSize : widget.size,
                  color: const Color(0xFF00BFA6),
                );
              }),

            // 🟢 Solid rounded background container (on top of waves, under the logo)
            if (widget.showBackground)
              Container(
                width: logoBgSize,
                height: logoBgSize,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 50,
                      spreadRadius: 6,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),

            // 🚀 The Logo itself
            AnimatedBuilder(
              animation: Listenable.merge([_entranceController, _breathController]),
              builder: (context, child) {
                final currentScale = _scaleEntrance.value * _breathScale.value;
                final currentOpacity = _opacityEntrance.value * _breathOpacity.value;

                return Opacity(
                  opacity: currentOpacity,
                  child: Transform.scale(
                    scale: currentScale,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: const _SvgLogoPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🌊 A single ripple wave that scales and fades
class _WaveCircle extends StatefulWidget {
  final double delay;
  final double size;
  final Color color;

  const _WaveCircle({
    required this.delay,
    required this.size,
    required this.color,
  });

  @override
  State<_WaveCircle> createState() => _WaveCircleState();
}

class _WaveCircleState extends State<_WaveCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );

    _startWithDelay();
  }

  Future<void> _startWithDelay() async {
    final milliseconds = (widget.delay * 1000).toInt();
    if (milliseconds > 0) {
      await Future.delayed(Duration(milliseconds: milliseconds));
    }
    if (mounted) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: (1.0 - _animation.value) * 0.4,
          child: Transform.scale(
            scale: 1.0 + (_animation.value * 0.8),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
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

    // Use theme-aware colors for the logo parts if needed, 
    // but typically a logo has its specific brand colors.
    // Based on previous search, the main part is very dark.
    
    /// 🔷 Polygon 1 (Dark Branding)
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
      const Color(0xFF052224), // Original Dark
      Offset.zero,
    );

    /// ⚪ Polygon 2 (White Accents)
    _drawPolygon(
      canvas,
      [
        Offset(84.66 / 96 * w, h),
        Offset(52.18 / 96 * w, h),
        Offset(31.7 / 96 * w, 69.71 / 90.59 * h),
        Offset(48.04 / 96 * w, 53.24 / 90.59 * h),
        Offset(84.66 / 96 * w, h),
      ],
      Colors.white, // Original White
      Offset.zero,
    );

    /// ⚪ Polygon 3 (Top White Accent)
    _drawPolygon(
      canvas,
      [
        Offset(96 / 96 * w, 4.88 / 90.59 * h),
        Offset(67.69 / 96 * w, 60.18 / 90.59 * h),
        Offset(54.5 / 96 * w, 46.73 / 90.59 * h),
        Offset(96 / 96 * w, 4.88 / 90.59 * h),
      ],
      Colors.white, // Original White
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






