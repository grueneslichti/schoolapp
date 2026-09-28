import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'games/number1_game_screen.dart';
import 'games/number2_game_screen.dart';
import 'games/function_game_screen.dart';
import '../services/game_access_manager.dart';

class ChallengeScreen extends StatefulWidget {
  final String schoolType;
  
  const ChallengeScreen({super.key, required this.schoolType});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}
class _ChallengeScreenState extends State<ChallengeScreen> {
  bool _isLoading = true;
  bool _canPlay = false;
  String _statusMessage = '';
  Map<String, dynamic>? _classHighscores;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final status = await ApiService().checkChallengeStatus();
    final difficulty = widget.schoolType == 'primary' ? 'primary' : 'easy';
    final highscores = await ApiService().getClassHighscores(
      gameType: 'number_hunt',
      difficulty: difficulty,
    );
    if (mounted) {
      setState(() {
        _canPlay = status?['can_play'] == true;
        _statusMessage = status?['message'] ?? '';
        _classHighscores = highscores;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielwiese'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _canPlay ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(
                        _canPlay ? Icons.play_circle : Icons.lock,
                        color: _canPlay ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: _canPlay ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (widget.schoolType == 'primary')
                      _buildGameCard(
                        title: '🧮 Zahlen-Jagd',
                        description: 'Finde Zahlen, die größer oder gleich dem Ziel sind!',
                        icon: Icons.grid_4x4,
                        color: Colors.amber.shade700,
                        onTap: () async {
                          await GameAccessManager.tryOpenGame(
                            context: context,
                            gameType: 'number_hunt',
                            gameName: 'Zahlen-Jagd',
                            gameBuilder: () => const Number1GameScreen(
                              difficulty: 'primary',
                            ),
                          );
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (widget.schoolType == 'secondary') ...[
                      _buildGameCard(
                        title: '🧮 Zahlen-Jagd',
                        description: 'Finde Zahlen, die gleich dem Ziel sind!',
                        icon: Icons.grid_4x4,
                        color: Colors.amber.shade700,
                        onTap: () async {
                          await GameAccessManager.tryOpenGame(
                            context: context,
                            gameType: 'mathe_jagd',
                            gameName: 'Zahlen-Jagd',
                            gameBuilder: () => const Number2GameScreen(),
                          );
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 16)],
                      if (widget.schoolType == 'high') ...[
                      _buildGameCard(
                      title: '📐 Function Master',
                      description: 'Funktionen auswerten, Graphen erkennen und Wahrscheinlichkeiten berechnen!',
                      icon: Icons.functions,
                      color: Colors.deepPurple.shade700,
                      onTap: () async {
                      await GameAccessManager.tryOpenGame(
                      context: context,
                      gameType: 'function_master',
                      gameName: 'Function Master',
                      gameBuilder: () => const FunctionGameScreen(),
                      );
                      _loadData();
                      },
                    ),
                  ],
                      if (_classHighscores != null) ...[
                        const Text(
                          '🏆 Klassen-Bestenliste',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildHighscoreList(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  Widget _buildGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(
                onTap != null ? Icons.chevron_right : Icons.lock,
                color: onTap != null ? Colors.grey.shade400 : Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHighscoreList() {
    final topScores = _classHighscores?['top_scores'] as List? ?? [];
    final myBest = _classHighscores?['my_best_score'];
    final myRank = _classHighscores?['my_rank'];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myBest != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Dein Rekord: $myBest Punkte',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (myRank != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('#$myRank'),
                      backgroundColor: Colors.purple.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
            ],  
            if (topScores.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Noch keine Highscores in der Klasse. Sei der Erste!'),
                ),
              )
            else
              ...topScores.asMap().entries.map((entry) {
                final index = entry.key;
                final score = entry.value;
                final isMe = score['is_me'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.purple.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: isMe ? Border.all(color: Colors.purple.shade300) : null,
                  ),
                  child: Row(
                    children: [
                      // Rang
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index < 3 
                              ? [Colors.amber, Colors.grey.shade400, Colors.orange.shade300][index]
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3 ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name
                      Expanded(
                        child: Text(
                          score['student_name'] ?? score['pseudonym'] ?? 'Unbekannt',
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      // Score
                      Text(
                        '${score['score']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}