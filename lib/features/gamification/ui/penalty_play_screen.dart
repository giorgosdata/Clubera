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

  // Γεωμετρία σκηνής (pixels). Κάμερα πίσω από τον σουτέρ: το τέρμα είναι
  // μπροστά, ο σουτέρ κάτω στη μέση και ο τερματοφύλακας κοιτά τον παίκτη.
  static const double _areaHeight = 360;
  static const double _goalWidth = 300;
  static const double _goalHeight = 224; // αναλογία goal.png 1400x1045
  static const double _goalTop = 30;
  static const double _goalBottom = _goalTop + _goalHeight;
  static const double _spotY = _areaHeight - 26; // σημείο πέναλτι (έδαφος)
  static const double _ballSize = 30;

  // Σταθερές διαστάσεις εικόνων (ύψος → πλάτος αναλογικά).
  static const double _keeperHeight = 170; // keeper.png 896x1200
  static const double _keeperWidth = 127;
  static const double _diveHeight = 172; // keeper_dive_*.png 4:3
  static const double _diveWidth = 230;
  static const double _shooterHeight = 180; // shooter_*.png 3:4
  static const double _shooterWidth = 135;

  // Στόχοι μέσα στο τέρμα, συμμετρικοί γύρω από το κέντρο.
  static const List<double> _targetX = [1 / 6, 0.5, 5 / 6];
  static const double _targetY = 0.4;

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

  /// Τετραγωνική καμπύλη Bezier στο έδαφος.
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

              final shot = _shotZone ?? 1;
              final keep = _keeperZone ?? 1;
              final scored = _shotZone != null && shot != keep;

              // Στόχος της μπάλας μέσα στο τέρμα.
              final target = Offset(
                goalLeft + _targetX[shot] * _goalWidth,
                _goalTop + _targetY * _goalHeight,
              );

              // ── Μπάλα: έδαφος + ύψος (για να φαίνεται το βάθος και η σκιά) ──
              final kickT = _ease(v, _kickAt, _impactAt, Curves.easeOutCubic);
              final groundStart = Offset(cx, _spotY);
              final Offset impact;
              final double heightAtImpact;
              final Offset groundImpact;
              if (scored) {
                groundImpact = Offset(target.dx, _goalBottom + 4);
                impact = target;
                heightAtImpact = groundImpact.dy - target.dy;
              } else {
                // Η μπάλα σταματά στα χέρια του τερματοφύλακα.
                final keeperCenterY = _goalTop + _goalHeight * 0.62;
                impact = Offset(
                  cx + (target.dx - cx) * 0.9,
                  keeperCenterY - 40,
                );
                groundImpact = Offset(impact.dx, _goalBottom + 4);
                heightAtImpact = groundImpact.dy - impact.dy;
              }
              final arc = sin(pi * kickT) * 40;
              var ground = _bezier(
                groundStart,
                Offset((groundStart.dx + groundImpact.dx) / 2, _spotY - 110),
                groundImpact,
                kickT,
              );
              var height = heightAtImpact * kickT + arc;

              // Αναπήδηση μετά τη σεηβ: προς τα έξω και κάτω.
              final bounceT = _ease(v, _impactAt, _endAt, Curves.easeOut);
              if (!scored && v > _impactAt) {
                final outward = impact.dx >= cx ? 90.0 : -90.0;
                final reboundGround = Offset(impact.dx + outward, _spotY - 40);
                ground = Offset.lerp(groundImpact, reboundGround, bounceT)!;
                height = heightAtImpact * (1 - bounceT) +
                    sin(pi * bounceT) * 36 * (1 - bounceT);
              }

              final ballCenter = Offset(ground.dx, ground.dy - height);
              final depthScale = 1 - 0.32 * kickT;
              final shadowAlpha =
                  (0.38 * (1 - height / 160)).clamp(0.08, 0.38).toDouble();

              // ── Σουτέρ: από πίσω. Τρέχει (προετοιμασία) και μετά σουτάρει ──
              final kickStarted = v >= _kickAt;
              final shooterAsset = kickStarted
                  ? 'assets/images/penalty/shooter_kick.png'
                  : 'assets/images/penalty/shooter_run.png';

              // ── Τερματοφύλακας: στέκεται και βουτάει στη ζώνη του ──
              final dive = _ease(v, 0.08, 0.5, Curves.easeOutBack);
              final keeperRest = Offset(cx, _goalTop + _goalHeight * 0.6);
              final keeperDiveTarget = Offset(
                goalLeft + _targetX[keep] * _goalWidth,
                _goalTop + _goalHeight * 0.72,
              );
              final keeperPos = keep == 1
                  ? keeperRest
                  : Offset.lerp(keeperRest, keeperDiveTarget, dive)!;
              final diving = keep != 1 && dive > 0.05;
              // Μικρό «κάθισμα» πριν το σουτ.
              final crouch = v < _kickAt ? sin(pi * v / _kickAt) * 0.05 : 0.0;

              // Μπάλα μέσα στα δίχτυα: μικρό φούσκωμα του τέρματος.
              final bulge = scored
                  ? sin(pi * _ease(v, _impactAt, _endAt, Curves.linear)) * 0.025
                  : 0.0;

              

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ετικέτες ζωνών πάνω από κάθε τρίτο του τέρματος.
                  Positioned(
                    left: goalLeft,
                    top: 0,
                    width: _goalWidth,
                    height: 24,
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
                  // Τέρμα (με φούσκωμα στο γκολ).
                  Positioned(
                    left: goalLeft,
                    top: _goalTop,
                    width: _goalWidth,
                    height: _goalHeight,
                    child: Transform.scale(
                      scale: 1 + bulge,
                      child: Image.asset(
                        'assets/images/penalty/goal.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  // Τερματοφύλακας.
                  if (!diving)
                    Positioned(
                      left: keeperPos.dx - _keeperWidth / 2,
                      top: keeperPos.dy - _keeperHeight / 2,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(1, 1 - crouch, 1),
                        child: Image.asset(
                          'assets/images/penalty/keeper.png',
                          height: _keeperHeight,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: keeperPos.dx - _diveWidth / 2,
                      top: keeperPos.dy - _diveHeight / 2,
                      child: Image.asset(
                        keep == 0
                            ? 'assets/images/penalty/keeper_dive_left.png'
                            : 'assets/images/penalty/keeper_dive_right.png',
                        height: _diveHeight,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  // Σκιά μπάλας στο έδαφος.
                  Positioned(
                    left: ground.dx - 13 * depthScale,
                    top: ground.dy - 4,
                    child: Container(
                      width: 26 * depthScale,
                      height: 8 * depthScale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: shadowAlpha),
                      ),
                    ),
                  ),
                  // Σουτέρ (πίσω από τη μπάλα).
                  Positioned(
                    left: cx - _shooterWidth / 2,
                    top: _spotY - _shooterHeight + 24,
                    child: Image.asset(
                      shooterAsset,
                      height: _shooterHeight,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  // Μπάλα.
                  Positioned(
                    left: ballCenter.dx - _ballSize / 2,
                    top: ballCenter.dy - _ballSize / 2,
                    child: Transform.rotate(
                      angle: kickT * 10,
                      child: Transform.scale(
                        scale: depthScale,
                        child: const SizedBox(
                          width: _ballSize,
                          height: _ballSize,
                          child: FittedBox(child: Text('⚽')),
                        ),
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
                              decoration: BoxDecoration(
                                border: isShot
                                    ? Border.all(
                                        color: AppTheme.accent.withValues(alpha: 0.7),
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
