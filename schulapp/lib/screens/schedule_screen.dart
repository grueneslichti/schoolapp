import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> _scheduleEntries = [];
  bool _isLoading = true;
  int _selectedDay = DateTime.now().weekday - 1;
  String? _myClassId;
  final List<String> _weekDays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  final List<String> _weekDaysFull = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getMySchedule(),
      ApiService().getMyInfo(),
    ]);
    final entries = results[0] as List<dynamic>;
    final myInfo = results[1] as Map<String, dynamic>?;
    final resolvedClassId = (myInfo?['class_id'] ?? _extractClassIdFromEntries(entries))?.toString();
    if (mounted) {
      setState(() {
        _scheduleEntries = List<Map<String, dynamic>>.from(entries);
        _myClassId = resolvedClassId;
        _isLoading = false;
      });
    }
  }
  String? _extractClassIdFromEntries(List<dynamic> entries) {
    for (final entry in entries) {
      if (entry is Map<String, dynamic> && entry['class_id'] != null) {
        return entry['class_id'].toString();
      }
      if (entry is Map && entry['class_id'] != null) {
        return entry['class_id'].toString();
      }
    }
    return null;
  }
  List<Map<String, dynamic>> get _entriesForSelectedDay {
    final filtered = _scheduleEntries.where((e) => e['day_of_week'] == _selectedDay).toList();
    filtered.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));
    return filtered;
  }
  Color _getSubjectColor(String subject) {
    final hash = subject.toLowerCase().hashCode;
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.red.shade400, Colors.amber.shade700, Colors.indigo,
      Colors.pink, Colors.cyan, Colors.brown, Colors.deepPurple,
    ];
    return colors[hash.abs() % colors.length];
  }
  void _showAddEntryDialog() {
    final fallbackClassId = _myClassId ?? _extractClassIdFromEntries(_scheduleEntries);
    if (fallbackClassId == null || fallbackClassId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Klasse gefunden'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _myClassId = fallbackClassId);
    showDialog(
      context: context,
      builder: (ctx) => _AddStudentEntryDialog(
        classId: fallbackClassId,
        dayOfWeek: _selectedDay,
        onEntryCreated: _loadSchedule,
      ),
    );
  }
  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('Möchtest du "${entry['subject']}" wirklich löschen?'),
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
      final success = await ApiService().deleteStudentScheduleEntry(entry['id']);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eintrag gelöscht'), backgroundColor: Colors.green),
        );
        _loadSchedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mein Stundenplan'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('success')
                : Colors.green.shade600,
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
                    Container(
                      color: isDark ? Colors.grey.shade800 : Colors.green.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: List.generate(7, (index) {
                          final isSelected = _selectedDay == index;
                          final isToday = index == DateTime.now().weekday - 1;
                          return Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedDay = index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green.shade600
                                      : (isToday ? Colors.green.shade100 : Colors.transparent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _weekDays[index],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : (isToday ? Colors.green.shade800 : Colors.grey.shade700),
                                      ),
                                    ),
                                    if (isToday)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.green.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            _weekDaysFull[_selectedDay],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showAddEntryDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Eigener Eintrag'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _entriesForSelectedDay.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Keine Stunden am ${_weekDaysFull[_selectedDay]}.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSchedule,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _entriesForSelectedDay.length,
                                itemBuilder: (context, index) {
                                  final entry = _entriesForSelectedDay[index];
                                  final subjectColor = _getSubjectColor(entry['subject'] ?? '');
                                  final isTeacherEntry = entry['created_by_role'] == 'teacher';
                                  final isEditable = entry['is_editable'] == true;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: isDark ? Colors.grey.shade800 : Colors.white,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: Container(
                                        width: 8,
                                        decoration: BoxDecoration(
                                          color: subjectColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(
                                            entry['subject'] ?? 'Unbekannt',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isTeacherEntry ? Colors.blue.shade50 : Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isTeacherEntry ? Colors.blue.shade200 : Colors.green.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              isTeacherEntry ? 'Lehrer' : 'Von dir',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isTeacherEntry ? Colors.blue.shade700 : Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${entry['start_time']} - ${entry['end_time']}',
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                            ),
                                            if (entry['room'] != null && entry['room'].toString().isNotEmpty) ...[
                                              const SizedBox(width: 12),
                                              Icon(Icons.room, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                entry['room'],
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      trailing: isEditable
                                          ? IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.red,
                                              onPressed: () => _deleteEntry(entry),
                                              tooltip: 'Löschen',
                                            )
                                          : Icon(
                                              Icons.lock_outline,
                                              size: 18,
                                              color: Colors.grey.shade400,
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

class _AddStudentEntryDialog extends StatefulWidget {
  final String classId;
  final int dayOfWeek;
  final VoidCallback onEntryCreated;
  const _AddStudentEntryDialog({
    required this.classId,
    required this.dayOfWeek,
    required this.onEntryCreated,
  });

  @override
  State<_AddStudentEntryDialog> createState() => _AddStudentEntryDialogState();
}

class _AddStudentEntryDialogState extends State<_AddStudentEntryDialog> {
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  bool _isSaving = false;
  final List<String> _weekDays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

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
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  Future<void> _saveEntry() async {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib ein Fach ein'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    final result = await ApiService().createStudentScheduleEntry(
      classId: widget.classId,
      subject: _subjectController.text.trim(),
      dayOfWeek: widget.dayOfWeek,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null && !result.containsKey('error')) {
      widget.onEntryCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eintrag hinzugefügt'), backgroundColor: Colors.green),
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
      title: Text('Eigener Eintrag am ${_weekDays[widget.dayOfWeek]}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dieser Eintrag ist nur für dich sichtbar.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Fach / Aktivität *',
                  hintText: 'z.B. AG Fußball, Nachhilfe...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(isStart: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Startzeit *',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(_startTime.format(context), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(isStart: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Endzeit *',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled),
                      const SizedBox(width: 8),
                      Text(_endTime.format(context), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Ort (optional)',
                  hintText: 'z.B. Sporthalle, Raum 105...',
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
          onPressed: _isSaving ? null : _saveEntry,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Hinzufügen'),
        ),
      ],
    );
  }
}