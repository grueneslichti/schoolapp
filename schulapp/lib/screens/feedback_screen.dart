import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  String? _selectedCategory;
  bool _isAnonymous = true; // NEU: Standard = Anonym
  bool _isSending = false;
  final List<String> _categories = [
    'Allgemein',
    'Mobbing',
    'Probleme mit Mitschülern',
    'Probleme mit Lehrern',
    'Sonstiges',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  Future<void> _sendFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte schreibe eine Nachricht'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_isAnonymous) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Nicht anonym?'),
            ],
          ),
          content: const Text(
            'Du schickst die Nachricht nicht anonym.\n\n'
            'Dein Name wird dem zuständigen Lehrer angezeigt.\n\n'
            'Bist du dir sicher?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nein, lieber anonym'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Ja, nicht anonym senden'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _isSending = true);
    final success = await ApiService().sendFeedback(
      message: _messageController.text.trim(),
      category: _selectedCategory,
      isAnonymous: _isAnonymous,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) {
      _messageController.clear();
      setState(() {
        _selectedCategory = null;
        _isAnonymous = true; // Zurücksetzen
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nachricht erfolgreich gesendet! 💚'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Senden'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kummerkasten'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info-Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isAnonymous
                            ? 'Deine Nachricht wird ANONYM gesendet. Der Lehrer sieht deinen Namen nicht.'
                            : 'Deine Nachricht wird NICHT anonym gesendet. Der Lehrer sieht deinen Namen.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isAnonymous ? Colors.teal.shade900 : Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: const Text('Anonym senden', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _isAnonymous
                        ? 'Dein Name wird NICHT angezeigt'
                        : 'Dein Name WIRD angezeigt',
                  ),
                  secondary: Icon(
                    _isAnonymous ? Icons.lock : Icons.person,
                    color: _isAnonymous ? Colors.teal : Colors.orange,
                  ),
                  value: _isAnonymous,
                  activeThumbColor: Colors.teal,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Kategorie:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'Kategorie wählen (optional)',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                )).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 20),
              const Text('Deine Nachricht:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Schreibe hier, was dich beschäftigt...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendFeedback,
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending ? 'Wird gesendet...' : 'Nachricht senden',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnonymous ? Colors.teal.shade700 : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}