import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../clubs/ui/club_profile_screen.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _wheelAngle;

  List<ClubModel> _clubs = [];
  ClubModel? _result;
  bool _spinning = false;
  bool _done = false;
  double _currentAngle = 0;

  static const _segColors = [
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFFF57F17),
    Color(0xFF0277BD),
    Color(0xFF4527A0),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF558B2F),
    Color(0xFF4E342E),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3800),
      vsync: this,
    );
    _wheelAngle = Tween<double>(begin: 0, end: 0).animate(_controller);
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    final snap = await FirebaseFirestore.instance
        .collection('clubs')
        .where('country', isEqualTo: 'Greece')
        .limit(300)
        .get();
    if (!mounted) return;
    setState(() {
      _clubs = snap.docs
          .map((d) => ClubModel.fromMap(d.data(), d.id))
          .toList();
    });
  }

  Future<void> _spin() async {
    if (_spinning || _clubs.isEmpty) return;
    final rng = Random();
    final picked = _clubs[rng.nextInt(_clubs.length)];
    final extraSpins = 5 + rng.nextInt(4); // 5-8 full rotations
    final end = _currentAngle + extraSpins * 2 * pi + rng.nextDouble() * 2 * pi;

    _wheelAngle = Tween<double>(begin: _currentAngle, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    setState(() {
      _spinning = true;
      _done = false;
      _result = null;
    });

    _controller.reset();
    await _controller.forward();
    if (!mounted) return;

    setState(() {
      _currentAngle = end % (2 * pi);
      _spinning = false;
      _done = true;
      _result = picked;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ποια ομάδα σου αναλογεί;'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Text(
                'Γύρισε τον τροχό και βρες την ομάδα σου!',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Wheel + pointer
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _wheelAngle,
                        builder: (ctx, child) => Transform.rotate(
                          angle: _wheelAngle.value,
                          child: CustomPaint(
                            size: const Size(300, 300),
                            painter: _WheelPainter(_segColors),
                          ),
                        ),
                      ),
                      // Center hub
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      // Pointer (top, pointing down into wheel)
                      Positioned(
                        top: 0,
                        child: CustomPaint(
                          size: const Size(28, 36),
                          painter: _PointerPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              if (!_done)
                GestureDetector(
                  onTap: _spinning ? null : _spin,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 52, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _spinning || _clubs.isEmpty
                          ? const LinearGradient(
                              colors: [Color(0xFF444444), Color(0xFF333333)])
                          : const LinearGradient(
                              colors: [Color(0xFF1A6FE8), Color(0xFF7B2FDB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: _spinning || _clubs.isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF1A6FE8)
                                    .withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Text(
                      _clubs.isEmpty
                          ? 'Φόρτωση...'
                          : _spinning
                              ? 'Γυρίζει...'
                              : '🎰  SPIN!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              if (_done && _result != null)
                _ResultCard(
                  club: _result!,
                  onSpin: () {
                    setState(() {
                      _done = false;
                      _result = null;
                    });
                    _spin();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Color> colors;
  const _WheelPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = colors.length;
    final sweep = 2 * pi / count;
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      fill.color = colors[i];
      final start = i * sweep - pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        fill,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        border,
      );
    }

    // Outer ring
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ResultCard extends StatelessWidget {
  final ClubModel club;
  final VoidCallback onSpin;
  const _ResultCard({required this.club, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1A6FE8).withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A6FE8).withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Η ομάδα σου είναι...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF1A6FE8).withValues(alpha: 0.5),
                    width: 2),
                image: safeNetworkImage(club.logoUrl) != null
                    ? DecorationImage(
                        image: safeNetworkImage(club.logoUrl)!,
                        fit: BoxFit.cover)
                    : null,
              ),
              child: safeNetworkImage(club.logoUrl) == null
                  ? const Icon(Icons.sports_soccer,
                      color: AppTheme.textSecondary, size: 40)
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              club.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (club.city.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                club.city,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ClubProfileScreen(clubId: club.id)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A6FE8), Color(0xFF7B2FDB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Δες την ομάδα',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onSpin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Text(
                        '🔄  Ξανά!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
