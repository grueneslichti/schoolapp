import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }
  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final exams = await ApiService().getMyUpcomingExams();
    if (mounted) {
      setState(() {
        _exams = List<Map<String, dynamic>>.from(exams);
        _isLoading = false;
      });
    }
  }
  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final raw = isoDate.split('T').first;
      final examDate = DateTime.parse(raw);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final examDay = DateTime(examDate.year, examDate.month, examDate.day);
      final diff = examDay.difference(today).inDays;
      final dateStr = '${examDate.day.toString().padLeft(2, '0')}.${examDate.month.toString().padLeft(2, '0')}.${examDate.year}';
      final weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
      final weekday = weekdays[examDate.weekday - 1];

      if (diff == 0) return '🔴 HEUTE ($weekday)';
      if (diff == 1) return '🟠 MORGEN ($weekday)';
      if (diff <= 3) return '🟡 $weekday ($dateStr)';
      return '$weekday, $dateStr';
    } catch (e) {
      return isoDate;
    }
  }
  int _getDaysUntil(String? isoDate) {
    if (isoDate == null) return 999;
    try {
      final raw = isoDate.split('T').first;
      final examDate = DateTime.parse(raw);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final examDay = DateTime(examDate.year, examDate.month, examDate.day);
      return examDay.difference(today).inDays;
    } catch (e) {
      return 999;
    }
  }
  Color _getUrgencyColor(int days) {
    if (days <= 0) return Colors.red.shade700;
    if (days <= 1) return Colors.orange.shade700;
    if (days <= 3) return Colors.amber.shade700;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anstehende Prüfungen'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadExams),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, size: 72, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Keine anstehenden Prüfungen!',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExams,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _exams.length,
                    itemBuilder: (context, index) {
                      final exam = _exams[index];
                      final days = _getDaysUntil(exam['exam_date']?.toString());
                      final urgencyColor = _getUrgencyColor(days);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: urgencyColor.withValues(alpha: 0.4), width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: urgencyColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      exam['subject'] ?? 'Unbekannt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: urgencyColor,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: urgencyColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      days <= 0 ? 'HEUTE!' : days == 1 ? 'MORGEN' : 'in $days Tagen',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                exam['title'] ?? 'Prüfung',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(exam['exam_date']?.toString()),
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
              );
            }
}