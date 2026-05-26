import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class AppUpdateService {
  static final _fs = FirebaseFirestore.instance;

  /// Compares current app version to Firestore config.
  /// Returns update info map if update is available, null if up to date.
  ///
  /// Firestore path: app_config/config
  /// Required fields: latest_version, min_supported_version, download_url, update_message
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      debugPrint('📱 Current app version: $currentVersion');

      final doc = await _fs.collection('app_config').doc('config').get();
      if (!doc.exists) {
        debugPrint('⚠️ No app_config/config found in Firestore');
        return null;
      }

      final data = doc.data()!;
      final latestVersion = data['latest_version'] as String? ?? '';
      final minVersion = data['min_supported_version'] as String? ?? '0.0.0';

      debugPrint('🏢 Latest version: $latestVersion, Min supported: $minVersion');

      if (!_isNewerVersion(latestVersion, currentVersion)) {
        debugPrint('✅ App is up to date');
        return null;
      }

      return {
        'has_update': true,
        'is_forced': _isOlderThan(currentVersion, minVersion),
        'download_url': data['download_url'] ?? '',
        'message': data['update_message'] ?? 'A new version of KoFund is available.',
        'latest_version': latestVersion,
      };
    } catch (e) {
      debugPrint('❌ Error checking for app update: $e');
      // Silently fail — never block app launch due to update check errors
      return null;
    }
  }

  static Future<void> openDownloadLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('❌ Could not launch URL: $url');
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
    }
  }

  /// Returns true if [latest] is strictly newer than [current]
  static bool _isNewerVersion(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  /// Returns true if [current] is strictly older than [min]
  static bool _isOlderThan(String current, String min) {
    final c = _parse(current);
    final m = _parse(min);
    for (int i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String version) {
    try {
      // Remove build number if present (e.g., 1.1.0+1 -> 1.1.0)
      final cleanVersion = version.split('+').first;
      final parts = cleanVersion.split('.');
      return [
        if (parts.isNotEmpty) int.tryParse(parts[0]) ?? 0 else 0,
        if (parts.length > 1) int.tryParse(parts[1]) ?? 0 else 0,
        if (parts.length > 2) int.tryParse(parts[2]) ?? 0 else 0,
      ];
    } catch (_) {
      return [0, 0, 0];
    }
  }
}





