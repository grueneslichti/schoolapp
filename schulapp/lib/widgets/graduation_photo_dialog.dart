import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GraduationPhotoDialog {
  static Future<void> checkAndShow(BuildContext context) async {
    final status = await ApiService().getGraduationPhotoStatus();
    if (status == null || status['pending'] != true) return;
    if (!context.mounted) return;
    final className = status['class_name'] ?? 'deiner alten Klasse';
    final wantsPhoto = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.photo_library, color: Colors.indigo.shade400, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Klassenabschluss-Foto?')),
          ],
        ),
        content: Text(
          'Du hast die Schule gewechselt. 🎓\n\n'
          'Möchtest du ein Andenken-Foto mit allen Schülern aus $className '
          'als Gruppen-Avatar bekommen?\n\n'
          'Anime-Avatare werden automatisch übernommen',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein, danke'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ja, Foto erstellen!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (wantsPhoto == null || !context.mounted) return;
    if (wantsPhoto) {
      await _generatePhoto(context);
    } else {
      await ApiService().declineGraduationPhoto();
    }
  }
  static Future<void> _generatePhoto(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Foto wird erstellt...'),
          ],
        ),
      ),
    );
    final result = await ApiService().generateGraduationPhoto();
    if (!context.mounted) return;
    Navigator.pop(context);
    if (result != null && result['photo_path'] != null) {
      _showPhotoResult(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto konnte nicht erstellt werden'), backgroundColor: Colors.red),
      );
    }
  }
  static void _showPhotoResult(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Dein Klassenfoto! 🎉'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ApiService().getGraduationPhotoUrl(),
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) =>
                      progress == null ? child : const CircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Du findest es jederzeit in deinem Profil.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}