import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TeacherMailboxScreen extends StatefulWidget {
  const TeacherMailboxScreen({super.key});

  @override
  State<TeacherMailboxScreen> createState() => _TeacherMailboxScreenState();
}

class _TeacherMailboxScreenState extends State<TeacherMailboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _inbox = [];
  List<dynamic> _sent = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMessages();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getTeacherInbox(),
      ApiService().getTeacherSent(),
    ]);
    if (mounted) {
      setState(() {
        _inbox = results[0];
        _sent = results[1];
        _isLoading = false;
      });
    }
  }
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return iso;
    }
  }
  Future<void> _openMessage(Map<String, dynamic> msg, bool isInbox) async {
    if (isInbox && msg['is_read'] != true) {
      await ApiService().markTeacherMessageRead(msg['id']);
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['subject']?.toString().isNotEmpty == true ? msg['subject'] : '(Kein Betreff)',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              isInbox ? 'Von: ${msg['sender_name']}' : 'An: ${msg['receiver_name']}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg['message'] ?? '', style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              Text(
                _formatDate(msg['created_at']?.toString()),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
        ],
      ),
    );
    _loadMessages();
  }
  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nachricht löschen?'),
        content: const Text('Die Nachricht wird entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ApiService().deleteTeacherMessage(msg['id']);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nachricht gelöscht'), backgroundColor: Colors.green),
        );
        _loadMessages();
      }
    }
  }
  Future<void> _composeMessage() async {
    final contacts = await ApiService().getTeacherContacts();
    if (!mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine weiteren Lehrer in ihrer Schule gefunden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    String? selectedReceiver;
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Neue Nachricht'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedReceiver,
                  decoration: const InputDecoration(
                    labelText: 'Empfänger',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: contacts.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(
                        c['school_name'] != null
                            ? '${c['name']} (${c['school_name']})'
                            : '${c['name']}',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedReceiver = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Betreff (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Nachricht *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton.icon(
              onPressed: selectedReceiver == null
                  ? null
                  : () async {
                      if (messageController.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final result = await ApiService().sendTeacherMessage(
                        receiverId: selectedReceiver!,
                        message: messageController.text.trim(),
                        subject: subjectController.text.trim(),
                      );    
                      if (mounted) {
                        if (result != null && !result.containsKey('error')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nachricht gesendet ✉️'), backgroundColor: Colors.green),
                          );
                          _loadMessages();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result?['error'] ?? 'Fehler'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.send),
              label: const Text('Senden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMessageList(List<dynamic> messages, bool isInbox) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isInbox ? 'Keine empfangenen Nachrichten' : 'Keine gesendeten Nachrichten',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUnread = isInbox && msg['is_read'] != true;
        final counterpart = isInbox ? msg['sender_name'] : msg['receiver_name'];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: isUnread ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isUnread ? BorderSide(color: Colors.indigo.shade300, width: 2) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openMessage(msg, isInbox),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (isInbox) ...[
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isUnread ? Colors.indigo : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${isInbox ? 'Von' : 'An'}: $counterpart',
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isInbox)
                              Icon(
                                msg['is_read'] == true ? Icons.done_all : Icons.done,
                                size: 16,
                                color: msg['is_read'] == true ? Colors.blue : Colors.grey,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['subject']?.toString().isNotEmpty == true ? msg['subject'] : '(Kein Betreff)',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          msg['message'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(msg['created_at']?.toString()),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () => _deleteMessage(msg),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final unreadCount = _inbox.where((m) => m['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posteingang-Lehrer'),
        backgroundColor: const Color.fromARGB(255, 92, 224, 241),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.inbox),
              ),
              text: 'Eingang',
            ),
            const Tab(icon: Icon(Icons.send), text: 'Gesendet'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _composeMessage,
        backgroundColor: const Color.fromARGB(255, 70, 203, 212),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('Neue Nachricht'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(onRefresh: _loadMessages, child: _buildMessageList(_inbox, true)),
                RefreshIndicator(onRefresh: _loadMessages, child: _buildMessageList(_sent, false)),
              ],
            ),
    );
  }
}