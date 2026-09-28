import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }
  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await ApiService().getMyTasks();
    if (mounted) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(tasks);
        _isLoading = false;
      });
    }
  }
  Future<void> _toggleComplete(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();
    final isCompleted = task['is_completed'] == true;
    final result = isCompleted
        ? await ApiService().uncompleteTask(taskId)
        : await ApiService().completeTask(taskId);
    if (result != null && mounted) {
      setState(() {
        final index = _tasks.indexWhere((t) => t['id'] == task['id']);
        if (index != -1) {
          _tasks[index]['is_completed'] = result['is_completed'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: result['is_completed'] == true ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  String _formatDueDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = date.difference(now).inDays;    
      final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';     
      if (diff < 0) return 'Überfällig!';
      if (diff == 0) return 'Heute fällig';
      if (diff == 1) return 'Morgen fällig';
      return '📅 $dateStr';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTasks = List<Map<String, dynamic>>.from(_tasks)
      ..sort((a, b) {
        final aCompleted = a['is_completed'] == true;
        final bCompleted = b['is_completed'] == true;
        if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
        return (a['due_date'] ?? '').toString().compareTo((b['due_date'] ?? '').toString());
      });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
        backgroundColor: Colors.amber.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, size: 64, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Aufgaben!',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
                      final isOverdue = task['is_overdue'] == true;
                      final isCompleted = task['is_completed'] == true;   
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCompleted
                                ? Colors.green.shade300
                                : (isOverdue ? Colors.red.shade300 : Colors.transparent),
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: isCompleted ? 0.6 : 1.0,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: isCompleted
                                  ? Colors.green.shade50
                                  : (isOverdue ? Colors.red.shade50 : Colors.amber.shade50),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : (isOverdue ? Icons.warning : Icons.assignment),
                                color: isCompleted
                                    ? Colors.green.shade700
                                    : (isOverdue ? Colors.red.shade700 : Colors.amber.shade700),
                              ),
                            ),
                            title: Text(
                              task['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
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
                                    color: isCompleted ? Colors.green : (isOverdue ? Colors.red : Colors.grey.shade700),
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
                              icon: Icon(
                                isCompleted ? Icons.undo : Icons.check_circle_outline,
                                size: 28,
                              ),
                              color: isCompleted ? Colors.orange : Colors.green,
                              onPressed: () => _toggleComplete(task),
                              tooltip: isCompleted ? 'Wieder öffnen' : 'Als erledigt markieren',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}