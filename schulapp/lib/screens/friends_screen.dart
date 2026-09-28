import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _FriendRequests = [];
  int _remainingXp = 0;
  int _weeklyLimit = 15;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final friends = await ApiService().getMyFriends();
    final xpInfo = await ApiService().getRemainingXp();
    final requests = await ApiService().getFriendRequests();
    if (mounted) {
      setState(() {
        _friends = List<Map<String, dynamic>>.from(friends);
        _remainingXp = xpInfo['remaining'] ?? 0;
        _weeklyLimit = xpInfo['weekly_limit'] ?? 15;
        _FriendRequests = List<Map<String, dynamic>>.from(requests);
        _isLoading = false;
      });
    }
  }
  void _showGiveXpDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (ctx) => _GiveXpDialog(
        friend: friend,
        remainingXp: _remainingXp,
        onXpGiven: _loadData,
      ),
    );
  }
  void _showFriendRequestsScreen() {
    showDialog(
      context: context,
      builder: (ctx) => _FriendRequestsDialog(
        requests: _FriendRequests,
        onRequestsChanged: _loadData,
      ),
    );
  }
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _SearchStudentsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Freunde'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline),
                onPressed: _showFriendRequestsScreen,
                tooltip: 'Freundesanfragen'
              ),
              if (_FriendRequests.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_FriendRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showSearchDialog,
            tooltip: 'Freund hinzufügen',
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.shade900,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '$_remainingXp / $_weeklyLimit XP übrig',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Du hast noch keine Freunde.',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Frag deinen Lehrer, wie du Freunde hinzufügen kannst!',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                radius: 28,
                                child: Icon(Icons.person, color: Colors.purple.shade700, size: 30)
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend['real_name'] ?? 'Unbekannt',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      friend['pseudonym'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.school, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Klasse ${friend['class_name']}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '⭐ ${friend['xp'] ?? 0} XP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: _remainingXp > 0
                                          ? () => _showGiveXpDialog(friend)
                                          : null,
                                      icon: const Icon(Icons.card_giftcard, size: 14),
                                      label: const Text('XP', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      );
                    },
                  ),
                ),
                      );
                    }
}
class _GiveXpDialog extends StatefulWidget {
  final Map<String, dynamic> friend;
  final int remainingXp;
  final VoidCallback onXpGiven;
  const _GiveXpDialog({
    required this.friend,
    required this.remainingXp,
    required this.onXpGiven,
  });

  @override
  State<_GiveXpDialog> createState() => _GiveXpDialogState();
}
class _GiveXpDialogState extends State<_GiveXpDialog> {
  int _selectedAmount = 1;
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  Future<void> _sendXp() async {
    setState(() => _isSending = true);
    final result = await ApiService().giveXpToFriend(
      receiverId: widget.friend['id'],
      amount: _selectedAmount,
      message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (result != null) {
      if (result['success'] == true) {
        widget.onXpGiven();
        Navigator.pop(context);   
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'XP erfolgreich verschenkt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Fehler beim Verschenken'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Netzwerkfehler'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('XP an ${widget.friend['real_name']} verschenken'),
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
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Du kannst noch ${widget.remainingXp} XP diese Woche verschenken',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Wie viele XP möchtest du verschenken?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final amount = index + 1;
                  final isSelected = _selectedAmount == amount;
                  final isDisabled = amount > widget.remainingXp;
                  return GestureDetector(
                    onTap: isDisabled ? null : () => setState(() => _selectedAmount = amount),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.grey.shade300
                            : isSelected
                                ? Colors.purple.shade600
                                : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : isSelected
                                  ? Colors.purple.shade600
                                  : Colors.purple.shade200,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '+$amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDisabled
                                ? Colors.grey
                                : isSelected
                                    ? Colors.white
                                    : Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _messageController,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Nachricht (optional)',
                  hintText: 'z.B. Danke für die Hilfe in Mathe!',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isSending || widget.remainingXp <= 0 ? null : _sendXp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isSending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('$_selectedAmount XP verschenken'),
        ),
      ],
    );
  }}

class _SearchStudentsDialog extends StatefulWidget {
  const _SearchStudentsDialog();

  @override
  State<_SearchStudentsDialog> createState() => _SearchStudentsDialogState();
}

class _SearchStudentsDialogState extends State<_SearchStudentsDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Future<void> _search() async {
    if (_searchController.text.trim().length < 2) return;
    setState(() => _isSearching = true);
    final results = await ApiService().searchStudents(_searchController.text.trim());
    if (mounted) {
      setState(() {
        _results = List<Map<String, dynamic>>.from(results);
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }
  Future<void> _sendRequest(Map<String, dynamic> student) async {
    final result = await ApiService().sendFriendRequest(student['id']); 
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? result['detail'] ?? 'Anfrage gesendet'),
          backgroundColor: result.containsKey('message') ? Colors.green : Colors.red,
        ),
      );
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Freund suchen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Name oder Pseudonym...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _hasSearched ? 'Keine Schüler gefunden.' : 'Suche nach einem Schüler...',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final student = _results[index];
                            final isFriend = student['is_already_friend'] == true;
                            final requestSent = student['request_already_sent'] == true;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.purple.shade100,
                                child: Icon(Icons.person, color: Colors.purple.shade700),
                              ),
                              title: Text(student['real_name'] ?? ''),
                              subtitle: Text('Klasse ${student['class_name']}'),
                              trailing: isFriend
                                  ? const Chip(label: Text('Bereits Freund'))
                                  : requestSent
                                      ? const Chip(label: Text('Anfrage gesendet'))
                                      : IconButton(
                                          icon: const Icon(Icons.person_add, color: Colors.purple),
                                          onPressed: () => _sendRequest(student),
                                        ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
class _FriendRequestsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRequestsChanged;
  const _FriendRequestsDialog({
    required this.requests,
    required this.onRequestsChanged,
  });

  @override
  State<_FriendRequestsDialog> createState() => _FriendRequestsDialogState();
}

class _FriendRequestsDialogState extends State<_FriendRequestsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.mail, color: Colors.purple),
          const SizedBox(width: 8),
          const Text('Freundesanfragen'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: widget.requests.isEmpty
            ? const Center(
                child: Text('Keine offenen Anfragen.', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                itemCount: widget.requests.length,
                itemBuilder: (context, index) {
                  final request = widget.requests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Icon(Icons.person, color: Colors.purple.shade700),
                      ),
                      title: Text(request['sender_name'] ?? ''),
                      subtitle: Text('Klasse ${request['sender_class']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              final success = await ApiService().acceptFriendRequest(request['id']);
                              if (success) {
                                widget.onRequestsChanged();
                                Navigator.pop(context);
                              }
                            },
                            tooltip: 'Annehmen',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              final success = await ApiService().declineFriendRequest(request['id']);
                              if (success) {
                                widget.onRequestsChanged();
                                Navigator.pop(context);
                              }
                            },
                            tooltip: 'Ablehnen',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}