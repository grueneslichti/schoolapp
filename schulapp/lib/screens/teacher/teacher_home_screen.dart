import 'package:flutter/material.dart';
import '../../services/button_config_service.dart';
import '../../services/api_service.dart' as app_api;
import '../../theme_manager.dart';
import '../login_screen.dart';
import '../settings/settings_screen.dart';
import 'teacher_grades_screen.dart';
import 'teacher_exams_screen.dart';
import 'teacher_notes_screen.dart';
import 'teacher_planner_screen.dart';
import 'teacher_inbox_screen.dart';
import 'teacher_invitation_screen.dart';
import 'schedule_editor_screen.dart';
import 'teacher_ratings_screen.dart';
import 'teacher_tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/mascot_fab.dart';
import 'class_randomizer_screen.dart';
import 'teacher_mailbox_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  List<ButtonConfig> _buttonConfigs = [];
  bool _isLoading = true;
  bool _mascotEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadButtonConfig();
    _loadMascotSetting();
    ButtonConfigService().addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    ButtonConfigService().removeListener(_onConfigChanged);
    super.dispose();
  }
  void _onConfigChanged() {
    _loadButtonConfig();
  }
  Future<void> _loadMascotSetting() async {
  final prefs = await SharedPreferences.getInstance();
  if (mounted) {
    setState(() => _mascotEnabled = prefs.getBool('mascot_enabled') ?? true);
  }
 }
  Future<void> _toggleMascot() async {
  final prefs = await SharedPreferences.getInstance();
  final newValue = !_mascotEnabled;
  await prefs.setBool('mascot_enabled', newValue);
  setState(() => _mascotEnabled = newValue);
}
  Future<void> _loadButtonConfig() async {
    final config = await ButtonConfigService().loadConfig(isTeacher: true);
    if (mounted) {
      setState(() {
        _buttonConfigs = config;
        _isLoading = false;
      });
    }
  }
  void _navigateToScreen(String buttonId) {
    Widget? screen;
    switch (buttonId) {
      case 'grades':
        screen = const TeacherGradesScreen();
        break;
      case 'exams':
        screen = const TeacherExamsScreen();
        break;
      case 'notes':
        screen = const TeacherNotesScreen();
        break;
      case 'planner':
        screen = const TeacherPlannerScreen();
        break;
      case 'inbox':
        screen = const TeacherInboxScreen();
        break;
      case 'inbox-teacher':
        screen = const TeacherMailboxScreen();
        break;
      case 'settings':
        screen = const SettingsScreen(isTeacher: true);
        break;
      case 'logout':
        _handleLogout();
        return;
      case 'invitation':
        screen = const TeacherInvitationScreen();
        break;
      case 'schedule_editor':
        screen = const ScheduleEditorScreen();
        break;
      case 'ratings_overview':
        screen = const TeacherRatingsScreen();
        break;
      case 'tasks':
        screen = const TeacherTasksScreen();
        break;
      case 'randomizer':
        screen = const ClassRandomizerScreen();
        break;
      }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    }
  }
  Future<void> _handleLogout() async {
    await app_api.ApiService().clearToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lehrer Dashboard'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              IconButton(
                icon: Icon(
                  _mascotEnabled ? Icons.pets : Icons.pets_outlined,
                  color: _mascotEnabled ? Colors.amber : Colors.white70,
                ),
                onPressed: _toggleMascot,
                tooltip: _mascotEnabled ? 'Maskottchen ausblenden' : 'Maskottchen einblenden',
              ),
            ],
          ),
          floatingActionButton: _mascotEnabled ? const MascotFab() : null,
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Willkommen zurück!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Klassenüberblick.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: _buttonConfigs
                                .where((config) => config.isVisible)
                                .map((config) {
                              final displayColor = themeManager.colorBlindMode
                                  ? themeManager.getColor(_mapIdToColorKey(config.id))
                                  : config.color;
                              return GestureDetector(
                                onTap: () => _navigateToScreen(config.id),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: displayColor.withValues(alpha: 0.3), width: 2),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(ButtonConfigService().getIcon(config.iconKey), size: 40, color: displayColor),
                                        const SizedBox(height: 12),
                                        Text(
                                          config.label,
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
  String _mapIdToColorKey(String buttonId) {
    switch (buttonId) {
      case 'grades': return 'default';
      case 'exams': return 'danger';
      case 'notes': return 'warning';
      case 'planner': return 'success';
      case 'inbox': return 'accent';
      case 'settings': return 'default';
      case 'logout': return 'default';
      case 'invitation': return 'accent';
      case 'schedule_editor': return 'success';
      case 'ratings_overview': return 'accent';
      default: return 'default';
    }
  }
}