import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/game_model.dart';

/// Πέναλτι: ο παίκτης σουτάρει 5 φορές σε μία από τις 3 ζώνες του τέρματος.
/// Ο τερματοφύλακας βουτάει τυχαία σε μία ζώνη. Τα γκολ είναι η βαθμολογία.
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

  // Σκηνή: φωτογραφία stadium.jpg (1744x2336). Όλες οι θέσεις είναι κλάσματα
  // του πλάτους (w) και του ύψους (h) της εικόνας, ώστε να ταιριάζουν ακριβώς.
  static const double _sceneAspect = 0.8112; // stadium.jpg (1100 px wide)
  static const double _goalL = 0.121, _goalR = 0.879; // άκρα τέρματος (x), συμμετρικά
  static const double _goalT = 0.161, _goalB = 0.382; // άνω/κάτω άκρο (y)
  static const double _spotX = 0.5, _spotY = 0.714; // σημείο πέναλτι, στο κέντρο
  // Στόχοι μέσα στο τέρμα (κλάσμα του τέρματος), συμμετρικοί.
  // Θέση του κέντρου της βουτιάς (πιο κοντά στο κέντρο της εστίας).
  static const List<double> _diveCenterX = [0.27, 0.5, 0.73];
  // Μεγέθη σε σχέση με τη σκηνή (ύψος / πλάτος).
  static const double _shooterH = 0.40; // του ύψους
  static const double _keeperH = 0.75; // του ύψους τέρματος
  static const double _keeperAspect = 0.741; // keeper.png
  static const double _diveAspect = 2.7; // keeper_dive_*.png
  static const double _diveW = 0.52; // του πλάτους του τέρματος

  // Χρονισμός (κλάσμα της συνολικής κίνησης).
  static const double _kickAt = 0.14; // η μπάλα φεύγει από το πόδι
  static const double _impactAt = 0.62; // επαφή με τέρμα ή τερματοφύλακα
  static const double _endAt = 0.92;

  final Random _rng = Random();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
    final keeper = _rng.nextInt(3);
    setState(() {
      _busy = true;
      _shotZone = zone;
      _keeperZone = keeper;
      _result = null;
    });

    // Όλη η κίνηση (προετοιμασία, σουτ, πτήση, βουτιά) σε ένα animation.
    await _anim.forward(from: 0);
    if (!mounted) return;
    final scored = zone != keeper;
    setState(() {
      if (scored) _goals++;
      _result = scored ? 'ΓΚΟΛ!' : 'Σεηβ!';
    });
    if (scored) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _kicks++;
    if (_kicks >= _totalKicks) {
      await _finish();
    } else {
      // Επιστροφή όλων στη θέση εκκίνησης πριν το επόμενο σουτ.
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
                  Center(child: SizedBox(width: 300, child: _goalArea())),
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

  Widget _goalArea() {
    return AspectRatio(
      aspectRatio: _sceneAspect,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final v = _anim.value;

              // Γεωμετρία σε pixels, από τα κλάσματα της σκηνής.
              final goalLeft = _goalL * w;
              final goalW = (_goalR - _goalL) * w;
              final goalTop = _goalT * h;
              final goalH = (_goalB - _goalT) * h;
              final goalBottom = _goalB * h;
              final cx = _spotX * w;
              final spot = Offset(cx, _spotY * h);
              final keep = _keeperZone ?? 1;

              // ── Σουτέρ ──
              final kickStarted = v >= _kickAt;
              final shooterAsset = kickStarted
                  ? 'assets/images/penalty/shooter_kick.png'
                  : 'assets/images/penalty/shooter_run.png';
              final shooterHeight = h * _shooterH;
              final run = _ease(v, 0.0, _kickAt, Curves.easeIn);
              final shooterTilt = run * 0.18;

              // ── Τερματοφύλακας ──
              final keeperStandH = goalH * _keeperH;
              final keeperStandW = keeperStandH * _keeperAspect;
              final dive = _ease(v, 0.08, 0.5, Curves.easeOutBack);
              final keeperRest = Offset(cx, goalTop + goalH * 0.6);
              final keeperDiveTarget = Offset(
                goalLeft + _diveCenterX[keep] * goalW,
                goalBottom - goalH * 0.3,
              );
              final keeperPos = keep == 1
                  ? keeperRest
                  : Offset.lerp(keeperRest, keeperDiveTarget, dive)!;
              final diving = keep != 1 && dive > 0.05;
              final diveW = goalW * _diveW;
              final diveHalfH = diveW / _diveAspect / 2;

              final crouch = v < _kickAt ? sin(pi * v / _kickAt) * 0.05 : 0.0;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Φόντο σκηνής.
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/penalty/stadium.jpg',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  // Ετικέτες ζωνών πάνω από τα τρίτα του τέρματος.
                  Positioned(
                    left: goalLeft,
                    top: goalTop - 26,
                    width: goalW,
                    height: 22,
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
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Τερματοφύλακας.
                  if (!diving)
                    Positioned(
                      left: keeperPos.dx - keeperStandW / 2,
                      top: keeperPos.dy - keeperStandH / 2,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(1, 1 - crouch, 1),
                        child: Image.asset(
                          'assets/images/penalty/keeper.png',
                          height: keeperStandH,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: keeperPos.dx - diveW / 2,
                      top: keeperPos.dy - diveHalfH,
                      child: Image.asset(
                        keep == 0
                            ? 'assets/images/penalty/keeper_dive_left.png'
                            : 'assets/images/penalty/keeper_dive_right.png',
                        width: diveW,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  // Σουτέρ, με τα πόδια στο σημείο πέναλτι. Το Align τον κεντράρει.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: spot.dy + h * 0.05 - shooterHeight,
                    height: shooterHeight,
                    child: Transform.rotate(
                      angle: shooterTilt,
                      alignment: Alignment.bottomCenter,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          shooterAsset,
                          height: shooterHeight,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  // Περιοχές πατήματος: τα τρίτα του τέρματος.
                  Positioned(
                    left: goalLeft,
                    top: goalTop,
                    width: goalW,
                    height: goalH,
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
                              decoration: BoxDecoration(
                                border: isShot
                                    ? Border.all(
                                        color: AppTheme.accent.withValues(alpha: 0.8),
                                        width: 2,
                                      )
                                    : null,
                              ),
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
