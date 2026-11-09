import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/game_model.dart';

/// Πέναλτι: ο παίκτης σουτάρει 5 φορές σε μία από τις 3 ζώνες του τέρματος.
/// Ο τερματοφύλακας πηδά τυχαία σε μία ζώνη. Τα γκολ είναι η βαθμολογία.
///
/// Οι πόντοι προκύπτουν μόνο από τα γκολ (`goals × pointsPerGoal`), και
/// δεν συνδέονται με δώρα ή κλήρωση. Η κατάταξη βασίζεται στους πόντους.
class PenaltyPlayScreen extends StatefulWidget {
  final GameModel game;
  const PenaltyPlayScreen({super.key, required this.game});

  @override
  State<PenaltyPlayScreen> createState() => _PenaltyPlayScreenState();
}

class _PenaltyPlayScreenState extends State<PenaltyPlayScreen> {
  static const int _totalKicks = 5;
  static const List<String> _zoneLabels = ['Αριστερά', 'Κέντρο', 'Δεξιά'];

  final Random _rng = Random();

  bool _checking = true;
  bool _canPlay = false;
  String? _limitMessage;

  int _kicks = 0;
  int _goals = 0;
  bool _busy = false;
  bool _finished = false;
  int? _shotZone;
  int? _keeperZone;
  String? _result;
  int _pointsWon = 0;

  /// Πόντοι ανά γκολ: το μέγιστο του παιχνιδιού ÷ 5 σουτ, ώστε 5 γκολ να δίνουν το μέγιστο.
  int get _pointsPerGoal {
    final perGoal = widget.game.maxPoints ~/ _totalKicks;
    return perGoal < 1 ? 1 : perGoal;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkLimit);
  }

  Future<void> _checkLimit() async {
    final user = context.read<AppProvider>().user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _canPlay = false;
        _limitMessage = 'Συνδέσου για να παίξεις.';
      });
      return;
    }
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('game_plays')
          .where('userId', isEqualTo: user.uid)
          .where('gameId', isEqualTo: widget.game.id)
          .where('playedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      if (!mounted) return;
      final played = snap.docs.length;
      setState(() {
        _checking = false;
        _canPlay = played < widget.game.dailyLimit;
        _limitMessage = _canPlay
            ? null
            : 'Έφτασες το ημερήσιο όριο (${widget.game.dailyLimit}/μέρα). Δοκίμασε αύριο!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _canPlay = false;
        _limitMessage = 'Σφάλμα: $e';
      });
    }
  }

  Future<void> _shoot(int zone) async {
    if (_busy || _finished || !_canPlay) return;
    setState(() {
      _busy = true;
      _shotZone = zone;
      _keeperZone = _rng.nextInt(3);
      _result = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final scored = _shotZone != _keeperZone;
    setState(() {
      if (scored) _goals++;
      _result = scored ? 'ΓΚΟΛ!' : 'Σεηβ!';
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _kicks++;
    if (_kicks >= _totalKicks) {
      await _finish();
    } else {
      setState(() {
        _busy = false;
        _shotZone = null;
        _keeperZone = null;
        _result = null;
      });
    }
  }

  Future<void> _finish() async {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    final won = _goals * _pointsPerGoal;

    setState(() {
      _finished = true;
      _canPlay = false;
      _busy = false;
      _pointsWon = won;
    });
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
        {'points': FieldValue.increment(won)},
      );
      batch.set(FirebaseFirestore.instance.collection('game_plays').doc(), {
        'userId': user.uid,
        'userName': user.name,
        'gameId': widget.game.id,
        'gameTitle': widget.game.title,
        'gameType': 'penalty',
        'goals': _goals,
        'pointsWon': won,
        'playedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      provider.updateUser(user.copyWith(points: user.points + won));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Σφάλμα αποθήκευσης: $e'), backgroundColor: AppTheme.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.game.title),
        backgroundColor: Colors.transparent,
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_limitMessage != null && !_finished)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _limitMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  Text(
                    'Γκολ: $_goals / $_kicks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Κάθε γκολ = $_pointsPerGoal pts',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _goalArea(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 32,
                    child: Text(
                      _result ?? (_busy ? '' : 'Διάλεξε ζώνη για να σουτάρεις'),
                      style: TextStyle(
                        color: _result == 'ΓΚΟΛ!' ? AppTheme.accent : Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_finished)
                    Column(
                      children: [
                        Text(
                          'Κέρδισες $_pointsWon πόντους!',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Επιστροφή'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _goalArea() {
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/penalty/goal.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Row(
            children: List.generate(3, (i) {
              final isKeeper = _keeperZone == i && _result != null;
              final isShot = _shotZone == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (_canPlay && !_busy && !_finished) ? () => _shoot(i) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isKeeper
                          ? AppTheme.liveRed.withValues(alpha: 0.35)
                          : (isShot
                              ? AppTheme.accent.withValues(alpha: 0.2)
                              : Colors.transparent),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _zoneLabels[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
