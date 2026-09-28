import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();
  Map<String, dynamic> _localizedStrings = {};
  String _currentLocale = 'de';
  bool _isLoaded = false;
  String get currentLocale => _currentLocale;
  bool get isLoaded => _isLoaded;
  Future<void> loadLocale(String locale) async {
    _currentLocale = locale;
    try {
      String jsonString = await rootBundle.loadString('assets/lang/$locale.json');
      _localizedStrings = json.decode(jsonString);
      _isLoaded = true; 
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', locale);
      notifyListeners();
    } catch (e) {
      debugPrint('Fehler beim Laden der Sprache $locale: $e');
    }
  }
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('app_locale') ?? 'de';
    await loadLocale(savedLocale);
  }
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
  String t(String key) => translate(key);
}