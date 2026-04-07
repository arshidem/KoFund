import 'package:flutter/material.dart';

class ThemeToggleSlider extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ThemeToggleSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? const Color(0xFF1E1E2C) : const Color(0xFFE0E0E0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Icons in background
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 14,
                    color: value ? Colors.grey.withValues(alpha: 0.3) : Colors.orangeAccent,
                  ),
                  Icon(
                    Icons.nightlight_round,
                    size: 14,
                    color: value ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
            
            // Sliding knob
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    value ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 16,
                    color: value ? Colors.indigo : Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
