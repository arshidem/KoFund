// lib/core/services/notification_service_stub.dart
// Default implementation for non-web platforms (Android/iOS).
// Contains no dart:js usage so it compiles safely outside the browser.

class WebNotificationHelper {
  static bool checkWebNotificationSupport() {
    // Not applicable on mobile platforms.
    return false;
  }

  static Future<String?> requestWebNotificationPermission() async {
    // Not applicable on mobile platforms.
    return null;
  }
}