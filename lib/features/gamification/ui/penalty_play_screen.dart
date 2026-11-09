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

class _PenaltyPlayScreenState extends State<PenaltyPlayScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalKicks = 5;
  static const List<String> _zoneLabels = ['Αριστερά', 'Κέντρο', 'Δεξιά'];

  // Γεωμετρία σκηνής (pixels). Το τέρμα είναι στο κέντρο, οι ζώνες είναι
  // ίσα τρίτα του πλάτους του τέρματος, ώστε η διάταξη να είναι συμμετρική.
  static const double _areaHeight = 340;
  static const double _goalWidth = 300;
  static const double _goalHeight = 224; // αναλογία goal.png 1400x1045
  static const double _goalTop = 34;
  static const double _keeperHeight = 170;
  static const double _keeperWidth = 127; // 896x1200
  static const double _shooterHeight = 150;
  static const double _shooterWidth = 112;
  static const double _ballSize = 26;
  // Σημεία-στόχοι μέσα στο τέρμα, συμμετρικά γύρω από το κέντρο.
  static const List<double> _targetX = [1 / 6, 0.5, 5 / 6];
  static const double _targetY = 0.4;

  final Random _rng = Random();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

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

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
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

    // Η κίνηση (σουτ, πέταγμα μπάλας, ντάιβ τερματοφύλακα) παίζει σε ένα animation.
    await _anim.forward(from: 0);
    if (!mounted) return;
    final scored = _shotZone != _keeperZone;
    setState(() {
      if (scored) _goals++;
      _result = scored ? 'ΓΚΟΛ!' : 'Σεηβ!';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _kicks++;
    if (_kicks >= _totalKicks) {
      await _finish();
    } else {
      // Επιστροφή της μπάλας και του τερματοφύλακα στη θέση εκκίνησης.
      await _anim.animateBack(0, duration: const Duration(milliseconds: 500));
      if (!mounted) return;
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
                  const SizedBox(height: 8),
                  _goalArea(),
                  const SizedBox(height: 8),
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

  /// Τιμή ενός διαστήματος [begin, end] του animation, με καμπύλη.
  static double _ease(double v, double begin, double end, Curve curve) {
    final t = ((v - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  /// Τετραγωνική καμπύλη Bezier: η διαδρομή της μπάλας έχει καμπύλη (φέξιμο).
  static Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  Widget _goalArea() {
    return SizedBox(
      height: _areaHeight,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final v = _anim.value;
              final goalLeft = (w - _goalWidth) / 2;
              final cx = w / 2;

              // Σημεία.
              final spot = Offset(cx, _areaHeight - 20); // σημείο πέναλτι
              final shot = _shotZone ?? 1;
              final keep = _keeperZone ?? 1;
              final target = Offset(
                goalLeft + _targetX[shot] * _goalWidth,
                _goalTop + _targetY * _goalHeight,
              );

              // Τερματοφύλακας: ξεκινά στη μέση και πέφτει προς τη ζώνη του.
              final keeperRest = Offset(cx, _goalTop + _goalHeight * 0.62);
              final keeperDive = Offset(
                goalLeft + _targetX[keep] * _goalWidth,
                keeperRest.dy + 10,
              );
              final dive = _ease(v, 0.05, 0.5, Curves.easeOutCubic);
              final keeperPos = Offset.lerp(keeperRest, keeperDive, dive)!;
              final keeperTilt = (keep - 1) * 0.5 * dive;

              // Μπάλα: γκολ ή σεηβ. Η σεηβ την σταματά ο τερματοφύλακας.
              final scored = _shotZone != null && shot != keep;
              final impact = scored
                  ? target
                  : Offset(keeperPos.dx, keeperPos.dy - 30);
              final flight = _ease(v, 0.12, 0.6, Curves.easeOutCubic);
              final bend = (impact.dx - cx).sign * 60;
              final control = Offset(
                (spot.dx + impact.dx) / 2 + bend,
                (spot.dy + impact.dy) / 2 - 90,
              );
              var ballPos = _bezier(spot, control, impact, flight);
              if (!scored && v > 0.6) {
                // Αναπήδηση από τα χέρια του τερματοφύλακα.
                final rebound = Offset(
                  impact.dx + (impact.dx >= cx ? 70 : -70),
                  impact.dy + 90,
                );
                ballPos = Offset.lerp(
                  impact,
                  rebound,
                  _ease(v, 0.6, 0.9, Curves.easeOut),
                )!;
              }

              // Σουτέρ: μικρή φόρα προς τα εμπρός στην αρχή της κίνησης.
              final run = _ease(v, 0.0, 0.14, Curves.easeIn);
              final shooterTilt = run * 0.18;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ετικέτες ζωνών, ακριβώς πάνω από κάθε τρίτο του τέρματος.
                  Positioned(
                    left: goalLeft,
                    top: 0,
                    width: _goalWidth,
                    height: 26,
                    child: Row(
                      children: List.generate(3, (i) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              _zoneLabels[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Τέρμα.
                  Positioned(
                    left: goalLeft,
                    top: _goalTop,
                    width: _goalWidth,
                    height: _goalHeight,
                    child: Image.asset(
                      'assets/images/penalty/goal.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  // Σουτέρ, πίσω από τη μπάλα, μπροστά από το τέρμα.
                  Positioned(
                    left: cx - _shooterWidth / 2,
                    top: spot.dy - _shooterHeight + 14,
                    child: Transform.rotate(
                      angle: shooterTilt,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        'assets/images/penalty/shooter.png',
                        height: _shooterHeight,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  // Τερματοφύλακας.
                  Positioned(
                    left: keeperPos.dx - _keeperWidth / 2,
                    top: keeperPos.dy - _keeperHeight / 2,
                    child: Transform.rotate(
                      angle: keeperTilt,
                      child: Image.asset(
                        'assets/images/penalty/keeper.png',
                        height: _keeperHeight,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  // Μπάλα.
                  Positioned(
                    left: ballPos.dx - _ballSize / 2,
                    top: ballPos.dy - _ballSize / 2,
                    child: Transform.rotate(
                      angle: flight * 8,
                      child: const SizedBox(
                        width: _ballSize,
                        height: _ballSize,
                        child: FittedBox(child: Text('⚽')),
                      ),
                    ),
                  ),
                  // Περιοχές πατήματος: τα ίδια τρίτα του τέρματος.
                  Positioned(
                    left: goalLeft,
                    top: _goalTop,
                    width: _goalWidth,
                    height: _goalHeight,
                    child: Row(
                      children: List.generate(3, (i) {
                        final isShot = _shotZone == i;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: (_canPlay && !_busy && !_finished)
                                ? () => _shoot(i)
                                : null,
                            child: Container(
                              color: isShot
                                  ? AppTheme.accent.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
