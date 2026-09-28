import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}
class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _scheduleEntries = [];
  bool _isLoading = true;
  int _selectedDay = 0;
  final List<String> _weekDays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  @override
  void initState() {
    super.initState();
    _loadClasses();
  }
  Future<void> _loadClasses() async {
    final classes = await ApiService().getClasses();
    if (!mounted) return;
    setState(() {
      _classes = List<Map<String, dynamic>>.from(classes);
      _isLoading = false;
      if (_classes.isNotEmpty) {
        _selectedClassId = _classes.first['id'].toString();
      }
    });
    if (_selectedClassId != null) _loadSchedule();
  }
  Future<void> _loadSchedule() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoading = true);
    final entries = await ApiService().getTeacherClassSchedule(
      _selectedClassId!,
    );
    if (!mounted) return;
    setState(() {
      _scheduleEntries = List<Map<String, dynamic>>.from(entries);
      _isLoading = false;
    });
  }
  List<Map<String, dynamic>> get _entriesForSelectedDay {
    final entries = _scheduleEntries
        .where((entry) => entry['day_of_week'] == _selectedDay)
        .toList();
    entries.sort(
      (a, b) =>
          (a['start_time'] as String).compareTo(b['start_time'] as String),
    );
    return entries;
  }
  void _showAddEntryDialog() {
    if (_selectedClassId == null) return;
    showDialog(
      context: context,
      builder: (context) => _AddEntryDialog(
        classId: _selectedClassId!,
        dayOfWeek: _selectedDay,
        onEntryCreated: _loadSchedule,
      ),
    );
  }
  Future<void> _deleteEntry(String entryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text(
          'Dieser Stundenplan-Eintrag wird für alle Schüler der Klasse entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ApiService().deleteTeacherScheduleEntry(entryId);
    if (!success || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
    _loadSchedule();
  }
  Future<void> _endLesson(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stunde beenden?'),
        content: const Text(
          'Nach dem Beenden können die Schüler die Stunde bewerten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ApiService().signalLessonEnd(
      classId: _selectedClassId!,
      subject: entry['subject'].toString(),
    );
    if (!mounted) return;
    final error = result?['error'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Stunde beendet. Die Bewertung ist jetzt geöffnet.'
              : error.toString(),
        ),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }
  Color _getSubjectColor(String subject) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.amber,
      Colors.indigo,
    ];
    return colors[subject.toLowerCase().hashCode.abs() % colors.length];
  }
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Stundenplan verwalten'),
          backgroundColor: themeManager.colorBlindMode
              ? themeManager.getColor('success')
              : Colors.teal.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSchedule,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Klasse wählen',
                        border: OutlineInputBorder(),
                      ),
                      items: _classes
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry['id'].toString(),
                              child: Text('Klasse ${entry['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedClassId = value);
                        _loadSchedule();
                      },
                    ),
                  ),
                  Row(
                    children: List.generate(
                      7,
                      (index) => Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedDay = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: _selectedDay == index
                                ? Colors.teal.shade600
                                : Colors.teal.shade50,
                            child: Text(
                              _weekDays[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedDay == index
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _entriesForSelectedDay.isEmpty
                        ? Center(
                            child: Text(
                              'Keine Stunden am ${_weekDays[_selectedDay]}.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _entriesForSelectedDay.length,
                            itemBuilder: (context, index) {
                              final entry = _entriesForSelectedDay[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: Container(
                                    width: 8,
                                    color: _getSubjectColor(
                                      entry['subject'] ?? '',
                                    ),
                                  ),
                                  title: Text(entry['subject'] ?? 'Unbekannt'),
                                  subtitle: Text(
                                    '${entry['start_time']} - ${entry['end_time']}${entry['room'] != null && entry['room'].toString().isNotEmpty ? '  |  ${entry['room']}' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.stop_circle_outlined),
                                        color: Colors.green.shade700,
                                        tooltip: 'Stunde beenden',
                                        onPressed: () => _endLesson(entry),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        tooltip: 'Eintrag löschen',
                                        onPressed: () => _deleteEntry(
                                          entry['id'].toString(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddEntryDialog,
          backgroundColor: themeManager.colorBlindMode
              ? themeManager.getColor('success')
              : Colors.teal.shade700,
          icon: const Icon(Icons.add),
          label: const Text('Stunde'),
        ),
      ),
    );
  }
}
class _AddEntryDialog extends StatefulWidget {
  final String classId;
  final int dayOfWeek;
  final VoidCallback onEntryCreated;
  const _AddEntryDialog({
    required this.classId,
    required this.dayOfWeek,
    required this.onEntryCreated,
  });
  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}
class _AddEntryDialogState extends State<_AddEntryDialog> {
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 8, minute: 45);
  bool _isSaving = false;
  final List<String> _weekDays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }
  Future<void> _selectTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null || !mounted) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  Future<void> _saveEntry() async {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte gib ein Fach ein')));
      return;
    }
    setState(() => _isSaving = true);
    final result = await ApiService().createTeacherScheduleEntry(
      classId: widget.classId,
      subject: _subjectController.text.trim(),
      dayOfWeek: widget.dayOfWeek,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      room: _roomController.text.trim().isEmpty
          ? null
          : _roomController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null && !result.containsKey('error')) {
      widget.onEntryCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stunde erfolgreich hinzugefügt')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result?['error'] ?? 'Fehler')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Neue Stunde am ${_weekDays[widget.dayOfWeek]}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Fach *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Startzeit'),
            trailing: Text(_startTime.format(context)),
            onTap: () => _selectTime(isStart: true),
          ),
          ListTile(
            title: const Text('Endzeit'),
            trailing: Text(_endTime.format(context)),
            onTap: () => _selectTime(isStart: false),
          ),
          TextField(
            controller: _roomController,
            decoration: const InputDecoration(
              labelText: 'Raum (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      ElevatedButton(
        onPressed: _isSaving ? null : _saveEntry,
        child: const Text('Hinzufügen'),
      ),
    ],
  );
}