import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherGradesScreen extends StatefulWidget {
  const TeacherGradesScreen({super.key});

  @override
  State<TeacherGradesScreen> createState() => _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends State<TeacherGradesScreen> {
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _studentGrades = [];
  bool _isLoading = true;
  bool _isLoadingGrades = false;
  final Set<int> _expandedIndices = {};
  bool _allExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }
  Future<void> _loadClasses() async {
    final classes = await ApiService().getClasses();
    if (mounted) {
      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes);
        _isLoading = false;
        if (_classes.isNotEmpty) {
          _selectedClassId = _classes[0]['id'] as String;
          _loadGrades();
        }
      });
    }
  }
  Future<void> _loadGrades() async {
    if (_selectedClassId == null) return;
    setState(() {
      _isLoadingGrades = true;
      _expandedIndices.clear();
      _allExpanded = false;
    });
    final grades = await ApiService().getClassGrades(_selectedClassId!);    
    if (mounted) {
      setState(() {
        _studentGrades = List<Map<String, dynamic>>.from(grades);
        _isLoadingGrades = false;
      });
    }
  }
  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expandedIndices.clear();
        _allExpanded = false;
      } else {
        _expandedIndices.addAll(List.generate(_studentGrades.length, (i) => i));
        _allExpanded = true;
      }
    });
  }
  void _showAddGradeDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => _AddGradeDialog(
        studentName: student['real_name'] ?? 'Unbekannt',
        studentId: student['student_id'] ?? '',
        classId: _selectedClassId!,
        onGradeAdded: _loadGrades,
      ),
    );
  }
  Future<void> _deleteGrade(String gradeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note löschen?'),
        content: const Text('Möchten Sie diese Note wirklich löschen?'),
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
      final success = await ApiService().deleteGrade(gradeId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note gelöscht'), backgroundColor: Colors.green),
        );
        _loadGrades();
      }
    }
  }
  Color _getGradeColor(double grade) {
    if (grade <= 2) return Colors.green.shade700;
    if (grade <= 3) return Colors.orange.shade700;
    if (grade <= 4) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Noten'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('default')
                : Colors.blue.shade700,
            foregroundColor: Colors.white,
            actions: [
              if (_studentGrades.isNotEmpty)
                IconButton(
                  icon: Icon(_allExpanded ? Icons.unfold_less : Icons.unfold_more),
                  onPressed: _toggleAll,
                  tooltip: _allExpanded ? 'Alle zuklappen' : 'Alle aufklappen',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadGrades,
                tooltip: 'Aktualisieren',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.school, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedClassId,
                              decoration: const InputDecoration(
                                labelText: 'Klasse wählen',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: _classes.map((c) {
                                return DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text('Klasse ${c['name']}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedClassId = val);
                                  _loadGrades();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoadingGrades
                          ? const Center(child: CircularProgressIndicator())
                          : _studentGrades.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sentiment_neutral, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Keine Schüler in dieser Klasse.',
                                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadGrades,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _studentGrades.length,
                                    itemBuilder: (context, index) {
                                      final student = _studentGrades[index];
                                      final grades = List<Map<String, dynamic>>.from(student['grades'] ?? []);
                                      final average = (student['average'] ?? 0.0).toDouble();
                                      final isExpanded = _expandedIndices.contains(index);
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        elevation: isExpanded ? 4 : 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                          child: ExpansionTile(
                                            initiallyExpanded: isExpanded,
                                            onExpansionChanged: (expanded) {
                                              setState(() {
                                                if (expanded) {
                                                  _expandedIndices.add(index);
                                                } else {
                                                  _expandedIndices.remove(index);
                                                }
                                              });
                                            },
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.blue.shade100,
                                              child: Icon(Icons.person, color: Colors.blue.shade700),
                                            ),
                                            title: Text(
                                              student['real_name'] ?? 'Unbekannt',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(
                                              student['pseudonym'] ?? '',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (grades.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${grades.length}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: average > 0
                                                        ? _getGradeColor(average).withValues(alpha: 0.1)
                                                        : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Text(
                                                    average > 0 ? 'Ø ${average.toStringAsFixed(1)}' : '–',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: average > 0 ? _getGradeColor(average) : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                child: Column(
                                                  children: [
                                                    const Divider(),
                                                    if (grades.isEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                        child: Text(
                                                          'Noch keine Noten eingetragen.',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.grey.shade500,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      ...grades.map((grade) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 10),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 36,
                                                              height: 36,
                                                              decoration: BoxDecoration(
                                                                color: _getGradeColor((grade['value'] ?? 0).toDouble()),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${grade['value']}',
                                                                  style: const TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    grade['subject'] ?? 'Unbekannt',
                                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                                  ),
                                                                  if (grade['description'] != null && grade['description'].toString().isNotEmpty)
                                                                    Text(
                                                                      grade['description'],
                                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete_outline, size: 20),
                                                              color: Colors.red,
                                                              onPressed: () => _deleteGrade(grade['id']),
                                                              tooltip: 'Note löschen',
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _showAddGradeDialog(student),
                                                        icon: const Icon(Icons.add, size: 18),
                                                        label: const Text('Note hinzufügen'),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: Colors.blue.shade700,
                                                          side: BorderSide(color: Colors.blue.shade300),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
        );
      },
    );
  }
}
class _AddGradeDialog extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String classId;
  final VoidCallback onGradeAdded;
  const _AddGradeDialog({
    required this.studentName,
    required this.studentId,
    required this.classId,
    required this.onGradeAdded,
  });

  @override
  State<_AddGradeDialog> createState() => _AddGradeDialogState();
}
class _AddGradeDialogState extends State<_AddGradeDialog> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedGrade = 3;
  bool _isSaving = false;
  List<String> _availableSubjects = [];
  String? _selectedSubject;
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }
  Future<void> _loadSubjects() async {
    final subjects = await ApiService().getMySubjectsForClass(widget.classId);
    if (mounted) {
      setState(() {
        _availableSubjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects[0] : null;
        _isLoadingSubjects = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  Future<void> _saveGrade() async {
    final subject = _availableSubjects.isEmpty
        ? _subjectController.text.trim()
        : (_selectedSubject ?? '').trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie ein Fach ein.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    final success = await ApiService().createGrade(
      studentId: widget.studentId,
      subject: subject,
      value: _selectedGrade,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      widget.onGradeAdded();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note erfolgreich eingetragen'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Speichern'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Note für ${widget.studentName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isLoadingSubjects
                  ? const Center(child: CircularProgressIndicator())
                  : _availableSubjects.isEmpty
                      ? TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Fach *',
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
              const Text('Note:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  final grade = index + 1;
                  final isSelected = _selectedGrade == grade;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGrade = grade),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$grade',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  hintText: 'z.B. Klassenarbeit Kapitel 5',
                  border: OutlineInputBorder(),
                ),
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
          onPressed: _isSaving ? null : _saveGrade,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }
}