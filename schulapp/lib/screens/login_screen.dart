import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'change_password_screen.dart';
import 'primary/primary_home_screen.dart';
import 'secondary/secondary_home_screen.dart';
import 'high/high_home_screen.dart';
import 'registration_screen.dart';
import 'teacher/teacher_home_screen.dart';
import '../services/school_background_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pseudonymController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String selectedRole = 'student';
  String? _backgroundImageUrl;
  final LocalizationService _localization = LocalizationService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }
  Future<void> _initialize() async {
    await _localization.loadSavedLocale();
    _loadSavedBackground();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pseudonymController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _showDisambiguationDialog(List options, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text(_localization.translate('who_are_you'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localization.translate('multiple_students_message'),
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loginWithChosenName(opt.toString(), password);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(opt.toString(), style: const TextStyle(fontSize: 16)),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
  Future<void> _loginWithChosenName(String loginName, String password) async {
    _pseudonymController.text = loginName;
    _passwordController.text = password;
    await _handleLogin();
  }
  Future<void> _loadSavedBackground() async {
    final hasLoggedIn = await SchoolBackgroundService.hasLoggedInOnce();
    if (hasLoggedIn) {
      final savedImage = await SchoolBackgroundService.getSavedBackground();
      if (mounted) {
        setState(() {
          _backgroundImageUrl = savedImage;
        });
      }
    }
  }
  Widget _getTargetScreen(String role, String schoolType, String realName) {
    if (role == 'teacher') {
      return const TeacherHomeScreen();
    }
    switch (schoolType) {
      case 'secondary':
        return SecondaryHomeScreen(realName: realName);
      case 'high':
        return HighHomeScreen(realName: realName);
      case 'primary':
      default:
        return PrimaryHomeScreen(realName: realName);
    }
  }
  Future<void> _changeLanguage(String locale) async {
    await _localization.loadLocale(locale);
    if (mounted) setState(() {});
  }
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    final identifier = _pseudonymController.text.trim();
    final password = _passwordController.text;
    final isTeacher = selectedRole == 'teacher';
    final result = isTeacher
        ? await ApiService().loginTeacher(identifier, password)
        : await ApiService().loginStudent(identifier, password);
    if (!mounted) return;
    if (result != null && result['requires_disambiguation'] == true) {
      setState(() => _isLoading = false);
      _showDisambiguationDialog(
        result['options'] as List,
        result['password'] as String,
      );
      return;
    }
    if (result != null && !result.containsKey('error')) {
      final schoolId = result['school_id']?.toString();
      final schoolName = result['school_name']?.toString() ?? 'Unbekannte Schule';
      final schoolType = result['school_type']?.toString() ?? 'primary';
      final role = result['role'].toString();
      final realName = result['real_name']?.toString()
          ?? result['full_name']?.toString()
          ?? result['pseudonym']?.toString()
          ?? 'User';
      final mustChange = result['must_change_password'] ?? false;
      if (schoolId != null) {
        await SchoolBackgroundService.loadAndSaveBackground(
          schoolId: schoolId,
          schoolName: schoolName,
          schoolType: schoolType,
        );
      }
      if (!mounted) return;
      if (mustChange) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChangePasswordScreen(isFirstLogin: true),
          ),
        );
        return;
      }
      final targetScreen = _getTargetScreen(role, schoolType, realName);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    } else {
      setState(() => _isLoading = false);
      final error = result?['error'];
      final errorMessage = error is List
          ? error.map((item) => item is Map ? item['msg'] : item).join(', ')
          : error?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? _localization.translate('login_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_backgroundImageUrl != null)
            Positioned.fill(
              child: Image.network(
                _backgroundImageUrl!,
                fit: BoxFit.cover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
          
          // Sprachauswahl oben rechts
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: _localization.currentLocale,
                underline: const SizedBox(),
                icon: const Icon(Icons.language, size: 20),
                items: const [
                  DropdownMenuItem(
                    value: 'de',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 8),
                        Text('Deutsch', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 8),
                        Text('English', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _changeLanguage(value);
                  }
                },
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: 80, color: Colors.blue.shade400),
                    const SizedBox(height: 20),
                    Text(
                      _localization.translate('welcome'),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _pseudonymController,
                      decoration: InputDecoration(
                        labelText: selectedRole == 'teacher' 
                            ? _localization.translate('email') 
                            : _localization.translate('email_or_name'),
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _localization.translate('password'),
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text(_localization.translate('student_login')),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text(_localization.translate('teacher_login')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _localization.translate('login'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistrationScreen(),
                            ),
                          );
                          if (!mounted) return;
                          if (result == true) {
                            _pseudonymController.clear();
                            _passwordController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_localization.translate('registration_success')),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person_add),
                        label: Text(_localization.translate('register')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade700,
                          side: BorderSide(color: Colors.purple.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final nameController = TextEditingController();
                        await showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(_localization.translate('forgot_password_title')),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    labelText: _localization.translate('your_name_or_email'),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(_localization.translate('cancel')),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final username = nameController.text.trim();
                                  if (username.isEmpty) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_localization.translate('enter_name_or_email')),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(ctx);
                                  final success = await ApiService().requestPasswordReset(username);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? _localization.translate('password_reset_success')
                                            : _localization.translate('password_reset_error'),
                                      ),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                },
                                child: Text(_localization.translate('request')),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(_localization.translate('forgot_password')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}