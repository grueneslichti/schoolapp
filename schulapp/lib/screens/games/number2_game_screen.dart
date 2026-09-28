import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class Number2GameScreen extends StatefulWidget {
  const Number2GameScreen({super.key});

  @override
  State<Number2GameScreen> createState() => _Number2GameScreenState();
}
class _Number2GameScreenState extends State<Number2GameScreen> {
  static const int gridCols = 6;
  static const int gridRows = 5;
  static const int maxLife = 100;
  static const int lifeLoss = 10;
  List<List<int>> _grid = [];
  List<List<bool>> _activeTiles = [];
  int _playerX = 0;
  int _playerY = 0;
  int _targetNumber = 0;
  String _targetEquation = '';
  int _score = 0;
  int _life = maxLife;
  bool _gameOver = false;
  bool _isLoading = false;
  bool _isNewRecord = false;
  String _difficulty = 'easy';
  bool _showTutorial = false;
  static const String _tutorialKey = 'Number2GameScreen_tutorial_seen';
  static const String _storagePrefix = 'Number2Game_state_';
  static const String _lastDifficultyKey = 'Number2Game_lastDifficulty';
  String get _stateKey => '$_storagePrefix$_difficulty';
  bool _isRestoring = true;
  final Random _random = Random();

  int get _minNumber {
    switch (_difficulty) {
      case 'easy': return 5;
      case 'medium': return -40;
      case 'hard': return -800; 
      default: return 5;
    }
  }
  int _signedInt(int minAbs, int maxAbs, {bool nonZero = false}) {
    int amount;
    do {
      amount = minAbs + _random.nextInt(maxAbs - minAbs + 1);
    } while (nonZero && amount == 0);
    if (amount == 0) return 0;
    return _random.nextBool() ? amount : -amount;
  }
  String _sub(int left, int right) {
    return right < 0 ? '$left + ${-right}' : '$left - $right';
  }
  int _splitPart(int sum) {
    if (sum == 0) return _signedInt(1, 15, nonZero: true);
    final fraction = 0.25 + _random.nextDouble() * 0.5;
    return (sum * fraction).round();
  }
  int get _maxNumber {
    switch (_difficulty) {
      case 'easy': return 800;
      case 'medium': return 1500;
      case 'hard': return 5000;
      default: return 800;
    }
  }
  int get _pointsPerEquation {
    switch (_difficulty) {
      case 'easy': return 15;
      case 'medium': return 30;
      case 'hard': return 50;
      default: return 15;
    }
  }
  int get _equationMinNumber {
    switch (_difficulty) {
      case 'easy': return -500;
      case 'medium': return -1500;
      case 'hard': return -3000;
      default: return -500;
    }
  }
  int get _equationMaxNumber {
    switch (_difficulty) {
      case 'easy': return 500;
      case 'medium': return 1500;
      case 'hard': return 3000;
      default: return 500;
    }
  }

  int _randomEquationNumberInRange({
    bool nonZero = false,
    bool avoidOne = true,
    int minimumAbsolute = 0,
  }) {
    bool isAllowed(int value) {
      return (!nonZero || value != 0) &&
          (!avoidOne || value.abs() != 1) &&
          value.abs() >= minimumAbsolute;
    }
    if (!nonZero && !avoidOne && minimumAbsolute == 0) {
      return _equationMinNumber +
          _random.nextInt(_equationMaxNumber - _equationMinNumber + 1);
    }
    int value;
    do {
      value = _equationMinNumber +
          _random.nextInt(_equationMaxNumber - _equationMinNumber + 1);
    } while (!isAllowed(value));
    return value;
  }
  String _add(int left, int right) {
    return right < 0 ? '$left - ${-right}' : '$left + $right';
  }
  String _subtractFromZero(int value) {
    return value < 0 ? '+ ${-value}' : '- $value';
  }
  String _addToExpression(int value) {
    return value < 0 ? '- ${-value}' : '+ $value';
  }
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
  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tutorialKey) ?? false;
    if (mounted) {
      setState(() => _showTutorial = !seen);
    }
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
      setState(() => _startFresh());
      await _saveCurrentState();
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

  Future<void> _restoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDiff = prefs.getString(_lastDifficultyKey) ?? 'easy';
    _difficulty = lastDiff;

    final loaded = await _loadState(lastDiff);
    if (!loaded) {
      _startFresh();
    }
    _gameOver = false;
    _isNewRecord = false;

    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _hideTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
    if (mounted) {
      setState(() => _showTutorial = false);
    }
  }

  void _startFresh() {
    _score = 0;
    _life = maxLife;
    _gameOver = false;
    _playerX = 0;
    _playerY = 0;
    _generateGrid();
    _setNewTarget();
  }

  void _initGame() {
    setState(() {
      _isNewRecord = false;
      _startFresh();
    });
      _saveCurrentState();
  }
  void _generateGrid() {
    final range = _maxNumber - _minNumber + 1;
    _grid = List.generate(gridRows, (_) =>
      List.generate(gridCols, (_) => _minNumber + _random.nextInt(range))
    );
    _activeTiles = List.generate(gridRows, (_) =>
      List.generate(gridCols, (_) => true)
    );
  }
  void _regenerateSomeTiles() {
    final activeTiles = <List<int>>[];
    for (int row = 0; row < gridRows; row++) {
      for (int col = 0; col < gridCols; col++) {
        if (_activeTiles[row][col]) {
          activeTiles.add([row, col]);
        }
      }
    }
    final regenCount = (activeTiles.length * 0.3).ceil();
    if (activeTiles.isNotEmpty && regenCount > 0) {
      final toRegen = List<List<int>>.from(activeTiles)..shuffle();
      final range = _maxNumber - _minNumber + 1;
      for (int i = 0; i < regenCount && i < toRegen.length; i++) {
        final row = toRegen[i][0];
        final col = toRegen[i][1];
        _grid[row][col] = _minNumber + _random.nextInt(range);
      }
    }
  }
  void _setNewTarget() {
    final activeValues = <int>[];
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (_activeTiles[r][c]) {
          activeValues.add(_grid[r][c]);
        }
      }
    }
    if (activeValues.isEmpty) {
      _generateGrid();
      for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
          activeValues.add(_grid[r][c]);
        }
      }
    }
    _targetNumber = activeValues[_random.nextInt(activeValues.length)];
    _targetEquation = _buildEquation(_targetNumber, _difficulty);
  }
  String _buildEquation(int target, String difficulty) {
    switch (difficulty) {
      case 'easy': return _buildEasyEquation(target);
      case 'medium': return _buildMediumEquation(target);
      case 'hard': return _buildHardEquation(target);
      default: return '$target';
    }
  }
  String _buildEasyEquation(int t) {
      final b = _signedInt(20, 150, nonZero: true);
      final c = _signedInt(20, 150, nonZero: true);
      final a = t + c - b;
      return '${_add(a, b)} ${_subtractFromZero(c)}';
      }
  String _encodeState() {
    return jsonEncode({
      'grid': _grid,
      'activeTiles': _activeTiles,
      'playerX': _playerX,
      'playerY': _playerY,
      'targetNumber': _targetNumber,
      'targetEquation': _targetEquation,
      'score': _score,
      'life': _life,
    });
  }
  bool _decodeState(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final grid = (data['grid'] as List)
          .map((row) => (row as List).map((e) => (e as num).toInt()).toList())
          .toList();
      final activeTiles = (data['activeTiles'] as List)
          .map((row) => (row as List).map((e) => e as bool).toList())
          .toList();
      final life = (data['life'] as num).toInt();
      if (life <= 0) return false;
      if (grid.length != gridRows) return false;
      _grid = grid;
      _activeTiles = activeTiles;
      _playerX = (data['playerX'] as num).toInt();
      _playerY = (data['playerY'] as num).toInt();
      _targetNumber = (data['targetNumber'] as num).toInt();
      _targetEquation = data['targetEquation'] as String;
      _score = (data['score'] as num).toInt();
      _life = life;
      return true;
    } catch (e) {
      return false;
    }
  }
  Future<void> _saveCurrentState() async {
    if (_gameOver) return;
    if (_grid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, _encodeState());
    await prefs.setString(_lastDifficultyKey, _difficulty);
  }
  Future<bool> _loadState(String difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$difficulty');
    return _decodeState(raw);
  }
  Future<void> _changeDifficulty(String diff) async {
    if (diff == _difficulty) return;
    await _saveCurrentState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDifficultyKey, diff);
    if (!mounted) return;
    setState(() => _difficulty = diff);
    final loaded = await _loadState(diff);
    if (!mounted) return;
    setState(() {
      if (!loaded) {
        _startFresh();
      }
      _gameOver = false;
      _isNewRecord = false;
      _isLoading = false;
    });
  }
  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
  String _buildMediumEquation(int t) {
    if (_random.nextBool()) {
      final a = _signedInt(2, 12, nonZero: true);
      final b = _signedInt(2, 12, nonZero: true);
      final d = _signedInt(10, 150, nonZero: true);
      final c = t - (a * b) + d;
      return '($a × $b) ${_addToExpression(c)} ${_subtractFromZero(d)}';
  } else {final b = 2 + _random.nextInt(11);
      final q = _signedInt(2, 15, nonZero: true); 
      final a = b * q;
      final d = _signedInt(10, 150, nonZero: true);
      final c = t - q + d;
      return '($a ÷ $b) ${_addToExpression(c)} ${_subtractFromZero(d)}';
    }
  }
  String _buildHardEquation(int t) {
    final c = 3 + _random.nextInt(13);
    var s = (t / c).round();
    var d = t - s * c;
    if (d == 0) {
      s += 1;
      d = t - s * c;
    }
    if (_random.nextBool()) {
      final a = _splitPart(s);
      final b = s - a;
      return '((${_add(a, b)}) × $c) ${_addToExpression(d)}';
    } else {
      final b = _signedInt(3, 40, nonZero: true);
      final a = s + b;
      return '((${_sub(a, b)}) × $c) ${_addToExpression(d)}';
    }
  }
  void _jumpToTile(int row, int col) {
    if (_gameOver) return;
    setState(() {
      _playerX = col;
      _playerY = row;
    });
  }
  void _activateTile() {
    if (_gameOver) return;
    setState(() {
      int tileValue = _grid[_playerY][_playerX];
      bool isActive = _activeTiles[_playerY][_playerX];
      if (!isActive) {
        _life -= lifeLoss;
        _regenerateSomeTiles();
        _setNewTarget();
      } else {
        if (tileValue == _targetNumber) {
          _score += _pointsPerEquation;
          _activeTiles[_playerY][_playerX] = false;
          _regenerateSomeTiles();
          _setNewTarget();
        } else {
          _life -= lifeLoss;
          _setNewTarget();
        }
      }
      _checkGameOver();
    });
    _saveCurrentState();
  }
  void _checkGameOver() {
    if (_life <= 0) {
      _life = 0;
      _gameOver = true;
      _submitScore();
    }
  }
  Future<void> _submitScore() async {
    setState(() => _isLoading = true);
    await _clearSavedState();
    final result = await ApiService().submitGameScore(
      gameType: 'mathe_jagd',
      difficulty: _difficulty,
      score: _score,
    );
    setState(() => _isLoading = false);
    if (mounted && result != null && !result.containsKey('error')) {
      _isNewRecord = result['is_new_class_record'] == true;
      _showResultDialog(result);
    }
  }
  void _showResultDialog(Map<String, dynamic> result) {
    final xpEarned = result['xp_earned'] ?? 0;
    final classRank = result['class_rank'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _isNewRecord ? Icons.emoji_events : Icons.sports_score,
              color: _isNewRecord ? Colors.amber : Colors.blue,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_isNewRecord ? 'Neuer Klassenrekord! 🎉' : 'Spiel beendet!'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erreichte Punkte: $_score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '+$xpEarned XP verdient!',
              style: TextStyle(fontSize: 16, color: Colors.green.shade700),
            ),
            if (classRank != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dein Rang in der Klasse: #$classRank',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Beenden'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initGame();
            },
            child: const Text('Nochmal spielen'),
          ),
        ],
      ),
    );
  }
  Color _getTileColor(int value) {
    return const Color.fromARGB(255, 58, 159, 209);
  }
  Color _getTileBorderColor(int value, bool isActive) {
    if (!isActive) return Colors.grey.shade600;
    return Colors.white.withValues(alpha: 0.6);
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
      appBar: AppBar(
        title: const Text('Mathe-Jagd'),
        backgroundColor: const Color.fromARGB(255, 89, 119, 255),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
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
                const Icon(Icons.scoreboard, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('$_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      Expanded(child: _buildDiffButton('medium', 'Mittel', Colors.orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDiffButton('hard', 'Schwer', Colors.red)),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 1, 95, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('LÖSE DIE GLEICHUNG:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        _targetEquation,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '= ?',
                        style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _life / maxLife,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _life > 50 ? Colors.green : (_life > 25 ? Colors.orange : Colors.red),
                          ),
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$_life', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCols,
                        childAspectRatio: 1,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: gridRows * gridCols,
                      itemBuilder: (context, index) {
                        int row = index ~/ gridCols;
                        int col = index % gridCols;
                        bool isPlayer = row == _playerY && col == _playerX;
                        bool isActive = _activeTiles[row][col];
                        int value = _grid[row][col];
                        return GestureDetector(
                          onTap: () => _jumpToTile(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isActive ? _getTileColor(value) : const Color.fromARGB(255, 7, 6, 6),
                              borderRadius: BorderRadius.circular(8),
                              border: isPlayer
                                  ? Border.all(color: const Color.fromARGB(255, 253, 255, 255), width: 4)
                                  : Border.all(
                                      color: _getTileBorderColor(value, isActive),
                                      width: 2,
                                    ),
                            ),
                            child: Center(
                              child: Text(
                                isActive ? '$value' : '',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.black87 : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _gameOver ? null : _activateTile,
                      icon: const Icon(Icons.touch_app),
                      label: const Text('Feld aktivieren'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 70, 12),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
                              Icon(Icons.calculate, color: Colors.amber.shade700, size: 32),
                              const SizedBox(width: 12),
                              const Text(
                                'Mathe-Jagd Anleitung',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTutorialSection(
                            'Ziel',
                            'Löse die Gleichung im Kopf und finde das EXAKTE Ergebnis auf dem Spielfeld!',
                          ),
                          _buildTutorialSection(
                            'Steuerung',
                            'Cursorbewegung durch Tippen.\nTippe auf "Feld aktivieren" wenn du die richtige Zahl ausgewählt hast.',
                          ),
                          _buildTutorialSection(
                            'Richtig',
                            'Deine Zahl = Ergebnis der Gleichung:\nDu bekommst Punkte und das Feld verschwindet.\nEine neue Gleichung erscheint!',
                          ),
                          _buildTutorialSection(
                            'Falsch',
                            'Eine andere Zahl oder ein leeres Feld:\n-10 Leben und eine neue Gleichung erscheint.',
                          ),
                          _buildTutorialSection(
                            'Schwierigkeit',
                            'Wähle oben zwischen Einfach, Mittel und Schwer.\nJe schwerer, desto komplexer die Gleichungen und desto mehr Punkte gibt es!',
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _hideTutorial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
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