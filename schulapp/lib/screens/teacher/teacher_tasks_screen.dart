import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherTasksScreen extends StatefulWidget {
  const TeacherTasksScreen({super.key});

  @override
  State<TeacherTasksScreen> createState() => _TeacherTasksScreenState();
}

class _TeacherTasksScreenState extends State<TeacherTasksScreen> {
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

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
          _loadTasks();
        }
      });
    }
  }
  Future<void> _loadTasks() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoading = true);
    final tasks = await ApiService().getClassTasks(_selectedClassId!); 
    if (mounted) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(tasks);
        _isLoading = false;
      });
    }
  }
  void _showAddTaskDialog() {
    if (_selectedClassId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _AddTaskDialog(
        classId: _selectedClassId!,
        onTaskCreated: _loadTasks,
      ),
    );
  }
  Future<void> _deleteTask(String taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aufgabe löschen?'),
        content: const Text('Möchten Sie diese Aufgabe wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ApiService().deleteTask(taskId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aufgabe gelöscht'), backgroundColor: Colors.green),
        );
        _loadTasks();
      }
    }
  }
  String _formatDueDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = date.difference(now).inDays;    
      final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';    
      if (diff < 0) return 'Überfällig! ($dateStr)';
      if (diff == 0) return 'Heute fällig! ($dateStr)';
      if (diff == 1) return 'Morgen fällig ($dateStr)';
      return '📅 $dateStr';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Aufgaben'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('warning')
                : Colors.amber.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Klasse wählen',
                          border: OutlineInputBorder(),
                        ),
                        items: _classes.map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text('Klasse ${c['name']}'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedClassId = val);
                            _loadTasks();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _tasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Keine Aufgaben für diese Klasse.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTasks,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _tasks.length,
                                itemBuilder: (context, index) {
                                  final task = _tasks[index];
                                  final isOverdue = task['is_overdue'] == true;    
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isOverdue ? Colors.red.shade300 : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: CircleAvatar(
                                        backgroundColor: isOverdue ? Colors.red.shade50 : Colors.amber.shade50,
                                        child: Icon(
                                          isOverdue ? Icons.warning : Icons.assignment,
                                          color: isOverdue ? Colors.red.shade700 : Colors.amber.shade700,
                                        ),
                                      ),
                                      title: Text(
                                        task['title'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text('Fach: ${task['subject'] ?? ''}', style: TextStyle(fontSize: 13)),
                                          Text(
                                            _formatDueDate(task['due_date']?.toString()),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isOverdue ? Colors.red : Colors.grey.shade700,
                                              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task['description'],
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () => _deleteTask(task['id']),
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
            onPressed: _showAddTaskDialog,
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('warning')
                : Colors.amber.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Aufgabe'),
          ),
        );
      },
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  final String classId;
  final VoidCallback onTaskCreated;
  const _AddTaskDialog({required this.classId, required this.onTaskCreated});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _availableSubjects = [];
  String? _selectedSubject;
  bool _isLoadingSubjects = true;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;

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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }
  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Fach und Titel ausfüllen'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    final dueDateStr = '${_dueDate.year.toString().padLeft(4, '0')}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}';
    final result = await ApiService().createTask(
      classId: widget.classId,
      subject: _selectedSubject!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      dueDate: dueDateStr,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null && !result.containsKey('error')) {
      widget.onTaskCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aufgabe erstellt'), backgroundColor: Colors.green),
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
      title: const Text('Neue Aufgabe'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isLoadingSubjects
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  : _availableSubjects.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Sie haben keine Fächer für diese Klasse zugewiesen bekommen.',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'Fach *',
                            border: OutlineInputBorder(),
                          ),
                          items: _availableSubjects.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedSubject = val),
                        ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel *',
                  hintText: 'z.B. Hausaufgaben Seite 42',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fällig am',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text('${_dueDate.day.toString().padLeft(2, '0')}.${_dueDate.month.toString().padLeft(2, '0')}.${_dueDate.year}'),
                    ],
                  ),
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
          onPressed: _isSaving ? null : _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Erstellen'),
        ),
      ],
    );
  }
}