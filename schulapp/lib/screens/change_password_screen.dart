import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;

  const ChangePasswordScreen({super.key, required this.isFirstLogin});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  Future<void> _handleChange() async {
    final oldPwd = _oldPasswordController.text;
    final newPwd = _newPasswordController.text;
    final confirmPwd = _confirmPasswordController.text;
    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      _showError("Bitte alle Felder ausfüllen.");
      return;
    }
    if (newPwd.length < 6) {
      _showError("Das neue Passwort muss mindestens 6 Zeichen lang sein.");
      return;
    }
    if (newPwd != confirmPwd) {
      _showError("Die neuen Passwörter stimmen nicht überein.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await ApiService().changePassword(oldPwd, newPwd);     
      if (!mounted) return;
      if (success) {
        await ApiService().clearToken();
        if (!mounted) return;  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwort erfolgreich geändert! Bitte neu anmelden.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showError("Änderung fehlgeschlagen. Ist das alte Passwort korrekt?");
      }
    } catch (e) {
      _showError("Ein unerwarteter Fehler ist aufgetreten.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstLogin ? 'Passwort festlegen' : 'Passwort ändern'),
        automaticallyImplyLeading: !widget.isFirstLogin, 
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isFirstLogin) ...[
                  const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Willkommen!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bitte vergib ein eigenes, sicheres Passwort für dein Konto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                ],
                TextField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Altes / Aktuelles Passwort',
                    prefixIcon: Icon(Icons.lock_clock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Neues Passwort',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Neues Passwort bestätigen',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleChange,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Passwort speichern', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}