import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherExamsScreen extends StatefulWidget {
  const TeacherExamsScreen({super.key});

  @override
  State<TeacherExamsScreen> createState() => _TeacherExamsScreenState();
}
class _TeacherExamsScreenState extends State<TeacherExamsScreen> {
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final exams = await ApiService().getAllExams();
    final classes = await ApiService().getClasses();
    if (mounted) {
      setState(() {
        _exams = List<Map<String, dynamic>>.from(exams);
        _classes = List<Map<String, dynamic>>.from(classes);
        _isLoading = false;
      });
    }
  }
  Map<String, List<Map<String, dynamic>>> _groupExamsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final exam in _exams) {
      final date = exam['exam_date'] as String;
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(exam);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  }
  Future<void> _deleteExam(String examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prüfung löschen?'),
        content: const Text('Möchten Sie diese Prüfung wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ApiService().deleteExam(examId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prüfung gelöscht'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    }
  }
  void _showAddExamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddExamDialog(
        classes: _classes,
        onExamCreated: _loadData,
      ),
    );
  }
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      final weekday = weekdays[date.weekday - 1];
      return '$weekday, ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        final grouped = _groupExamsByDate();   
        return Scaffold(
          appBar: AppBar(
            title: const Text('Prüfungstermine'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('danger')
                : Colors.red.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Aktualisieren',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _exams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Noch keine Prüfungen eingetragen.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final date = grouped.keys.elementAt(index);
                          final exams = grouped[date]!;                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDate(date),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              ...exams.map((exam) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.school, color: Colors.red.shade700),
                                  ),
                                  title: Text(
                                    exam['subject'] ?? 'Unbekanntes Fach',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Klasse ${exam['class_name']}',
                                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                        ),
                                        if (exam['description'] != null && exam['description'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            exam['description'],
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () => _deleteExam(exam['id']),
                                    tooltip: 'Löschen',
                                  ),
                                ),
                              )),
                            ],
                          );
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddExamDialog,
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('danger')
                : Colors.red.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Prüfung'),
          ),
        );
      },
    );
  }
}
class _AddExamDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final VoidCallback onExamCreated;
  const _AddExamDialog({required this.classes, required this.onExamCreated});

  @override
  State<_AddExamDialog> createState() => _AddExamDialogState();
}

class _AddExamDialogState extends State<_AddExamDialog> {
  List<String> _availableSubjects = [];
  String? _selectedClassId;
  String? _selectedSubject;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isChecking = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      _selectedClassId = widget.classes[0]['id'] as String;
      _loadSubjects();
    }
  }
  Future<void> _loadSubjects() async {
    if (_selectedClassId == null) return;
    final subjects = await ApiService().getMySubjectsForClass(_selectedClassId!);
    if (mounted) {
      setState(() {
        _availableSubjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects[0] : null;
      });
    }
  }
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }
  Future<void> _saveExam() async {
    if (_selectedClassId == null) {
      _showError('Bitte wählen Sie eine Klasse aus.');
      return;
    }
    final subject = _availableSubjects.isEmpty
      ? _subjectController.text.trim()
      : (_selectedSubject ?? '').trim();

    if (subject.isEmpty) {
      _showError('Bitte geben Sie ein Fach ein.');
      return;
    }
    setState(() => _isChecking = true);
    final conflictResult = await ApiService().checkExamConflict(
      classId: _selectedClassId!,
      subject: subject,
      examDate: _selectedDate.toIso8601String().split('T')[0],
    );
    if (!mounted) return;
    setState(() => _isChecking = false);
    if (conflictResult['has_conflict'] == true) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Konflikt erkannt!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conflictResult['message'] ?? 'Es gibt bereits Prüfungen an diesem Tag.'),
              const SizedBox(height: 12),
              const Text(
                'Möchten Sie trotzdem speichern?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Trotzdem speichern'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }
    setState(() => _isSaving = true);

    final result = await ApiService().createExam(
      classId: _selectedClassId!,
      subject: subject,
      examDate: _selectedDate.toIso8601String().split('T')[0],
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null) {
      widget.onExamCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prüfung erfolgreich erstellt'), backgroundColor: Colors.green),
      );
    } else {
      _showError('Fehler beim Speichern. Bitte versuchen Sie es erneut.');
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Prüfung'),
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
                    child: Text(c['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedClassId = val;
                    _availableSubjects = [];
                    _selectedSubject = null;
                  });
                  _loadSubjects();
                },
              ),
              const SizedBox(height: 16),
              _availableSubjects.isEmpty
                  ? TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Fach *',
                        hintText: 'z.B. Mathematik',
                        border: OutlineInputBorder(),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Fach *',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableSubjects
                          .map((subject) => DropdownMenuItem(
                                value: subject,
                                child: Text(subject),
                              ))
                          .toList(),
                      onChanged: (subject) => setState(() => _selectedSubject = subject),
                    ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum *',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  hintText: 'z.B. Kapitel 5-7, Taschenrechner erlaubt',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChecking || _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isChecking || _isSaving ? null : _saveExam,
          child: _isChecking
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
        ),
      ],
    );
  }
}