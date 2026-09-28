import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SchoolService {
  static const String _schoolIdKey = 'configured_school_id';
  static const String _schoolNameKey = 'configured_school_name';
  static const String _backgroundCacheKey = 'school_background_cache';
  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_schoolIdKey) != null;
  }
  static Future<String?> getSchoolId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_schoolIdKey);
  }
  static Future<void> setupSchool(String setupCode) async {
    final result = await ApiService().setupSchool(setupCode);
    if (result == null || result.containsKey('error')) {
      throw Exception(result?['error'] ?? 'Ungültiger Setup-Code');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schoolIdKey, result['school_id']);
    await prefs.setString(_schoolNameKey, result['school_name']);
    if (result['has_background'] == true) {
      await _loadAndCacheBackground(result['school_id']);
    }
  }
  static Future<void> _loadAndCacheBackground(String schoolId) async {
    final result = await ApiService().getSchoolLoginBackground(schoolId);
    if (result != null && result['image_url'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backgroundCacheKey, ApiService.fileUrl(result['image_url']));
    }
  }
  static Future<String?> getCachedBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundCacheKey);
  }
  
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_schoolIdKey);
    await prefs.remove(_schoolNameKey);
    await prefs.remove(_backgroundCacheKey);
  }
}