// lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;
  bool get isDarkMode => _isDarkMode;

  /// [initialDarkMode] is pre-loaded from SharedPreferences in main() BEFORE
  /// runApp, so the very first frame already has the correct theme.
  ThemeProvider({bool initialDarkMode = false}) : _isDarkMode = initialDarkMode;

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
}





