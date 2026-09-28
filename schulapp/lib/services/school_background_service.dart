import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SchoolBackgroundService {
  static const String _keySchoolId = 'current_school_id';
  static const String _keySchoolName = 'current_school_name';
  static const String _keySchoolType = 'current_schoo_type';
  static const String _keyBackgroundImage = 'school_background_image';
  static const String _keyHasLoggedInOnce = 'has_logged_in_once';
  static Future<bool> hasLoggedInOnce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasLoggedInOnce) ?? false;
  }
  static Future<String?> getSavedBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBackgroundImage);
  }
  static Future<String?> getSavedSchoolName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySchoolName);
  }
  static Future<String> getSavedSchoolType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySchoolType) ?? 'primary';
  }
  static Future<void> loadAndSaveBackground({
    required String schoolId,
    required String schoolName,
    required String schoolType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySchoolId, schoolId);
    await prefs.setString(_keySchoolName, schoolName);
    await prefs.setString(_keySchoolType, schoolType);
    await prefs.setBool(_keyHasLoggedInOnce, true);
    try {
      final data = await ApiService().getSchoolLoginBackground(schoolId);
      if (data != null && data['has_background'] == true && data['image_url'] != null) {
        await prefs.setString(_keyBackgroundImage, ApiService.fileUrl(data['image_url']));
      } else {
        await prefs.remove(_keyBackgroundImage);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Hintergrundbilds: $e');
    }
  }
  static Future<bool> isSchoolChanged(String newSchoolId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSchoolId = prefs.getString(_keySchoolId);
    return savedSchoolId != null && savedSchoolId != newSchoolId;
  }
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBackgroundImage);
  }
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySchoolId);
    await prefs.remove(_keySchoolName);
    await prefs.remove(_keyBackgroundImage);
    await prefs.remove(_keyHasLoggedInOnce);
  }  
}