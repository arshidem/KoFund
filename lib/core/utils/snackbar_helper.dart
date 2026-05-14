// Snackbar utilities 
import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message) {
    _showBranded(context, message);
  }

  static void showError(BuildContext context, String message) {
    _showBranded(context, message); // Use global premium style
  }

  static void showInfo(BuildContext context, String message) {
    _showBranded(context, message);
  }

  static void showWarning(BuildContext context, String message) {
    _showBranded(context, message);
  }

  // Branded KoFund Snackbar logic
  static void showKoFundSnackbar(BuildContext context, String message, {Color? backgroundColor}) {
    _showBranded(context, message, backgroundColor: backgroundColor);
  }

  // Private helper to avoid duplication and globalize the style
  static void _showBranded(BuildContext context, String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Small KoFund Logo with Primary Background (Branding)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primary(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Transform.scale(
                scale: 1.6,
                child: Image.asset(
                  'assets/logos/KoFund.png',
                  height: 18,
                  width: 18,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Global Small Text Style
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? (Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF13181D) // Deeper premium dark
            : const Color(0xFF1D2329)), // Sleek charcoal
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Keep custom option for specialized use cases
  static void showCustom(BuildContext context, {
    required String message,
    Color? backgroundColor,
    Color? textColor,
    Color? actionColor,
    int durationSeconds = 3,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _showBranded(context, message, backgroundColor: backgroundColor);
  }
}
