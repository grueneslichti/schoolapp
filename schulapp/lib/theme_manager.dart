import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _colorBlindMode = false;
  ThemeMode get themeMode => _themeMode;
  bool get colorBlindMode => _colorBlindMode;
  ThemeManager() {
    _loadSettings();
  }
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _colorBlindMode = prefs.getBool('colorBlindMode') ?? false;
    notifyListeners();
  }
  Future<void> toggleDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  Future<void> toggleColorBlindMode(bool isColorBlind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('colorBlindMode', isColorBlind);
    _colorBlindMode = isColorBlind;
    notifyListeners();
  }
  Color getColor(String key) {
    if (_colorBlindMode) {
      switch (key) {
        case 'success': return Colors.blue.shade700;
        case 'danger': return const Color.fromARGB(255, 173, 1, 122);
        case 'warning': return Colors.yellow.shade800;
        case 'accent': return Colors.purple.shade700;
        default: return Colors.blueGrey.shade700;
      }
    } else {
      switch (key) {
        case 'success': return Colors.green.shade400;
        case 'danger': return Colors.red.shade400;
        case 'warning': return Colors.orange.shade400;
        case 'accent': return Colors.purple.shade400;
        default: return Colors.blue.shade400;
      }
    }
  }
}
final themeManager = ThemeManager();