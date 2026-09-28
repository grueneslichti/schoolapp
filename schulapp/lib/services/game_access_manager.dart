import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class GameAccessManager {
  static Future<void> tryOpenGame({
    required BuildContext context,
    required String gameType,
    required String gameName,
    required Widget Function() gameBuilder,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    final access = await ApiService().getGameAccess(gameType);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (access == null) {
      _showError(context, 'Verbindung fehlgeschlagen');
      return;
    }
    if (!access['time_available']) {
      _showTimeBlocked(context, access['time_reason'], access['free_at']);
      return;
    }
    if (access['is_unlocked']) {
      _openGame(context, gameBuilder);
      return;
    }
    if (access['trial_active']) {
      _openGameWithTrial(context, gameBuilder, access['trial_seconds_remaining'], gameType, gameName, access['unlock_cost']);
      return;
    }
    if (!access['trial_started']) {
      _showTrialOffer(context, gameType, gameName, gameBuilder, access['unlock_cost']);
      return;
    }
    _showUnlockDialog(context, gameType, gameName, access['unlock_cost'], access['student_xp']);
  }
  static void _openGame(BuildContext context, Widget Function() builder) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => builder()));
  }
  static void _showTimeBlocked(BuildContext context, String reason, String? freeAt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Jetzt nicht spielbar')),
          ],
        ),
        content: Text(
          reason + (freeAt != null ? '\n\n🕐 Frei ab: $freeAt Uhr' : ''),
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay')),
        ],
      ),
    );
  }
  static void _showTrialOffer(
    BuildContext context,
    String gameType,
    String gameName,
    Widget Function() builder,
    int cost,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.play_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('$gameName testen?')),
          ],
        ),
        content: Text(
          'Du kannst dieses Spiel 5 Minuten kostenlos testen.\n\n'
          'Du kannst es für $cost XP dauerhaft freischalten.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Später')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().startGameTrial(gameType);
              if (context.mounted) {
                tryOpenGame(
                  context: context,
                  gameType: gameType,
                  gameName: gameName,
                  gameBuilder: builder,
                );
              }
            },
            icon: const Icon(Icons.timer),
            label: const Text('5 Min. testen'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
  static void _openGameWithTrial(
    BuildContext context,
    Widget Function() builder,
    int secondsRemaining,
    String gameType,
    String gameName,
    int cost,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrialWrapper(
          secondsRemaining: secondsRemaining,
          gameType: gameType,
          gameName: gameName,
          unlockCost: cost,
          child: builder(),
        ),
      ),
    );
  }
  static void _showUnlockDialog(
    BuildContext context,
    String gameType,
    String gameName,
    int cost,
    int studentXp,
  ) {
    final canAfford = studentXp >= cost;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('$gameName freischalten')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Die Testphase ist vorbei.\n\n'
              'Schalte das Spiel dauerhaft frei mit XP:',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              '⚡ $cost XP',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Text(
              canAfford ? 'Dein Guthaben: $studentXp XP' : 'Du hast nur $studentXp XP 😢',
              style: TextStyle(color: canAfford ? Colors.green : Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton.icon(
            onPressed: canAfford
                ? () async {
                    final result = await ApiService().unlockGame(gameType);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (result != null && !result.containsKey('error')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(canAfford ? 'Freischalten' : 'Zu wenig XP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
class TrialWrapper extends StatefulWidget {
  final int secondsRemaining;
  final String gameType;
  final String gameName;
  final int unlockCost;
  final Widget child;
  const TrialWrapper({
    super.key,
    required this.secondsRemaining,
    required this.gameType,
    required this.gameName,
    required this.unlockCost,
    required this.child,
  });

  @override
  State<TrialWrapper> createState() => _TrialWrapperState();
}

class _TrialWrapperState extends State<TrialWrapper> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _trialEnded = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.secondsRemaining;
    _startTimer();
  }
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _secondsRemaining = 0;
          _trialEnded = true;
          timer.cancel();
          _showTrialEnded();
        }
      });
    });
  }
  void _showTrialEnded() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Testphase vorbei!'),
          ],
        ),
        content: Text(
          'Die 5 Minuten sind um.\n\n'
          'Schalte ${widget.gameName} für ${widget.unlockCost} XP frei, um weiterzuspielen.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Beenden'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await ApiService().unlockGame(widget.gameType);
              if (!ctx.mounted) return;
              if (result != null && !result.containsKey('error')) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
                );
                setState(() => _trialEnded = false);
              }
            },
            icon: const Icon(Icons.lock_open_rounded),
            label: Text('Für ${widget.unlockCost} XP freischalten'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).viewPadding.top + kToolbarHeight;
    final isUrgent = _secondsRemaining < 60;
    return Stack(
      children: [
        widget.child,
        if (!_trialEnded)
          Positioned(
            top: topOffset + 6,
            right: 10,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.red.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 13,
                      color: isUrgent ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_secondsRemaining),
                      style: TextStyle(
                        color: isUrgent ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}