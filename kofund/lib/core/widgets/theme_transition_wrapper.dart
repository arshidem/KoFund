import 'package:flutter/material.dart';

class ThemeTransitionWrapper extends StatefulWidget {
  final Widget child;
  final bool isDarkMode;

  const ThemeTransitionWrapper({
    super.key,
    required this.child,
    required this.isDarkMode,
  });

  @override
  State<ThemeTransitionWrapper> createState() => _ThemeTransitionWrapperState();
}

class _ThemeTransitionWrapperState extends State<ThemeTransitionWrapper> {

  @override
  Widget build(BuildContext context) {
    // Flutter's native MaterialApp automatically handles smooth interpolation
    // between theme colors. Removing AnimatedSwitcher prevents the full-screen 
    // flash and fade effect when toggling between light and dark modes.
    return widget.child;
  }
}
