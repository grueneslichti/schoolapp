import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherInvitationScreen extends StatefulWidget {
  const TeacherInvitationScreen({super.key});

  @override
  State<TeacherInvitationScreen> createState() => _TeacherInvitationScreenState();
}

class _TeacherInvitationScreenState extends State<TeacherInvitationScreen> {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _myCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final classes = await ApiService().getClasses();
    final codes = await ApiService().getMyInvitationCodes();
    
    if (mounted) {
      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes);
        _myCodes = List<Map<String, dynamic>>.from(codes);
        _isLoading = false;
      });
    }
  }

  void _showCreateCodeDialog() {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Klassen vorhanden'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _CreateCodeDialog(
        classes: _classes,
        onCodeCreated: _loadData,
      ),
    );
  }

  Future<void> _deactivateCode(String codeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code deaktivieren?'),
        content: const Text('Schüler können sich mit diesem Code dann nicht mehr registrieren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService().deactivateInvitationCode(codeId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code deaktiviert'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code "$code" kopiert!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Einladungscodes'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('accent')
                : Colors.indigo.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.indigo.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Erstelle einen Code und gib ihn deinen Schülern. '
                              'Neue Schüler können sich damit selbst registrieren.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.indigo.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _myCodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Noch keine Codes erstellt.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _myCodes.length,
                                itemBuilder: (context, index) {
                                  final code = _myCodes[index];
                                  final isActive = code['is_active'] == true;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isActive ? Colors.indigo.shade600 : Colors.grey.shade400,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  code['code'] ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.5,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
                                                  ),
                                                ),
                                                child: Text(
                                                  isActive ? 'Aktiv' : 'Deaktiviert',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(Icons.school, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text('Klasse ${code['class_name']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                              const SizedBox(width: 16),
                                              Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text('${code['times_used']}x genutzt', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                            ],
                                          ),
                                          const SizedBox(height: 12), 
                                          Row(
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => _copyToClipboard(code['code']),
                                                icon: const Icon(Icons.copy, size: 16),
                                                label: const Text('Kopieren'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.indigo.shade700,
                                                  side: BorderSide(color: Colors.indigo.shade300),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (isActive)
                                                TextButton.icon(
                                                  onPressed: () => _deactivateCode(code['id']),
                                                  icon: const Icon(Icons.block, size: 16),
                                                  label: const Text('Deaktivieren'),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateCodeDialog,
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('accent')
                : const Color.fromARGB(255, 236, 237, 245),
            icon: const Icon(Icons.add),
            label: const Text('Neuer Code'),
          ),
        );
      },
    );
  }
}

class _CreateCodeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final VoidCallback onCodeCreated;

  const _CreateCodeDialog({required this.classes, required this.onCodeCreated});

  @override
  State<_CreateCodeDialog> createState() => _CreateCodeDialogState();
}

class _CreateCodeDialogState extends State<_CreateCodeDialog> {
  String? _selectedClassId;
  final _codeController = TextEditingController();
  int _expiresInDays = 30;
  bool _isSaving = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _generateRandomCode() {
    final adjectives = ['SONNE', 'MOND', 'STERN', 'WOLKE', 'BLUME', 'BAUM', 'FLUSS', 'BERG', 'MEER', 'REGEN'];
    final random = (adjectives..shuffle()).first;
    final number = (100 + DateTime.now().millisecond % 900);
    _codeController.text = '$random-$number';
  }

  Future<void> _createCode() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle eine Klasse'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Code ein'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final result = await ApiService().createInvitationCode(
      classId: _selectedClassId!,
      code: _codeController.text.trim().toUpperCase(),
      expiresInDays: _expiresInDays,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null && !result.containsKey('error')) {
      widget.onCodeCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code "${result['code']}" erstellt!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['error'] ?? 'Fehler'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Einladungscode erstellen'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Klasse *',
                  border: OutlineInputBorder(),
                ),
                items: widget.classes.map((c) {
                  return DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text('Klasse ${c['name']}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedClassId = val),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Code *',
                        hintText: 'z.B. SONNE-2024',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _generateRandomCode,
                    icon: const Icon(Icons.casino),
                    tooltip: 'Zufälligen Code generieren',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.indigo.shade50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Code läuft ab nach:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [7, 14, 30, 60].map((days) {
                  final isSelected = _expiresInDays == days;
                  return ChoiceChip(
                    label: Text('$days Tage'),
                    selected: isSelected,
                    selectedColor: Colors.indigo.shade600,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.indigo.shade800,
                    ),
                    onSelected: (_) => setState(() => _expiresInDays = days),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _createCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Erstellen'),
        ),
      ],
    );
  }
}