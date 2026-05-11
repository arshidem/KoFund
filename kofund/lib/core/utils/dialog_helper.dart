import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';

class DialogHelper {
  /// Shows a premium confirmation dialog based on the modern redesign.
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    String title = 'Are you sure?',
    String message = 'This action cannot be undone. Please confirm if you want to proceed.',
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon = Icons.warning_rounded,
    bool isDestructive = false,
    Widget? content,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.4), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final primaryColor = AppColors.primary(context);
        final errorColor = AppColors.error(context);
        final badgeColor = isDestructive ? errorColor : primaryColor;
        
        return Dialog(
          backgroundColor: AppColors.card(context),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isDark 
                ? BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)
                : BorderSide.none,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Stack(
              children: [
                // Close button at top right
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary(context),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Central Badge Icon with PREMIUM DARK GLOW
                      _PulseIcon(
                        child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: badgeColor.withValues(alpha: isDark ? 0.5 : 0.3),
                                blurRadius: isDark ? 20 : 12,
                                spreadRadius: isDark ? 2 : 0,
                                offset: const Offset(0, 4),
                              ),
                              // Extra neon glow for dark mode
                              if (isDark)
                                BoxShadow(
                                  color: badgeColor.withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Ttitle
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Message or Custom Content
                      if (content != null) ...[
                        content,
                      ] else ...[
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary(context),
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          if (cancelLabel.isNotEmpty) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: isDark 
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : AppColors.border(context).withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  cancelLabel,
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          
                          // Confirm Button
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (isDark)
                                    BoxShadow(
                                      color: badgeColor.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: badgeColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  confirmLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: (isDark ? 8 : 4) * animation.value,
            sigmaY: (isDark ? 8 : 4) * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ).drive(Tween<double>(begin: 0.85, end: 1.0)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final Widget child;
  const _PulseIcon({required this.child});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}





