import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class ClassRandomizerScreen extends StatefulWidget {
  const ClassRandomizerScreen({super.key});
  @override
  State<ClassRandomizerScreen> createState() => _ClassRandomizerScreenState();
}
class _ClassRandomizerScreenState extends State<ClassRandomizerScreen> {
  List<dynamic> _classes = [];
  String? _selectedClassId;
  int _numGroups = 2;
  bool _isLoadingClasses = true;
  bool _isGenerating = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;
  final List<Color> _groupColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber.shade700,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }
  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    final classes = await ApiService().getRandomizerClasses();
    if (mounted) {
      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) {
          _selectedClassId = classes[0]['id'];
        }
        _isLoadingClasses = false;
      });
    }
  }
  Color _getGroupColor(int index) {
    return _groupColors[index % _groupColors.length];
  }
  Future<void> _generateGroups() async {
    if (_selectedClassId == null) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    final result = await ApiService().generateRandomGroups(
      classId: _selectedClassId!,
      numGroups: _numGroups,
    );
    if (!mounted) return;
    if (result != null && result.containsKey('error')) {
      setState(() {
        _errorMessage = result['error'];
        _isGenerating = false;
      });
    } else {
      setState(() {
        _result = result;
        _isGenerating = false;
      });
    }
  }
  void _copyToClipboard() {
    if (_result == null) return;
    final buffer = StringBuffer();
    buffer.writeln('Klasse ${_result!['class_name']} - ${_result!['num_groups']} Gruppen:');
    buffer.writeln();
    for (var group in _result!['groups']) {
      buffer.writeln('Gruppe ${group['group_number']} (${group['size']} Schüler):');
      for (var student in group['students']) {
        buffer.writeln('  - $student');
      }
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gruppen in Zwischenablage kopiert 📋'), backgroundColor: Colors.green),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klassen-Randomisierer'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'In Zwischenablage kopieren',
              onPressed: _copyToClipboard,
            ),
        ],
      ),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Klassen gefunden',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.indigo.shade50,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedClassId,
                            decoration: const InputDecoration(
                              labelText: 'Klasse auswählen',
                              prefixIcon: Icon(Icons.school),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _classes.map((c) {
                              return DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text('${c['name']} (${c['student_count']} Schüler)'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClassId = value;
                                _result = null;
                                _errorMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Anzahl Gruppen:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                onPressed: _numGroups > 1
                                    ? () => setState(() => _numGroups--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                iconSize: 32,
                                color: Colors.indigo,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_numGroups',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _numGroups++),
                                icon: const Icon(Icons.add_circle_outline),
                                iconSize: 32,
                                color: Colors.indigo,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isGenerating ? null : _generateGroups,
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.shuffle),
                              label: Text(_isGenerating ? 'Wird gemischt...' : 'Gruppen auslosen 🎲'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _result == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.groups_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Wähle eine Klasse und lose die Gruppen aus',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _generateGroups(),
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Text(
                                    'Klasse ${_result!['class_name']} • ${_result!['num_students']} Schüler • ${_result!['num_groups']} Gruppen',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '⬇️ Zum Neu-Mischen ziehen',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ...(_result!['groups'] as List).asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final group = entry.value;
                                    final color = _getGroupColor(index);
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.1),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${group['group_number']}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Gruppe ${group['group_number']}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: color.withValues(alpha: 1.0),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '${group['size']} Schüler',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              children: (group['students'] as List).map<Widget>((student) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.person, size: 18, color: color.withValues(alpha: 0.7)),
                                                      const SizedBox(width: 8),
                                                      Text('$student', style: const TextStyle(fontSize: 15)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}