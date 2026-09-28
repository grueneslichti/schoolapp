import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  List<Map<String, dynamic>> _unratedSignals = [];
  bool _isLoading = true;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _loadUnratedSignals();
  }
  Future<void> _loadUnratedSignals() async {
    setState(() {
      _isLoading = true;
      _emptyMessage = null;
    });
    final signals = await ApiService().getUnratedToday();
    if (!mounted) return;
    setState(() {
      _unratedSignals = signals
          .map((signal) => Map<String, dynamic>.from(signal as Map))
          .toList();
      _isLoading = false;
      if (_unratedSignals.isEmpty) {
        _emptyMessage = 'Für heute sind keine offenen Bewertungen vorhanden.';
      }
    });
  }
  Future<void> _showRatingDialog(Map<String, dynamic> signal) async {
    int? selectedRating;
    String? comment;
    final commentController = TextEditingController();
    final ratingOptions = [
      {'value': 5, 'emoji': '😄', 'label': 'Sehr gut', 'color': Colors.green},
      {'value': 4, 'emoji': '🙂', 'label': 'Gut', 'color': Colors.lightGreen},
      {'value': 3, 'emoji': '😐', 'label': 'Ganz okay', 'color': Colors.amber},
      {'value': 2, 'emoji': '🙁', 'label': 'Nicht gut', 'color': Colors.orange},
      {'value': 1, 'emoji': '😟', 'label': 'Nicht verstanden', 'color': Colors.red},
    ];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(signal['subject']?.toString() ?? 'Unterricht'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Wie war der Unterricht?'),
                const SizedBox(height: 16),
                ...ratingOptions.map((option) {
                  final value = option['value'] as int;
                  final color = option['color'] as Color;
                  final isSelected = selectedRating == value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setDialogState(() {
                        selectedRating = value;
                      }),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.18)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              option['emoji'] as String,
                              style: const TextStyle(fontSize: 34),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              option['label'] as String,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected ? color : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setDialogState(() {
                    selectedRating = null;
                  }),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Neutral bewerten'),
                ),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Kommentar (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                comment = commentController.text.trim();
                Navigator.pop(context, true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
    if (result != true || !mounted) return;
    final response = await ApiService().rateLesson(
      signalId: signal['signal_id'].toString(),
      rating: selectedRating,
      isNeutral: selectedRating == null,
      comment: comment?.isEmpty == true ? null : comment,
    );
    if (!mounted) return;
    if (response?['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response!['error'].toString())),
      );
      return;
    }
    setState(() {
      _unratedSignals.removeWhere(
        (entry) => entry['signal_id'] == signal['signal_id'],
      );
      _emptyMessage = _unratedSignals.isEmpty
          ? 'Alle heutigen Stunden wurden bewertet.'
          : null;
    });
  }
  String _formatTime(String? value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bewertung des Unterrichts'),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUnratedSignals,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUnratedSignals,
              child: _unratedSignals.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 160),
                        Icon(Icons.check_circle, size: 72, color: Colors.green),
                        const SizedBox(height: 16),
                        Center(child: Text(_emptyMessage ?? 'Keine offenen Bewertungen.')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Offene Bewertungen von heute',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Du kannst diese Stunden bis zum Tagesende nachträglich bewerten.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        ..._unratedSignals.map(
                          (signal) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.school_outlined),
                              title: Text(signal['subject']?.toString() ?? 'Unterricht'),
                              subtitle: Text(
                                'Beendet um ${_formatTime(signal['signal_time']?.toString())}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showRatingDialog(signal),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}