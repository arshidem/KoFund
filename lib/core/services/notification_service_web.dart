// lib/core/services/notification_service_web.dart
// Web-specific implementation using dart:js
// This file is ONLY imported when compiling for web (see notification_service.dart's
// conditional import). It must never be reachable from an Android/iOS build.
import 'dart:js' as js;

class WebNotificationHelper {
  static bool checkWebNotificationSupport() {
    try {
      final hasNotification = js.context.hasProperty('Notification');
      if (!hasNotification) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> requestWebNotificationPermission() async {
    try {
      final notification = js.context['Notification'];
      if (notification == null) return null;

      final currentPermission = notification['permission'] as String?;
      if (currentPermission == 'granted') return 'granted';
      if (currentPermission == 'denied') return 'denied';

      final result = await js.context.callMethod('Notification.requestPermission');
      return result as String?;
    } catch (e) {
      return null;
    }
  }
}