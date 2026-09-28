import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  int selectedMinutes = 45;
  int remainingSeconds = 0;
  int elapsedSeconds = 0;
  bool isRunning = false;
  Timer? timer;

  final List<int> timeOptions = [15, 30, 45, 60];

  void startTimer() {
    setState(() {
      isRunning = true;
      remainingSeconds = selectedMinutes * 60;
      elapsedSeconds = 0;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
          elapsedSeconds++;
        });
        return;
      }
      timer.cancel();
      _finishFocusSession(completed: true);
    });
  }
  Future<void> stopTimer() async {
    if (!isRunning) {
      return;
    }
    await _finishFocusSession(completed: false);
  }

  Future<void> _finishFocusSession({required bool completed}) async {
    timer?.cancel();
    final actualMinutes = (elapsedSeconds / 60).ceil();
    setState(() {
      isRunning = false;
      remainingSeconds = 0;
      elapsedSeconds = 0;
    });

    final result = await ApiService().completeFocusSession(
      plannedMinutes: selectedMinutes,
      actualMinutes: actualMinutes,
      completed: completed,
    );
    if (!mounted) return;
    if (result != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.emoji_events : Icons.thumb_up,
                size: 64,
                color: completed ? Colors.amber : Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                '+${result['xp_earned']} XP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result['message'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Gesamt: ${result['total_xp']} XP',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Weiter'),
              ),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fehler beim Speichern. XP wurden nicht gutgeschrieben.'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pop(context);
  }
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fokus Modus'),
        backgroundColor: Colors.purple.shade400,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade100,
              Colors.indigo.shade100,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer,
                size: 100,
                color: Colors.purple,
              ),
              const SizedBox(height: 30),

              if (!isRunning) ...[
                const Text(
                  'Wähle eine Zeit:',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: timeOptions.map((minutes) {
                    final isSelected = selectedMinutes == minutes;
                    return ChoiceChip(
                      label: Text('$minutes Min'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          selectedMinutes = minutes;
                        });
                      },
                      selectedColor: Colors.purple.shade400,
                      labelStyle: TextStyle(
                        fontSize: 18,
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Fokus starten',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Konzentriere dich auf den Unterricht!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: stopTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Abbrechen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}