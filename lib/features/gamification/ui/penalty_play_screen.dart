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
  static const List<double> _targetX = [1 / 6, 0.5, 5 / 6];
  // Θέση του κέντρου της βουτιάς (πιο κοντά στο κέντρο της εστίας).
  static const List<double> _diveCenterX = [0.27, 0.5, 0.73];
  static const double _targetY = 0.4;
  // Μεγέθη σε σχέση με τη σκηνή (ύψος / πλάτος).
  static const double _shooterH = 0.40; // του ύψους
  static const double _keeperH = 0.75; // του ύψους τέρματος
  static const double _keeperAspect = 0.741; // keeper.png
  static const double _diveAspect = 2.7; // keeper_dive_*.png
  static const double _ballH = 0.062; // του ύψους σκηνής (μεγαλύτερη, μπροστά από τον σουτέρ)
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

  /// Τετραγωνική καμπύλη Bezier στο έδαφος.
  static Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
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
              final ballBase = _ballH * h;

              final shot = _shotZone ?? 1;
              final keep = _keeperZone ?? 1;
              final scored = _shotZone != null && shot != keep;

              // Στόχος μέσα στο τέρμα.
              final target = Offset(
                goalLeft + _targetX[shot] * goalW,
                goalTop + _targetY * goalH,
              );

              // ── Μπάλα: έδαφος + ύψος ──
              final kickT = _ease(v, _kickAt, _impactAt, Curves.easeOutCubic);
              final groundImpact = Offset(target.dx, goalBottom);
              final Offset impact;
              final double heightAtImpact;
              if (scored) {
                impact = target;
                heightAtImpact = groundImpact.dy - target.dy;
              } else {
                // Η μπάλα σταματά στα χέρια του τερματοφύλακα.
                final keeperCenterY = goalTop + goalH * 0.55;
                impact = Offset(cx + (target.dx - cx) * 0.9, keeperCenterY - goalH * 0.12);
                heightAtImpact = groundImpact.dy - impact.dy;
              }
              final arc = sin(pi * kickT) * h * 0.09;
              // Η μπάλα στέκεται λίγο πιο μπροστά από τα πόδια του σουτέρ (πιο κοντά στην κάμερα).
              final ballStart = Offset(spot.dx, spot.dy + h * 0.09);
              var ground = _bezier(
                ballStart,
                Offset((spot.dx + groundImpact.dx) / 2, spot.dy - h * 0.25),
                groundImpact,
                kickT,
              );
              var height = heightAtImpact * kickT + arc;

              // Αναπήδηση μετά τη σεηβ: προς τα έξω και προς την κάμερα.
              final bounceT = _ease(v, _impactAt, _endAt, Curves.easeOut);
              if (!scored && v > _impactAt) {
                final outward = impact.dx >= cx ? w * 0.22 : -w * 0.22;
                final reboundGround = Offset(impact.dx + outward, spot.dy - h * 0.02);
                ground = Offset.lerp(groundImpact, reboundGround, bounceT)!;
                height = heightAtImpact * (1 - bounceT) +
                    sin(pi * bounceT) * h * 0.05 * (1 - bounceT);
              }

              final ballCenter = Offset(ground.dx, ground.dy - height);
              // Βάθος: η μπάλα μικραίνει καθώς πηγαίνει στο τέρμα.
              final depthScale = 1 - 0.4 * kickT;
              final ballSize = ballBase * depthScale;
              final shadowAlpha =
                  (0.4 * (1 - height / (h * 0.4))).clamp(0.08, 0.4).toDouble();

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
                  // Σκιά μπάλας στο έδαφος.
                  Positioned(
                    left: ground.dx - ballSize * 0.5,
                    top: ground.dy - ballSize * 0.12,
                    child: Container(
                      width: ballSize,
                      height: ballSize * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: shadowAlpha),
                      ),
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
                  // Μπάλα.
                  Positioned(
                    left: ballCenter.dx - ballSize / 2,
                    top: ballCenter.dy - ballSize / 2,
                    child: Transform.rotate(
                      angle: kickT * 10,
                      child: SizedBox(
                        width: ballSize,
                        height: ballSize,
                        child: Image.asset(
                          'assets/images/penalty/ball.png',
                          fit: BoxFit.contain,
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
