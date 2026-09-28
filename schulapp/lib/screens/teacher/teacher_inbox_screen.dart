import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme_manager.dart';

class TeacherInboxScreen extends StatefulWidget {
  const TeacherInboxScreen({super.key});

  @override
  State<TeacherInboxScreen> createState() => _TeacherInboxScreenState();
}
class _TeacherInboxScreenState extends State<TeacherInboxScreen> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }
  Future<void> _loadInbox() async {
    setState(() => _isLoading = true);
    final feedbacks = await ApiService().getMyInbox(unreadOnly: _showUnreadOnly);
    if (mounted) {
      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(feedbacks);
        _isLoading = false;
        _selectedIds.clear();
        _selectionMode = false;
      });
    }
  }
  Future<void> _markAsRead(String feedbackId) async {
    await ApiService().markFeedbackAsRead(feedbackId);
    _loadInbox();
  }
  Future<void> _deleteFeedback(String feedbackId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nachricht löschen?'),
        content: const Text('Möchtest du diese Nachricht wirklich löschen?\nSie kann nicht wiederhergestellt werden.'),
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
      final success = await ApiService().deleteFeedback(feedbackId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nachricht gelöscht'), backgroundColor: Colors.green),
        );
        _loadInbox();
      }
    }
  }
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mehrere Nachrichten löschen?'),
        content: Text('${_selectedIds.length} Nachrichten werden gelöscht.\nSie können nicht wiederhergestellt werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('${_selectedIds.length} löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await ApiService().bulkDeleteFeedbacks(_selectedIds.toList());
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInbox();
      }
    }
  }
  void _toggleSelection(String feedbackId) {
    setState(() {
      if (_selectedIds.contains(feedbackId)) {
        _selectedIds.remove(feedbackId);
      } else {
        _selectedIds.add(feedbackId);
      }
    });
  }
  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _feedbacks.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_feedbacks.map((f) => f['id'].toString()));
      }
    });
  }
  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
            title: _selectionMode
                ? Text('${_selectedIds.length} ausgewählt')
                : const Text('Posteingang-Schüler'),
            backgroundColor: themeManager.colorBlindMode
                ? themeManager.getColor('accent')
                : Colors.purple.shade700,
            foregroundColor: Colors.white,
            actions: [
              if (_selectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectAll,
                  tooltip: 'Alle auswählen',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                  tooltip: 'Ausgewählte löschen',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                  tooltip: 'Auswahl beenden',
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _selectionMode = true),
                  tooltip: 'Mehrfachauswahl',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInbox),
              ],
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.filter_list),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _showUnreadOnly ? 'Nur ungelesene Nachrichten' : 'Alle Nachrichten',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch(
                      value: _showUnreadOnly,
                      onChanged: (val) {
                        setState(() => _showUnreadOnly = val);
                        _loadInbox();
                      },
                      activeThumbColor: Colors.purple.shade600,
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sie sehen nur Nachrichten aus Klassen, wo Sie als "Zuständig" eingetragen sind.',
                        style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _feedbacks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mark_email_read, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _showUnreadOnly
                                      ? 'Keine ungelesenen Nachrichten.'
                                      : 'Keine Nachrichten vorhanden.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadInbox,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _feedbacks.length,
                              itemBuilder: (context, index) {
                                final feedback = _feedbacks[index];
                                final isRead = feedback['is_read'] == true;
                                final isAnonymous = feedback['is_anonymous'] == true;
                                final studentName = feedback['student_name'];
                                final feedbackId = feedback['id'].toString();
                                final isSelected = _selectedIds.contains(feedbackId);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: isRead ? 1 : 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.purple.shade400
                                          : (isRead ? Colors.transparent : Colors.purple.shade300),
                                      width: isSelected ? 3 : 2,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (_selectionMode) {
                                        _toggleSelection(feedbackId);
                                      } else {
                                        if (!isRead) _markAsRead(feedbackId);
                                      }
                                    },
                                    onLongPress: () {
                                      if (!_selectionMode) {
                                        setState(() {
                                          _selectionMode = true;
                                          _selectedIds.add(feedbackId);
                                        });
                                      } else {
                                        _toggleSelection(feedbackId);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_selectionMode) ...[
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (_) => _toggleSelection(feedbackId),
                                              activeColor: Colors.purple.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (!isRead)
                                                      Container(
                                                        width: 10,
                                                        height: 10,
                                                        margin: const EdgeInsets.only(right: 8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple.shade600,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    Text(
                                                      'Klasse ${feedback['class_name']}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      _formatDate(feedback['created_at']?.toString()),
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isAnonymous ? Icons.lock : Icons.person,
                                                      size: 16,
                                                      color: isAnonymous ? Colors.grey : Colors.blue,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isAnonymous ? 'Anonymer Schüler' : studentName ?? 'Schüler',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: isAnonymous ? Colors.grey.shade600 : Colors.blue.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (feedback['category'] != null) ...[
                                                  Chip(
                                                    label: Text(feedback['category'], style: const TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.orange.shade50,
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                                Text(
                                                  feedback['message'] ?? '',
                                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!_selectionMode) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.red.shade400,
                                              onPressed: () => _deleteFeedback(feedbackId),
                                              tooltip: 'Nachricht löschen',
                                            ),
                                          ],
                                        ],
                                      ),
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