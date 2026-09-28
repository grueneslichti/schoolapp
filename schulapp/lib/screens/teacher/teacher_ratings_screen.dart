import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherRatingsScreen extends StatefulWidget {
  const TeacherRatingsScreen({super.key});

  @override
  State<TeacherRatingsScreen> createState() => _TeacherRatingsScreenState();
}

class _TeacherRatingsScreenState extends State<TeacherRatingsScreen> {
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _ratings = [];
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
          _loadRatings();
        }
      });
    }
  }
  Future<void> _loadRatings() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoading = true);
    final ratings = await ApiService().getClassLessonRatings(_selectedClassId!);  
    if (mounted) {
      setState(() {
        _ratings = List<Map<String, dynamic>>.from(ratings);
        _isLoading = false;
      });
    }
  }
  IconData _getSmileyIcon(int? rating, bool isNeutral) {
    if (isNeutral) return Icons.remove_circle_outline;
    switch (rating) {
      case 1: return Icons.sentiment_very_dissatisfied;
      case 2: return Icons.sentiment_dissatisfied;
      case 3: return Icons.sentiment_neutral;
      case 4: return Icons.sentiment_satisfied;
      case 5: return Icons.sentiment_very_satisfied;
      default: return Icons.help_outline;
    }
  }
  Color _getSmileyColor(int? rating, bool isNeutral) {
    if (isNeutral) return Colors.grey;
    switch (rating) {
      case 1: return Colors.red.shade700;
      case 2: return Colors.orange.shade700;
      case 3: return Colors.amber.shade700;
      case 4: return Colors.lightGreen.shade700;
      case 5: return Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Unterrichtsbewertungen'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('default')
                : Colors.deepPurple.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRatings),
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
                            _loadRatings();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _ratings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rate_review, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('Noch keine Bewertungen.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRatings,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _ratings.length,
                                itemBuilder: (context, index) {
                                  final rating = _ratings[index];
                                  final avgRating = (rating['average_rating'] ?? 0).toDouble();
                                  final totalRatings = rating['total_ratings'] ?? 0;
                                  final neutralCount = rating['neutral_count'] ?? 0;   
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ExpansionTile(
                                      leading: Icon(
                                        avgRating > 0 ? _getSmileyIcon(avgRating.round(), false) : Icons.remove_circle_outline,
                                        color: avgRating > 0 ? _getSmileyColor(avgRating.round(), false) : Colors.grey,
                                        size: 32,
                                      ),
                                      title: Text(
                                        rating['subject'] ?? 'Unbekannt',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${_formatDate(rating['signal_time'])} • $totalRatings Bewertungen',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (avgRating > 0)
                                            Text(
                                              'Ø ${avgRating.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _getSmileyColor(avgRating.round(), false),
                                              ),
                                            ),
                                          if (neutralCount > 0)
                                            Text(
                                              '$neutralCount neutral',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: (rating['ratings'] as List<dynamic>?)?.map((r) {
                                              final isNeutral = r['is_neutral'] == true;
                                              final ratingValue = r['rating'];
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      _getSmileyIcon(ratingValue, isNeutral),
                                                      color: _getSmileyColor(ratingValue, isNeutral),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            isNeutral ? 'Keine Bewertung' : 'Bewertung: $ratingValue/5',
                                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                                          ),
                                                          if (r['comment'] != null && r['comment'].toString().isNotEmpty)
                                                            Text(
                                                              '"${r['comment']}"',
                                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList() ?? [],
                                          ),
                                        ),
                                      ],
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
  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}