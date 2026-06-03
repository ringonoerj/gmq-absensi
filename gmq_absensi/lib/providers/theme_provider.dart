import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  final Box _cacheBox = Hive.box('gmq_cache');

  ThemeMode get themeMode {
    final storedValue = _cacheBox.get(_themeKey, defaultValue: 'light');
    switch (storedValue) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    String value;
    switch (mode) {
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
      case ThemeMode.light:
      default:
        value = 'light';
        break;
    }
    _cacheBox.put(_themeKey, value);
    notifyListeners();
  }

  void toggleTheme() {
    if (themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
