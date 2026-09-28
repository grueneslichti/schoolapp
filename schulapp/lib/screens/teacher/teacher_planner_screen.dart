import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TeacherPlannerScreen extends StatefulWidget {
  const TeacherPlannerScreen({super.key});

  @override
  State<TeacherPlannerScreen> createState() => _TeacherPlannerScreenState();
}

class _TeacherPlannerScreenState extends State<TeacherPlannerScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }
  Future<void> _loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? appointmentsString = prefs.getString('teacher_appointments');   
    if (appointmentsString != null) {
      setState(() {
        final List<dynamic> decoded = jsonDecode(appointmentsString);
        _appointments = decoded.map((e) => e as Map<String, dynamic>).toList();
        _appointments.sort((a, b) => a['datetime'].compareTo(b['datetime']));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }
  Future<void> _saveAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_appointments', jsonEncode(_appointments));
  }
  void _showAddAppointmentDialog() {
    final titleController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    String selectedType = 'meeting';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neuer Termin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titel (z.B. "Elterngespräch Max M.")',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Datum (YYYY-MM-DD)',
                    hintText: '2024-06-15',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Uhrzeit (HH:MM)',
                    hintText: '14:30',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Ort (optional)',
                    hintText: 'Zimmer 204',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Typ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'meeting', child: Text('📅 Besprechung')),
                    DropdownMenuItem(value: 'exam', child: Text('📝 Prüfung')),
                    DropdownMenuItem(value: 'class', child: Text('🎓 Unterricht')),
                    DropdownMenuItem(value: 'other', child: Text('📌 Sonstiges')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty &&
                    dateController.text.trim().isNotEmpty &&
                    timeController.text.trim().isNotEmpty) {
                  final newAppointment = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': titleController.text.trim(),
                    'date': dateController.text.trim(),
                    'time': timeController.text.trim(),
                    'datetime': '${dateController.text.trim()} ${timeController.text.trim()}',
                    'location': locationController.text.trim(),
                    'type': selectedType,
                  };

                  setState(() {
                    _appointments.add(newAppointment);
                    _appointments.sort((a, b) => a['datetime'].compareTo(b['datetime']));
                  });
                  
                  _saveAppointments();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
  void _deleteAppointment(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: const Text('Möchten Sie diesen Termin wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _appointments.removeAt(index);
              });
              _saveAppointments();
              Navigator.pop(context);              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Termin gelöscht'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  String _getTypeIcon(String type) {
    switch (type) {
      case 'meeting': return '📅';
      case 'exam': return '📝';
      case 'class': return '🎓';
      case 'other': return '📌';
      default: return '📅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminplaner'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Termine vorhanden.',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tippe auf +, um einen neuen Termin zu erstellen.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = _appointments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Text(
                            _getTypeIcon(appointment['type']),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        title: Text(
                          appointment['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  appointment['date'],
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  appointment['time'],
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            if (appointment['location'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment['location'],
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteAppointment(index),
                          tooltip: 'Termin löschen',
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppointmentDialog,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Neuer Termin'),
      ),
    );
  }
}