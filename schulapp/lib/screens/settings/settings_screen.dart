import 'package:flutter/material.dart';
import '../../theme_manager.dart';
import '../change_password_screen.dart';
import 'button_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isTeacher;

  const SettingsScreen({super.key, this.isTeacher = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Farbblindmodus', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Ersetzt Rot/Grün durch Blau/Orange'),
                value: themeManager.colorBlindMode,
                activeTrackColor: Colors.purple.withValues(alpha: 0.5),
                activeThumbColor: Colors.purple,
                onChanged: (value) async {
                  await themeManager.toggleColorBlindMode(value);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Dunkler Modus', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Schont die Augen'),
                value: themeManager.themeMode == ThemeMode.dark,
                activeTrackColor: Colors.purple.withValues(alpha: 0.5),
                activeThumbColor: Colors.purple,
                onChanged: (value) async {
                  await themeManager.toggleDarkMode(value);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.purple),
                title: const Text('Passwort ändern', style: TextStyle(fontSize: 18)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen(isFirstLogin: false)),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dashboard_customize, color: Colors.teal),
                title: const Text('Buttons anpassen', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Farben und Reihenfolge ändern'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ButtonEditorScreen(isTeacher: widget.isTeacher),
                    ),
                  );
                },
              ),
              const Divider(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTeacher
                          ? '.'
                          : '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}