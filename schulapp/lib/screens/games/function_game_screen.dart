import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../widgets/function_graph.dart';

class FunctionGameScreen extends StatefulWidget {
  const FunctionGameScreen({super.key});

  @override
  State<FunctionGameScreen> createState() => _FunctionGameScreenState();
}
class _FunctionGameScreenState extends State<FunctionGameScreen> {
  String _difficulty = 'easy';
  Map<String, dynamic>? _currentTask;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedAnswer;
  bool? _wasCorrect;
  int _totalCorrect = 0;
  int _totalAttempts = 0;
  int _xpEarned = 0;
  int _functionPoints = 0;
  String _errorMessage = '';
  bool _showTutorial = false;
  static const String _tutorialKey = 'FunctionGameScreen_tutorial_seen';
  static const String _storagePrefix = 'FunctionGameScreen_state_';
  static const String _lastDifficultyKey = 'FunctionGameScreen_lastDifficulty';
  static const String _functionPointsKey = 'FunctionGameScreen_functionPoints';
  bool _isRestoring = true;
  String get _stateKey => '$_storagePrefix$_difficulty';

  @override
  void initState() {
    super.initState();
    _checkTutorial();
    _restoreGame();
  }

  @override
  void dispose() {
    _saveCurrentState();
    super.dispose();
  }
  String _encodeState() {
    return jsonEncode({
      'totalCorrect': _totalCorrect,
      'totalAttempts': _totalAttempts,
      'xpEarned': _xpEarned,
    });
  }
  bool _decodeState(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _totalCorrect = (data['totalCorrect'] as num).toInt();
      _totalAttempts = (data['totalAttempts'] as num).toInt();
      _xpEarned = (data['xpEarned'] as num).toInt();
      return true;
    } catch (e) {
      return false;
    }
  }
  Future<void> _saveCurrentState() async {
    if (_gridIsEmpty()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, _encodeState());
    await prefs.setString(_lastDifficultyKey, _difficulty);
    await prefs.setInt(_functionPointsKey, _functionPoints);
  }
  bool _gridIsEmpty() => _totalAttempts == 0 && _totalCorrect == 0;
  Future<bool> _loadState(String difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$difficulty');
    return _decodeState(raw);
  }
  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
  Future<void> _restoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDiff = prefs.getString(_lastDifficultyKey) ?? 'easy';
    _difficulty = lastDiff;
    await _loadState(lastDiff);
    _functionPoints = prefs.getInt(_functionPointsKey) ?? 0;
    await _loadTask();
    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }
  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tutorialKey) ?? false;
    if (mounted) {
      setState(() => _showTutorial = !seen);
    }
  }
  Future<void> _hideTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
    if (mounted) {
      setState(() => _showTutorial = false);
    }
  }
  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
      _isSubmitting = false;
      _selectedAnswer = null;
      _wasCorrect = null;
      _errorMessage = '';
    });
    final task = await ApiService().getFunctionTask(difficulty: _difficulty);
    if (mounted) {
      if (task != null && !task.containsKey('error')) {
        setState(() {
          _currentTask = task;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = task?['error'] ?? 'Unbekannter Fehler beim Laden';
          _isLoading = false;
        });
      }
    }
  }

  void _selectAnswer(String answer) {
    if (_isSubmitting || _wasCorrect != null) return;
    setState(() => _selectedAnswer = answer);
  }
  Future<void> _submitAnswer() async {
    if (_isSubmitting || _selectedAnswer == null || _currentTask == null) return;
    setState(() => _isSubmitting = true);
    final result = await ApiService().submitFunctionAnswer(
      answer: _selectedAnswer!,
      correctAnswer: _currentTask!['correct_answer'],
      difficulty: _difficulty,
    );
    if (mounted && result != null) {
      setState(() {
        _wasCorrect = result['is_correct'] == true;
        _totalAttempts++;
        if (_wasCorrect!) {
          _totalCorrect++;
          _xpEarned += (result['xp_earned'] as num?)?.toInt() ?? 0;
          _functionPoints = (result['total_function_points'] as num?)?.toInt() ?? _functionPoints;
        }
        _isSubmitting = false;
      });
      _saveCurrentState();
      if (result['is_correct'] == true) {
        await _loadTask();
      } else {
        _showResultDialog(false, 0);
      }
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  void _showResultDialog(bool isCorrect, int xpEarned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(isCorrect ? 'Richtig!' : 'Leider falsch'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCorrect)
              Text(
                '+$xpEarned XP verdient!',
                style: TextStyle(fontSize: 18, color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            Text(
              'Richtige Antwort: ${_currentTask?['correct_answer']}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadTask();
            },
            child: const Text('Nächste Aufgabe'),
          ),
        ],
      ),
    );
  }
  Future<void> _changeDifficulty(String diff) async {
    if (diff == _difficulty) return;
    await _saveCurrentState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDifficultyKey, diff);
    if (!mounted) return;
    setState(() => _difficulty = diff);
    await _loadState(diff);
    await _loadTask();
  }
  Future<void> _newGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neues Spiel starten?'),
        content: Text('Dein Fortschritt in "${_difficultyLabel(_difficulty)}" wird gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Neu starten'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _totalCorrect = 0;
        _totalAttempts = 0;
        _xpEarned = 0;
      });
      await _clearSavedState();
      await _loadTask();
    }
  }
  String _difficultyLabel(String diff) {
    switch (diff) {
      case 'easy': return 'Einfach';
      case 'medium': return 'Mittel';
      case 'hard': return 'Schwer';
      default: return diff;
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return Scaffold(
        backgroundColor: Colors.grey.shade900,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Function Master'),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Neues Spiel',
            onPressed: _newGame,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => setState(() => _showTutorial = true),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('$_xpEarned XP', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade800,
                child: Row(
                  children: [
                    Expanded(child: _buildDiffButton('easy', 'Einfach', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDiffButton('medium','Mittel', Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDiffButton('hard','Schwer', Colors.red)),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentTask == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  'Fehler beim Laden',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade300),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _loadTask,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Erneut versuchen'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Card(
                                  color: Colors.grey.shade800,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentTask!['question'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (_currentTask!['graph_type'] != null) ...[
                                          Center(
                                            child: FunctionGraph(
                                              graphType: _currentTask!['graph_type'],
                                              graphPoints: _currentTask!['graph_points'],
                                              graphLines: _currentTask!['graph_lines'],
                                              size: 200,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Antwortmöglichkeiten:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '👆 Tippe auf eine Antwort, dann "Aktivieren"',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 12),
                                ...(_currentTask!['options'] as List<dynamic>).map((option) {
                                  final isSelected = _selectedAnswer == option;
                                  final showCorrect = _wasCorrect != null && option == _currentTask!['correct_answer'];
                                  final showWrong = _wasCorrect == false && isSelected;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () => _selectAnswer(option),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: showCorrect
                                              ? Colors.green.shade900
                                              : showWrong
                                                  ? Colors.red.shade900
                                                  : isSelected
                                                      ? Colors.deepPurple.shade800
                                                      : Colors.grey.shade800,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: showCorrect
                                                ? Colors.green
                                                : showWrong
                                                    ? Colors.red
                                                    : isSelected
                                                        ? Colors.cyan
                                                        : Colors.grey.shade600,
                                            width: isSelected || showCorrect || showWrong ? 3 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton.icon(
                                    onPressed: _selectedAnswer == null || _isSubmitting || _wasCorrect != null
                                        ? null
                                        : _submitAnswer,
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.touch_app),
                                    label: Text(_isSubmitting ? 'Wird geprüft...' : 'Aktivieren'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  color: Colors.deepPurple.shade900,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem('✅ Richtig', '$_totalCorrect', Colors.green),
                                        _buildStatItem('📊 Gesamt', '$_totalAttempts', Colors.grey.shade300),
                                        _buildStatItem('⭐ Punkte', '$_functionPoints', Colors.amber),
                                        _buildStatItem('⚡ XP', '$_xpEarned', Colors.lightBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          if (_showTutorial) ...[
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.functions, color: Colors.deepPurple.shade400, size: 32),
                              const SizedBox(width: 12),
                              const Text(
                                'Function Master Anleitung',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTutorialSection(
                            'Ziel',
                            'Löse die Mathe-Aufgabe und wähle die richtige Antwort aus!',
                          ),
                          _buildTutorialSection(
                            'Steuerung',
                            'Tippe auf eine Antwortmöglichkeit.\nDrücke dann "Aktivieren" um deine Antwort zu bestätigen.',
                          ),
                          _buildTutorialSection(
                            'Richtig',
                            'Richtige Antwort:\nDu bekommst Punkte und eine neue Aufgabe erscheint!',
                          ),
                          _buildTutorialSection(
                            'Falsch',
                            'Falsche Antwort:\nDie richtige Antwort wird angezeigt und eine neue Aufgabe erscheint.',
                          ),
                          _buildTutorialSection(
                            'Schwierigkeit',
                            'Wähle oben zwischen Einfach, Mittel und Schwer.\nJe schwerer, desto mehr Punkte gibt es pro richtiger Antwort. 100 Punkte ergeben 1 XP.',
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _hideTutorial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Verstanden!', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildDiffButton(String diff, String label, Color color) {
    final isSelected = _difficulty == diff;
    return ElevatedButton(
      onPressed: () => _changeDifficulty(diff),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ],
    );
  }
  Widget _buildTutorialSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }
}