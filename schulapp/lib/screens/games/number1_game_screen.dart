import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class Number1GameScreen extends StatefulWidget {
  final String difficulty;
  const Number1GameScreen({super.key, required this.difficulty});
  @override
  State<Number1GameScreen> createState() => _Number1GameScreenState();
}
class _Number1GameScreenState extends State<Number1GameScreen> {
  static const int gridCols = 6;
  static const int gridRows = 5;
  List<List<int>> _grid = [];
  List<List<bool>> _activeTiles = [];
  int _playerX = 0;
  int _playerY = 0;
  int _targetNumber = 0;
  int _score = 0;
  int _life = 100;
  int _currentMaxNumber = 10;
  bool _gameOver = false;
  bool _isLoading = false; //Muss da sein!!!
  bool _isNewRecord = false;
  String? _lockedAxis;
  bool _showTutorial = true;
  bool _isRestoring = true;
  static const String _storagePrefix = 'Number1Game_state_';
  String get _stateKey => '$_storagePrefix${widget.difficulty}';
  final Random _random = Random();
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
    final tutorialSeen = prefs.getBool('number_game_tutorial_seen') ?? false;
    
    if (mounted) {
      setState(() => _showTutorial = !tutorialSeen);
    }
  }
  Future<void> _hideTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('number_game_tutorial_seen', true);
    if (mounted) {
      setState(() => _showTutorial = false);
    }
  }
  void _startFresh() {
    _score = 0;
    _life = 100;
    _isNewRecord = false;
    _playerX = 0;
    _playerY = 0;
    _gameOver = false;
    _lockedAxis = null;
    _currentMaxNumber = 10;
    _generateGrid();
    _setNewTarget();
  }
  void _initGame() {
    setState(_startFresh);
    _saveCurrentState();
  }
  Future<void> _restoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = _decodeState(prefs.getString(_stateKey));
    if (!loaded) {
      _startFresh();
    }
    _gameOver = false;
    _isNewRecord = false;
    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }
  Future<void> _newGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neues Spiel starten?'),
        content: const Text('Dein aktueller Fortschritt wird gelöscht.'),
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
      await _clearSavedState();
      setState(_startFresh);
      await _saveCurrentState();
    }
  }
  String _encodeState() {
    return jsonEncode({
      'grid': _grid,
      'activeTiles': _activeTiles,
      'playerX': _playerX,
      'playerY': _playerY,
      'targetNumber': _targetNumber,
      'score': _score,
      'life': _life,
      'currentMaxNumber': _currentMaxNumber,
      'lockedAxis': _lockedAxis,
    });
  }
  bool _decodeState(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final grid = (data['grid'] as List)
          .map((row) => (row as List).map((value) => (value as num).toInt()).toList())
          .toList();
      final activeTiles = (data['activeTiles'] as List)
          .map((row) => (row as List).map((value) => value as bool).toList())
          .toList();
      final life = (data['life'] as num).toInt();
      if (life <= 0 || grid.length != gridRows || activeTiles.length != gridRows) return false;
      if (grid.any((row) => row.length != gridCols) ||
          activeTiles.any((row) => row.length != gridCols)) {
        return false;
      }
      _grid = grid;
      _activeTiles = activeTiles;
      _playerX = (data['playerX'] as num).toInt();
      _playerY = (data['playerY'] as num).toInt();
      _targetNumber = (data['targetNumber'] as num).toInt();
      _score = (data['score'] as num).toInt();
      _life = life;
      _currentMaxNumber = (data['currentMaxNumber'] as num).toInt();
      _lockedAxis = data['lockedAxis'] as String?;
      return _playerX >= 0 && _playerX < gridCols && _playerY >= 0 && _playerY < gridRows;
    } catch (_) {
      return false;
    }
  }
  Future<void> _saveCurrentState() async {
    if (_gameOver || _grid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, _encodeState());
  }
  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
  void _generateGrid() {
    _grid = List.generate(gridRows, (_) => 
      List.generate(gridCols, (_) => _random.nextInt(_currentMaxNumber) + 1)
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
      for (int i = 0; i < regenCount && i < toRegen.length; i++) {
        final row = toRegen[i][0];
        final col = toRegen[i][1];
        _grid[row][col] = _random.nextInt(_currentMaxNumber) + 1;
      }
    }
  }
  void _setNewTarget() {
    _targetNumber = _random.nextInt(_currentMaxNumber) + 1;
  }
  void _updateDifficulty() {
    var newMax = 10 + (_score ~/ 100) * 5;
    if (newMax > 50) newMax = 50;
    _currentMaxNumber = newMax;
  }
  void _movePlayer(int dx, int dy) {
    if (_gameOver) return; 
    setState(() {
      if (_lockedAxis == null) {
        if (dx != 0) {
          _lockedAxis = 'x';
        } else if (dy != 0) {
          _lockedAxis = 'y';
        }
      }
      int newX = _playerX;
      int newY = _playerY; 
      if (_lockedAxis == 'x' && dx != 0) {
        newX = _playerX + dx;
      } else if (_lockedAxis == 'y' && dy != 0) {
        newY = _playerY + dy;
      }
      if (newX >= 0 && newX < gridCols) _playerX = newX;
      if (newY >= 0 && newY < gridRows) _playerY = newY;
    });
    _saveCurrentState();
  }
  void _activateTile() {
    if (_gameOver) return;
    setState(() {
      int tileValue = _grid[_playerY][_playerX];
      bool isActive = _activeTiles[_playerY][_playerX];
      if (!isActive) {
        _life -= 10;
        _setNewTarget();
      } else if (tileValue >= _targetNumber) {
        int points = tileValue == _targetNumber ? 10 : tileValue * 5;
        _score += points;
        _activeTiles[_playerY][_playerX] = false;
        _setNewTarget();
        _updateDifficulty();
        _regenerateSomeTiles();
      } else {
        _life -= 10;
        _setNewTarget();
      }
      _lockedAxis = null;
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
      gameType: 'number_hunt',
      difficulty: widget.difficulty,
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
              child: Text(_isNewRecord ? 'Neuer Klassenrekord! ' : 'Spiel beendet!'),
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
  Color _getTileBorderColor(int value, bool isActive) {
    if (!isActive) return Colors.grey.shade600;
    if (value <= 10) return Colors.white.withValues(alpha: 0.5);
    if (value <= 20) return Colors.white.withValues(alpha: 0.6);
    if (value <= 30) return Colors.white.withValues(alpha: 0.7);
    if (value <= 40) return Colors.white.withValues(alpha: 0.8);
    return Colors.white;
  }
  Color _getTileColor(int value) {
    if (value <= 10) return Colors.lightBlue.shade300;
    if (value <= 20) return const Color.fromARGB(255, 61, 189, 67);
    if (value <= 30) return Colors.orange.shade300;
    if (value <= 40) return Colors.yellow.shade300;
    return Colors.white;
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
        title: const Text('Zahlen-Jagd'),
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
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('$_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) _movePlayer(1, 0);
              if (details.primaryVelocity! < 0) _movePlayer(-1, 0);
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 0) _movePlayer(0, 1);
              if (details.primaryVelocity! < 0) _movePlayer(0, -1);
            },
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('ZIEL:', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        '$_targetNumber',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lockedAxis == null 
                        ? Colors.green.shade100 
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lockedAxis == null 
                        ? 'Wähle eine Richtung (X oder Y)'
                        : 'Achse gesperrt: ${_lockedAxis == 'x' ? 'Horizontal (X)' : 'Vertikal (Y)'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _lockedAxis == null 
                          ? Colors.green.shade900 
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _life / 100,
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
                        return Container(
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
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.black87 : Colors.transparent,
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
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showTutorial) ...[
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
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
                              Icon(Icons.school, color: Colors.amber.shade700, size: 32),
                              const SizedBox(width: 12),
                              Text(
                                'Spielanleitung',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTutorialSection(
                            'Ziel',
                            'Finde Zahlen auf dem Spielfeld, die größer oder gleich der ZIEL-Vorgabe sind!',
                          ),
                          _buildTutorialSection(
                            '🎮 Steuerung',
                            'Swipe nach links/rechts für Links/Rechts-Achse\nSwipe nach oben/unten für Oben/Unten-Achse\nWichtig: Du kannst nur in EINE Richtung bewegen, bis du ein Feld aktivierst!',
                          ),
                          _buildTutorialSection(
                            'Richtige Aktivierung',
                            'Zahl ist gleich Ziel-Vorgabe: +10 Punkte\nZahl größer Ziel-Vorgbae: +5 Punkte\nFelder werden deaktiviert',
                          ),
                          _buildTutorialSection(
                            'Falsche Aktivierung',
                            'Zahl kleiner als Ziel: -10 Leben\nLeeres Feld: -10 Leben\nIn beiden Fällen: Eine neue Zahl-Vorgabe!',
                          ),
                          _buildTutorialSection(
                            'Achtung!',
                            'Alle 100 Punkte steigen die maximalen Zahlen bis auf ein maximum von 50.\nEinige Felder werden nach jeder Aktivierung neu generiert!\nManchmal muss man eine niedrigere Zahl nehmen, oder ein leeres Feld aktivieren',
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