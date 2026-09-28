import 'package:flutter/material.dart';
import '../../services/button_config_service.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';
import '../settings/settings_screen.dart';
import '../focus/focus_mode_screen.dart';
import '../login_screen.dart';
import '../feedback_screen.dart';
import '../schedule_screen.dart';
import '../rating_screen.dart';
import 'primary_avatar_screen.dart';
import '../friends_screen.dart';
import '../avatar_shop_screen.dart';
import '/../../widgets/avatar_with_items.dart';
import '../tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/mascot_fab.dart';
import '../student_exams_screen.dart';
import '../challenge_screen.dart';
import '../../widgets/graduation_photo_dialog.dart';

class PrimaryHomeScreen extends StatefulWidget {
  final String realName;
  const PrimaryHomeScreen({super.key, required this.realName});

  @override
  State<PrimaryHomeScreen> createState() => _PrimaryHomeScreenState();
}

class _PrimaryHomeScreenState extends State<PrimaryHomeScreen> {
  List<ButtonConfig> _buttonConfigs = [];
  bool _isLoading = true;
  int _currentXp = 0;
  String? _avatarBase64;
  List<Map<String, dynamic>> equippedItems = [];
  bool _hasUpcomingExams = false;
  int _examCount = 0;
  bool _mascotEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadButtonConfig();
    _loadXp();
    _loadAvatar();
    _loadEquippedItems();
    _checkXpNotifications();
    _loadMascotSetting();
    _checkUpcomingExams();
    ButtonConfigService().addListener(_onConfigChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
    GraduationPhotoDialog.checkAndShow(context);
    });
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
  Future<void> _checkUpcomingExams() async {
  final result = await ApiService().checkUpcomingExams();
  if (mounted) {
    setState(() {
      _hasUpcomingExams = result['has_exams'] == true;
      _examCount = result['count'] ?? 0;
    });
  }
}
  Future<void> _loadButtonConfig() async {
    final config = await ButtonConfigService().loadConfig(isTeacher: false);
    if (mounted) {
      setState(() {
        _buttonConfigs = config;
        _isLoading = false;
      });
    }
  }
  Future<void> _loadXp() async {
    final xp = await ApiService().getMyXp();
    if (mounted) {
      setState(() => _currentXp = xp);
    }
  }
  Future<void> _loadAvatar() async {
    final data = await ApiService().getMyAvatar();
    if (mounted && data != null && data['image_base64'] != null) {
      setState(() {
        _avatarBase64 = data['image_base64'];
      });
    }
  }
  Future<void> _checkXpNotifications() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final data = await ApiService().getXpNotifications();
    final notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
    if (notifications.isNotEmpty && mounted) {
      _showXpNotificationDialog(data);
    }
  }
  Future<void> _loadEquippedItems() async {
    final items = await ApiService().getEquippedItems();
    if (mounted) {
      setState(() => equippedItems = items);
    }
  }
  void _showXpNotificationDialog(Map<String, dynamic> data) {
    final notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
    final totalXp = data['total_xp_received'] ?? 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 56, color: Colors.purple.shade400),
            const SizedBox(height: 12),
            Text(
              'Du hast XP geschenkt bekommen! 🎉',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '+$totalXp XP insgesamt',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  children: notifications.map((gift) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${gift['amount']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'von ${gift['sender_name']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                                if (gift['message'] != null && gift['message'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${gift['message']}"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () async {
                await ApiService().markXpNotificationsRead();
                _loadXp();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Super, danke!'),
            ),
          ),
        ],
      ),
    );
  }
  void _navigateToScreen(String buttonId) {
    switch (buttonId) {
      case 'rating':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RatingScreen()));
        break;
      case 'schedule':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
        break;
      case 'focus':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FocusModeScreen()));
        break;
      case 'friends':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()))
            .then((_) => _loadXp());
        break;
      case 'feedback':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackScreen()));
        break;
      case 'settings':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen(isTeacher: false)));
        break;
      case 'logout':
        _handleLogout();
        break;
      case 'shop':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AvatarShopScreen()))
        .then((_) => _loadXp());
      break;
      case 'tasks':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TasksScreen()));
        break;
      case 'challenges':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ChallengeScreen(schoolType: 'primary')))
            .then((_) => _loadXp());
        break;
      case 'games':
        Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChallengeScreen(schoolType: 'primary')),
        );
      break;
    }
  }
  Future<void> _handleLogout() async {
    await ApiService().clearToken();
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
            title: Text('Hallo, ${widget.realName}!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  _mascotEnabled ? Icons.pets : Icons.pets_outlined,
                  color: _mascotEnabled ? Colors.amber : Colors.white70,
                ),
                onPressed: _toggleMascot,
                tooltip: _mascotEnabled ? 'Maskottchen ausblenden' : 'Maskottchen einblenden',
              ),
              Container(
                margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 18, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      '$_currentXp XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _mascotEnabled ? const MascotFab() : null,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [Colors.grey.shade900, Colors.black]
                    : [Colors.blue.shade100, Colors.purple.shade100],
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Column(
                      children: [
                        AvatarWithItems(
                          avatarBase64: _avatarBase64,
                          equippedItems: equippedItems,
                          size: 140,
                          showFrameIcon: false,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PrimaryAvatarScreen()),
                            );
                            _loadAvatar();
                            _loadEquippedItems();
                            _loadXp();
                          },
                        ),
                        if (_hasUpcomingExams) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StudentExamsScreen()),
                              );
                              _checkUpcomingExams();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                              gradient: LinearGradient(
                              colors: [Colors.red.shade600, Colors.orange.shade600],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_late, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            const Text(
                            'Prüfungstermine',
                            style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                  ),
                ),
                Text(
                  '$_examCount anstehende Prüfung${_examCount > 1 ? 'en' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    ),
  ),
],
const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                            children: _buttonConfigs
                                .where((config) => config.isVisible)
                                .map((config) {
                              final displayColor = themeManager.colorBlindMode
                                  ? themeManager.getColor(_mapIdToColorKey(config.id))
                                  : config.color;

                              return _buildButton(
                                icon: ButtonConfigService().getIcon(config.iconKey),
                                label: config.label,
                                color: displayColor,
                                onTap: () => _navigateToScreen(config.id),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      });
      }
  }
  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  String _mapIdToColorKey(String buttonId) {
    switch (buttonId) {
      case 'rating': return 'warning';
      case 'schedule': return 'success';
      case 'focus': return 'accent';
      case 'friends': return 'default';
      case 'shop': return 'warning';
      case 'feedback': return 'success';
      case 'settings': return 'default';
      case 'games': return 'accent';
      case 'logout': return 'default';
      default: return 'default';
    }
  }