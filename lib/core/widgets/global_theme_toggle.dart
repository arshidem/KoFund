import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../constants/app_colors.dart';

class GlobalThemeToggle extends StatelessWidget {
  const GlobalThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Positioned(
      left: 16,
      bottom: 24, // Slightly higher to clear some bottom bars
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: FloatingActionButton.small(
          onPressed: () {
            themeProvider.toggleTheme(!isDarkMode);
            HapticFeedback.lightImpact();
          },
          backgroundColor: isDarkMode 
              ? const Color(0xFF1D2329) 
              : Colors.white,
          foregroundColor: isDarkMode 
              ? const Color(0xFF00E3C3) 
              : const Color(0xFF00BFA6),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isDarkMode ? const Color(0xFF00E3C3) : const Color(0xFF00BFA6)).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                ),
              );
            },
            child: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              key: ValueKey<bool>(isDarkMode),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}





