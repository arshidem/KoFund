import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Write a value to secure storage
  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure storage
  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return await _storage.read(key: key);
  }

  /// Delete a value from secure storage
  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _storage.delete(key: key);
  }

  /// Delete all values from secure storage
  Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kofund_auth_state');
      await prefs.remove('kofund_user_data');
      await prefs.remove('kofund_last_login');
      return;
    }
    await _storage.deleteAll();
  }

  /// Migrates data from SharedPreferences to SecureStorage if it exists
  /// This ensures existing users don't lose their sessions.
  Future<void> migrateFromSharedPrefs(List<String> keys) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          debugPrint('🔐 Migrating key "$key" to SecureStorage...');
          await write(key, value);
          await prefs.remove(key);
          debugPrint('✅ Migration complete for "$key"');
        }
      }
    } catch (e) {
      debugPrint('❌ Error during storage migration: $e');
    }
  }
}





