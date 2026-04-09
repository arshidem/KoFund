import 'package:flutter/services.dart';

class HapticHelper {
  /// A subtle tactile click, perfect for toggles and small buttons.
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// A standard interaction tap feedback.
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// A strong feedback for destructive or high-stakes actions.
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// A short vibration sequence for successful completions.
  static Future<void> success() async {
    // Note: Standard success feedback is one short vibration
    await HapticFeedback.vibrate();
  }

  /// A distinct click, primarily used for selection changes.
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
