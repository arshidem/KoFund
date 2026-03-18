// lib/core/constants/app_styles.dart
import 'package:flutter/material.dart';
import 'app_dimensions.dart';

class AppStyles {
  // Border Radii
  static BorderRadius radiusSmall = BorderRadius.circular(AppDimensions.radiusSmall);
  static BorderRadius radiusMedium = BorderRadius.circular(AppDimensions.radiusMedium);
  static BorderRadius radiusLarge = BorderRadius.circular(AppDimensions.radiusLarge);
  static BorderRadius radiusExtraLarge = BorderRadius.circular(AppDimensions.radiusExtraLarge);
  static BorderRadius radiusFull = BorderRadius.circular(AppDimensions.radiusFull);

  // Paddings
  static const EdgeInsets paddingSmall = EdgeInsets.all(AppDimensions.spaceSmall);
  static const EdgeInsets paddingMedium = EdgeInsets.all(AppDimensions.spaceMedium);
  static const EdgeInsets paddingLarge = EdgeInsets.all(AppDimensions.spaceLarge);
  
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: AppDimensions.screenPaddingHorizontal,
    vertical: AppDimensions.screenPaddingVertical,
  );

  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: AppDimensions.screenPaddingHorizontal,
  );

  // Spacing (Gaps)
  static const SizedBox gapSmall = SizedBox(height: AppDimensions.spaceSmall, width: AppDimensions.spaceSmall);
  static const SizedBox gapMedium = SizedBox(height: AppDimensions.spaceMedium, width: AppDimensions.spaceMedium);
  static const SizedBox gapLarge = SizedBox(height: AppDimensions.spaceLarge, width: AppDimensions.spaceLarge);

  // Common Decorations
  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: radiusLarge,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
