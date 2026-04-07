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
    // If the theme hasn't changed, just return the child
    // This allows normal rebuilds without triggering the switcher
    final themeUID = widget.isDarkMode ? 'dark' : 'light';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      // Custom transition that slides based on the direction
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Determine direction:
        // Light -> Dark: Slide from Left to Right (0.0 to 1.0)
        // Dark -> Light: Slide from Right to Left (0.0 to -1.0)
        
        final bool isMovingToDark = widget.isDarkMode;
        
        // We use a slide transition for the incoming widget
        // and optionally another for the outgoing
        final slideAnimation = animation.drive(
          Tween<Offset>(
            begin: isMovingToDark 
                ? const Offset(-1.0, 0.0) // Enter from left
                : const Offset(1.0, 0.0), // Enter from right
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        );

        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
      // Important to have a Stack layout so the old child stays visible while the new one slides in
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(themeUID),
        child: widget.child,
      ),
    );
  }
}
