import 'package:flutter/material.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

class PremiumSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? activeIcon;
  final IconData? inactiveIcon;
  final Color? activeColor;
  final Color? inactiveColor;

  const PremiumSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeIcon,
    this.inactiveIcon,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onChanged != null;
    
    return GestureDetector(
      onTap: isEnabled ? () {
        HapticHelper.selection();
        onChanged!(!value);
      } : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: value 
                ? (activeColor ?? const Color(0xFF00D2B4)) 
                : (inactiveColor ?? (isDark ? Colors.white10 : Colors.black12)),
            boxShadow: [
              if (!isDark || value)
                BoxShadow(
                  color: (value ? (activeColor ?? const Color(0xFF00D2B4)) : Colors.black)
                      .withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: (activeIcon != null || inactiveIcon != null)
                      ? Center(
                          child: Icon(
                            value ? activeIcon : inactiveIcon,
                            size: 14,
                            color: value 
                                ? (activeColor ?? const Color(0xFF00D2B4)) 
                                : Colors.grey,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





