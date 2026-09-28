import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class ProfileExportScreen extends StatefulWidget {
  const ProfileExportScreen({super.key});

  @override
  State<ProfileExportScreen> createState() => _ProfileExportScreenState();
}

class _ProfileExportScreenState extends State<ProfileExportScreen> {
  Map<String, dynamic>? _exportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExport();
  }
  Future<void> _loadExport() async {
    final data = await ApiService().exportMyProfile();
    if (mounted) {
      setState(() {
        _exportData = data;
        _isLoading = false;
      });
    }
  }
  Future<void> _saveToFile() async {
    if (_exportData == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/mein_schulapp_profil.json');
      await file.writeAsString(jsonEncode(_exportData)); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil gespeichert: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Future<void> _shareProfile() async {
    if (_exportData == null) return;
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/mein_schulapp_profil.json');
      await file.writeAsString(jsonEncode(_exportData));
      
      await Share.shareXFiles([XFile(file.path)], text: 'Mein SchulApp-Profil');
    } catch (e) {
      // Teilen fehlgeschlagen
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exportData == null
              ? const Center(child: Text('Fehler beim Laden'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Schüler-Informationen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            _infoRow('Name', _exportData!['student']?['real_name'] ?? ''),
                            _infoRow('Pseudonym', _exportData!['student']?['pseudonym'] ?? ''),
                            _infoRow('XP', '${_exportData!['student']?['xp'] ?? 0}'),
                            _infoRow('Klasse', _exportData!['student']?['class_name'] ?? ''),
                            _infoRow('Schule', _exportData!['student']?['school_name'] ?? ''),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            _infoRow('Avatar vorhanden', _exportData!['avatar']?['has_avatar'] == true ? 'Ja' : 'Nein'),
                            _infoRow('Items gesammelt', '${_exportData!['total_items'] ?? 0}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveToFile,
                      icon: const Icon(Icons.save),
                      label: const Text('Profil auf Gerät speichern'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _shareProfile,
                      icon: const Icon(Icons.share),
                      label: const Text('Profil teilen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
    );
  }
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}