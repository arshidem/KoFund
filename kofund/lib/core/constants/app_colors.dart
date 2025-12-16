// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  /// 🌤 LIGHT THEME
  static const lightPrimary = Color(0xFF00BFA6);
  static const lightPrimaryGradientStart = Color(0xFF00C6A2);
  static const lightPrimaryGradientEnd = Color(0xFF00E3C3);
  static const lightBackground = Color(0xFFF0F8F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFDFDFD);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightTextPrimary = Color(0xFF1A2E2A);
  static const lightTextSecondary = Color(0xFF5F6B6B);
  static const lightTextTertiary = Color(0xFF8A9A9A);
  static const lightTextCards = Color(0xFF052224);
  static const lightRevenue = Color(0xFF00BFA6);
  static const lightExpense = Color(0xFFFF6B6B);
  static const lightBalance = Color(0xFF2196F3);
  static const lightSuccess = Color(0xFF00B75C);
  static const lightError = Color(0xFFF44336);
  static const lightWarning = Color(0xFFFFB300);
  static const lightInfo = Color(0xFF2196F3);
  static const lightProgressBackground = Color(0xFFE8F5F2);
  static const lightProgressFill = Color(0xFF00BFA6);

  /// 🌑 DARK THEME
  static const darkPrimary = Color(0xFF00E3C3);
  static const darkPrimaryGradientStart = Color(0xFF00796B);
  static const darkPrimaryGradientEnd = Color(0xFF004D40);
  static const darkBackground = Color(0xFF0D1B1A);
  static const darkCard = Color(0xFF162626);
  static const darkSurface = Color(0xFF1B2E2E);
  static const darkBorder = Color(0xFF2D3D3D);
  static const darkTextPrimary = Color(0xFFE0F2EF);
  static const darkTextSecondary = Color(0xFF9EB6B4);
  static const darkTextTertiary = Color(0xFF6B8A87);
  static const darkTextCards = Color(0xFFF1FFF3);
  static const darkRevenue = Color(0xFF00E3C3);
  static const darkExpense = Color(0xFFFF8A8A);
  static const darkBalance = Color(0xFF4FC3F7);
  static const darkSuccess = Color(0xFF32D47A);
  static const darkError = Color(0xFFFF6B6B);
  static const darkWarning = Color(0xFFFFCA28);
  static const darkInfo = Color(0xFF4FC3F7);
  static const darkProgressBackground = Color(0xFF1A2E2A);
  static const darkProgressFill = Color(0xFF00E3C3);

  /// 🆕 ADDED: Missing methods
  static Color cardBackground(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  
  static Color secondary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkPrimary : lightPrimary;

  /// Theme-aware color getters
  static Color primary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkPrimary : lightPrimary;
  
  static Color background(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;
  
  static Color card(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  
  static Color surface(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;
  
  static Color textPrimary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  
  static Color textSecondary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
  
  static Color textTertiary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkTextTertiary : lightTextTertiary;

  static Color textCards(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkTextCards : lightTextCards;
  
  static Color revenue(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkRevenue : lightRevenue;
  
  static Color expense(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkExpense : lightExpense;
  
  static Color balance(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkBalance : lightBalance;
  
  static Color success(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkSuccess : lightSuccess;
  
  static Color error(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkError : lightError;
  
  static Color warning(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkWarning : lightWarning;
  
  static Color info(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkInfo : lightInfo;
  
  static Color border(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;
  
  static Color progressBackground(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkProgressBackground : lightProgressBackground;
  
  static Color progressFill(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? darkProgressFill : lightProgressFill;

  /// Gradients
  static LinearGradient primaryGradient(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark 
          ? const LinearGradient(
              colors: [darkPrimaryGradientStart, darkPrimaryGradientEnd],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : const LinearGradient(
              colors: [lightPrimaryGradientStart, lightPrimaryGradientEnd],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );

  /// Static gradients for direct usage
  static const LinearGradient lightGradient = LinearGradient(
    colors: [lightPrimaryGradientStart, lightPrimaryGradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkPrimaryGradientStart, darkPrimaryGradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}