import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

class MilestoneCelebrationOverlay extends StatefulWidget {
  final Widget child;

  const MilestoneCelebrationOverlay({
    super.key,
    required this.child,
  });

  @override
  MilestoneCelebrationOverlayState createState() => MilestoneCelebrationOverlayState();
}

class MilestoneCelebrationOverlayState extends State<MilestoneCelebrationOverlay> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  /// Triggers the Haptic feedback, Confetti burst, and the Card Ripple effect.
  void triggerCelebration() {
    HapticHelper.success();
    _confettiController.play();
    _rippleController.forward(from: 0.0);
  }

  // A custom path to draw star-shaped confetti
  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
        Positioned(
          top: -20,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive, // Explosive burst like fireworks
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.amber,
              Colors.cyan,
            ],
            createParticlePath: drawStar,
            numberOfParticles: 50, // More particles for premium feel
            gravity: 0.15, // Slightly faster descent for more energy
          ),
        ),
      ],
    );
  }
}





