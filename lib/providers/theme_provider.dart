import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppColor { blue, teal, purple }

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppColor _appColor = AppColor.blue;

  ThemeMode get themeMode => _themeMode;
  AppColor get appColor => _appColor;

  ThemeProvider() {
    _loadThemeSettings();
  }

  ThemeData getTheme() {
    Color seedColor;
    switch (_appColor) {
      case AppColor.blue:
        seedColor = Colors.blue;
        break;
      case AppColor.teal:
        seedColor = Colors.teal;
        break;
      case AppColor.purple:
        seedColor = Colors.purple;
        break;
    }

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
    );
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeSettings();
    notifyListeners();
  }

  void setAppColor(AppColor color) {
    _appColor = color;
    _saveThemeSettings();
    notifyListeners();
  }

  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('themeMode') ?? 0;
      final appColorIndex = prefs.getInt('appColor') ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex.clamp(0, 2)];
      _appColor = AppColor.values[appColorIndex.clamp(0, 2)];
      notifyListeners();
    } catch (e) {
      // Use defaults if loading fails
    }
  }

  Future<void> _saveThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', _themeMode.index);
      await prefs.setInt('appColor', _appColor.index);
    } catch (e) {
      // Ignore save errors
    }
  }
}

