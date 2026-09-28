import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';

class MascotChatScreen extends StatefulWidget {
  const MascotChatScreen({super.key});

  @override
  State<MascotChatScreen> createState() => _MascotChatScreenState();
}

class _MascotChatScreenState extends State<MascotChatScreen> {
  final List<Map<String, String>> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;
  bool _kiAvailable = true;
  bool _isLoadingHistory = true;
  String _storageKey = 'chat_default';
  String get _mascotImageUrl => '${ApiService.baseUrl}/mascot/image';

  @override
  void initState() {
    super.initState();
    _init();
  }
  Future<void> _init() async {
    await _checkKi();
    await _loadHistory();
  }
  Future<void> _checkKi() async {
    final available = await ApiService().checkMascotAvailable();
    if (mounted) {
      setState(() => _kiAvailable = available);
    }
  }
  Future<void> _loadHistory() async {
    final key = await ApiService().getChatStorageKey();
    _storageKey = key;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (mounted) {
      setState(() {
        if (json != null) {
          try {
            final decoded = jsonDecode(json) as List;
            for (final item in decoded) {
              if (item is Map) {
                final msg = Map<String, String>.from(item);
                if (msg.containsKey('role') && msg.containsKey('content')) {
                  _messages.add(msg);
                }
              }
            }
          } catch (e) {
            _messages.clear();
          }
        }
        if (_messages.isEmpty) {
          _messages.add({
            'role': 'assistant',
            'content': 'Hallo! Ich bin Lottie. \nWie kann ich helfen?',
          });
        }
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    }
  }
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();  
    final toSave = _messages.length > 100
        ? _messages.sublist(_messages.length - 100)
        : _messages; 
    final json = jsonEncode(toSave);
    await prefs.setString(_storageKey, json);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;
    _inputController.clear();
    final history = List<Map<String, String>>.from(_messages);
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isThinking = true;
    });
    _scrollToBottom();
    _saveHistory();
    final reply = await ApiService().sendMascotMessage(text, history);
    if (!mounted) return;
    setState(() {
      _isThinking = false;
      _messages.add({
        'role': 'assistant',
        'content': reply ?? 'Ohh, ich bin gerade etwas müde. 😴\nVersuch es gleich noch einmal!',
      });
    });
    _scrollToBottom();
    _saveHistory();
  }
  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Verlauf löschen?'),
          ],
        ),
        content: const Text(
          'Möchtest du den gesamten Chat-Verlauf mit Lottie löschen?\n\n'
          'Dies kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _messages.clear();
        _messages.add({
          'role': 'assistant',
          'content': 'Hallo! Ich bin Lottie, dein Schulmaskottchen! \nWie kann ich helfen?',
        });
      });
      await _saveHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat-Verlauf gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.network(
                _mascotImageUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Icon(Icons.pets, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Lottie',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoadingHistory && _messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
              tooltip: 'Chat-Verlauf löschen',
            ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_kiAvailable)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: Colors.orange.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.orange.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Die KI ist gerade offline. Lottie kann erst antworten, wenn der Server läuft.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildThinkingBubble();
                      }
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.orange.shade400 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(16),
                              bottomLeft: isUser
                                  ? const Radius.circular(16)
                                  : const Radius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                ClipOval(
                                  child: Image.network(
                                    _mascotImageUrl,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.pets, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    color: isUser ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            maxLines: 3,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Frag Lottie etwas...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: _isThinking ? null : _send,
                          backgroundColor: Colors.orange.shade400,
                          child: _isThinking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.network(
                _mascotImageUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Icon(Icons.pets, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            _ThinkingVideo(url: '${ApiService.baseUrl}/mascot/animation'),
            const SizedBox(width: 8),
            Text(
              'Lottie denkt nach...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
class _ThinkingVideo extends StatefulWidget {
  final String url;
  const _ThinkingVideo({required this.url});

  @override
  State<_ThinkingVideo> createState() => _ThinkingVideoState();
}
class _ThinkingVideoState extends State<_ThinkingVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }
  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) {
        setState(() => _controller = controller);
      }
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return const SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }
    return SizedBox(
      width: 60,
      height: 60,
      child: ClipOval(
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}