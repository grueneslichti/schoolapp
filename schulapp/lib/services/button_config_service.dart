import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ButtonConfig {
  final String id;
  final String label;
  final String iconKey;
  final Color color;
  bool isVisible;

  ButtonConfig({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.color,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'iconKey': iconKey,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'isVisible': isVisible,
    };
  }
  factory ButtonConfig.fromJson(Map<String, dynamic> json) {
    return ButtonConfig(
      id: json['id'],
      label: json['label'],
      iconKey: json['iconKey'],
      color: _parseColor(json['color']),
      isVisible: json['isVisible'] ?? true,
    );
  }

  static Color _parseColor(String colorString) {
    final hex = colorString.replaceFirst('#', '');
    final value = int.parse(hex, radix: 16);
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return Color.fromARGB(a, r, g, b);
  }
}
class ButtonConfigService extends ChangeNotifier {
  static final ButtonConfigService _instance = ButtonConfigService._internal();
  factory ButtonConfigService() => _instance;
  ButtonConfigService._internal();
  static const String _studentStorageKey = 'student_button_configuration';
  static const String _teacherStorageKey = 'teacher_button_configuration';
  static const Map<String, IconData> iconMap = {
    'star': Icons.star,
    'calendar': Icons.calendar_today,
    'timer': Icons.timer,
    'people': Icons.people,
    'shop': Icons.shopping_bag,
    'Avatarshop': Icons.shopping_bag,
    'settings': Icons.settings,
    'logout': Icons.logout,
    'analytics': Icons.analytics,
    'event': Icons.event_available,
    'notes': Icons.sticky_note_2,
    'planner': Icons.calendar_month,
    'inbox': Icons.mark_email_unread,
    'feedback': Icons.mail_outline,
    'invitation': Icons.qr_code,
    'schedule_editor': Icons.edit_calendar,
    'ratings_overview': Icons.rate_review,
    'tasks': Icons.assignment_outlined,
    'games': Icons.sports_esports,
    'shuffle': Icons.shuffle,
  };
  List<ButtonConfig> getDefaultStudentConfig() {
    return [
      ButtonConfig(id: 'rating', label: 'Bewertung des Unterrichts', iconKey: 'star', color: Colors.orange.shade400),
      ButtonConfig(id: 'schedule', label: 'Stundenplan', iconKey: 'calendar', color: Colors.green.shade400),
      ButtonConfig(id: 'focus', label: 'Fokus', iconKey: 'timer', color: Colors.purple.shade400),
      ButtonConfig(id: 'friends', label: 'Freunde', iconKey: 'people', color: Colors.blue.shade400),
      ButtonConfig(id: 'shop', label: 'Avatarshop', iconKey: 'shop', color: Colors.amber.shade600),
      ButtonConfig(id: 'feedback', label: 'Kummerkasten', iconKey: 'feedback', color:Colors.teal.shade600),
      ButtonConfig(id: 'settings', label: 'Einstellungen', iconKey: 'settings', color: Colors.grey.shade600),
      ButtonConfig(id: 'logout', label: 'Abmelden', iconKey: 'logout', color: Colors.grey.shade700),
      ButtonConfig(id: 'tasks', label: 'Aufgaben', iconKey: 'tasks', color: Colors.amber.shade600),
      ButtonConfig(id: 'games', label: 'Schul-Spiele', iconKey: 'games', color: Colors.deepPurple.shade600),
    ];
  }
  List<ButtonConfig> getDefaultTeacherConfig() {
    return [
      ButtonConfig(id: 'grades', label: 'Noten', iconKey: 'analytics', color: Colors.blue.shade700),
      ButtonConfig(id: 'exams', label: 'Prüfungen', iconKey: 'event', color: Colors.red.shade700),
      ButtonConfig(id: 'notes', label: 'Notizen', iconKey: 'notes', color: Colors.amber.shade700),
      ButtonConfig(id: 'planner', label: 'Terminplaner', iconKey: 'planner', color: Colors.teal.shade700),
      ButtonConfig(id: 'inbox', label: 'Posteingang-Schüler', iconKey: 'inbox', color: const Color.fromARGB(255, 31, 162, 64)),
      ButtonConfig(id: 'inbox-teacher', label: 'Posteingang-Lehrer', iconKey: 'inbox', color: const Color.fromARGB(255, 182, 113, 9)),
      ButtonConfig(id: 'invitation', label: 'Einladungen', iconKey: 'invitation', color: Colors.indigo.shade600),
      ButtonConfig(id: 'settings', label: 'Einstellungen', iconKey: 'settings', color: Colors.grey.shade600),
      ButtonConfig(id: 'ratings_overview', label: 'Unterrichtsbewertung', iconKey: 'ratings_overview', color: Colors.deepPurple.shade600),
      ButtonConfig(id: 'randomizer', label: 'Klassen-Randomizer', iconKey: 'shuffle', color: Colors.indigo.shade700),
      ButtonConfig(id: 'logout', label: 'Abmelden', iconKey: 'logout', color: Colors.grey.shade700),
      ButtonConfig(id: 'tasks', label: 'Aufgaben', iconKey: 'tasks', color: Colors.amber.shade700),

    ];
  }
  String _getStorageKey({required bool isTeacher}) {
    return isTeacher ? _teacherStorageKey : _studentStorageKey;
  }
  List<ButtonConfig> _getDefaultConfig({required bool isTeacher}) {
    return isTeacher ? getDefaultTeacherConfig() : getDefaultStudentConfig();
  }
  Future<List<ButtonConfig>> loadConfig({required bool isTeacher}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _getStorageKey(isTeacher: isTeacher);
    final jsonString = prefs.getString(storageKey);

    if (jsonString == null) {
      final defaultConfig = _getDefaultConfig(isTeacher: isTeacher);
      await saveConfig(defaultConfig, isTeacher: isTeacher);
      return defaultConfig;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      var config = jsonList.map((json) => ButtonConfig.fromJson(json)).toList();
      bool needsSave = false;
      final shopIndex = config.indexWhere((button) => button.id == 'shop');
      if (shopIndex != -1) {
        final shop = config[shopIndex];
        if (shop.label == 'Shop' || shop.iconKey == 'Avatarshop') {
          config[shopIndex] = ButtonConfig(
            id: shop.id,
            label: 'Avatar-Shop',
            iconKey: 'shop',
            color: shop.color,
            isVisible: shop.isVisible,
          );
          needsSave = true;
        }
      }
      if (!isTeacher) {
        for (var index = 0; index < config.length; index++) {
          final button = config[index];
          if (button.id != 'rating') continue;
          if (button.label != 'Bewertung des Unterrichts') {
            config[index] = ButtonConfig(
              id: button.id,
              label: 'Bewertung des Unterrichts',
              iconKey: button.iconKey,
              color: button.color,
              isVisible: button.isVisible,
            );
            needsSave = true;
          }
        }
      }
      if (!isTeacher) {
        config.removeWhere((c) => c.id == 'schedule_editor');
        if (config.where((c) => c.id == 'schedule').length > 1) {
          final first = config.firstWhere((c) => c.id == 'schedule');
          config = config.where((c) => c.id != 'schedule' || c == first).toList();
          needsSave = true;
        }
      }
      if (!config.any((c) => c.id == 'logout')) {
        config.add(ButtonConfig(
          id: 'logout',
          label: 'Abmelden',
          iconKey: 'logout',
          color: Colors.grey.shade700,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (!isTeacher && !config.any((c) => c.id == 'feedback')) {
        config.add(ButtonConfig(
          id: 'feedback',
          label: 'Kummerkasten',
          iconKey: 'feedback',
          color: Colors.teal.shade600,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (isTeacher) {
        for (var index = 0; index < config.length; index++) {
          final button = config[index];
          if (button.id == 'inbox' && button.label != 'Posteingang-Schüler') {
            config[index] = ButtonConfig(
              id: button.id,
              label: 'Posteingang-Schüler',
              iconKey: button.iconKey,
              color: button.color,
              isVisible: button.isVisible,
            );
            needsSave = true;
          } else if (button.id == 'teacher_mailbox') {
            config[index] = ButtonConfig(
              id: 'inbox-teacher',
              label: 'Posteingang-Lehrer',
              iconKey: button.iconKey,
              color: button.color,
              isVisible: button.isVisible,
            );
            needsSave = true;
          }
        }
        if (!config.any((button) => button.id == 'inbox-teacher')) {
          config.add(ButtonConfig(
            id: 'inbox-teacher',
            label: 'Posteingang-Lehrer',
            iconKey: 'inbox',
            color: const Color.fromARGB(255, 182, 113, 9),
            isVisible: true,
          ));
          needsSave = true;
        }
      }
      if (isTeacher && !config.any((c) => c.id == 'schedule_editor')) {
        config.add(ButtonConfig(
          id: 'schedule_editor',
          label: 'Stundenplan',
          iconKey: 'schedule_editor',
          color: Colors.teal.shade700,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (isTeacher && !config.any((c) => c.id == 'invitation')) {
        config.add(ButtonConfig(
          id: 'invitation',
          label: 'Einladungen',
          iconKey: 'invitation',
          color: Colors.indigo.shade600,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (isTeacher && !config.any((c) => c.id == 'ratings_overview')) {
        config.add(ButtonConfig(
          id: 'ratings_overview',
          label: 'Unterrichtsbewertung',
          iconKey: 'ratings_overview',
          color: Colors.deepPurple.shade600,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (isTeacher && !config.any((c) => c.id == 'randomizer')) {
        config.add(ButtonConfig(
          id: 'randomizer',
          label: 'Klassen-Randomizer',
          iconKey: 'shuffle',
          color: Colors.indigo.shade700,
          isVisible: true,
        ));
        needsSave = true;
      }
      if (needsSave) {
        await saveConfig(config, isTeacher: isTeacher);
      }
      if (!isTeacher && !config.any((c) => c.id == 'tasks')) {
        config.add(ButtonConfig(
        id: 'tasks',
        label: 'Aufgaben',
        iconKey: 'tasks',
        color: Colors.amber.shade600,
        isVisible: true,
      ));
      needsSave = true;
      }
      if (isTeacher && !config.any((c) => c.id == 'tasks')) {
        config.add(ButtonConfig(
        id: 'tasks',
        label: 'Aufgaben',
        iconKey: 'tasks',
        color: Colors.amber.shade700,
        isVisible: true,
        ));
      needsSave = true;
      }
      if (!isTeacher && !config.any((c) => c.id == 'games')) {
  config.add(ButtonConfig(
    id: 'games',
    label: 'Schul-Spiele',
    iconKey: 'games',
    color: Colors.deepPurple.shade600,
    isVisible: true,
  ));
  needsSave = true;
}
      return config;
    } catch (e) {
      return _getDefaultConfig(isTeacher: isTeacher);
    }
  }
  Future<void> saveConfig(List<ButtonConfig> config, {required bool isTeacher}) async {
    for (var c in config) {
      if (c.id == 'settings') {
        c.isVisible = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _getStorageKey(isTeacher: isTeacher);
    final jsonString = jsonEncode(config.map((c) => c.toJson()).toList());
    await prefs.setString(storageKey, jsonString);
    notifyListeners();
  }

  Future<void> resetToDefault({required bool isTeacher}) async {
    final defaultConfig = _getDefaultConfig(isTeacher: isTeacher);
    await saveConfig(defaultConfig, isTeacher: isTeacher);
  }
  IconData getIcon(String iconKey) {
    return iconMap[iconKey] ?? Icons.help_outline;
  }
}