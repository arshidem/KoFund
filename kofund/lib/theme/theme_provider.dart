// Theme provider 
import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  ThemeData get currentTheme => _themeMode == ThemeMode.dark 
      ? AppTheme.darkTheme() 
      : AppTheme.lightTheme();

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}