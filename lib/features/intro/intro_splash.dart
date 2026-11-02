// Opening animation (design «3 · Βίντεο έναρξης»): darkness, the stadium
// floodlights come on, the shield comes forward with a glow, «CLUBERA» and
// the tagline appear, then it fades into the app.
//
// About 3 seconds the first time; later openings play a short version
// (about 1.2 s). A tap skips it. With "reduce motion" on it is skipped.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'intro_seen_v1';

class IntroSplash extends StatefulWidget {
  final VoidCallback onDone;
  const IntroSplash({super.key, required this.onDone});

  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_seenKey) ?? false;
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _finish();
      return;
    }
    _c.duration = Duration(milliseconds: seen ? 1300 : 3200);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    // The short version starts where the shield comes in.
    _c.forward(from: seen ? 0.3 : 0.0);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Value of a 0→1 ramp between [a] and [b] (fractions of the timeline).
  double _ramp(double t, double a, double b, [Curve curve = Curves.easeOut]) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Material(
        color: const Color(0xFF04071A),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final fadeOut = 1 - _ramp(t, 0.86, 1.0, Curves.easeIn);
            final stadium = _ramp(t, 0.10, 0.30);
            final dim = 0.8 - 0.45 * _ramp(t, 0.30, 0.45);
            final flash = t < 0.08 ? _ramp(t, 0, 0.08) : 1 - _ramp(t, 0.08, 0.32);
            final shieldIn = _ramp(t, 0.32, 0.50, Curves.easeOutBack);
            final shieldOpacity = _ramp(t, 0.32, 0.44);
            final word = _ramp(t, 0.50, 0.64);
            return Opacity(
              opacity: fadeOut.clamp(0.0, 1.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: stadium,
                    child: Transform.scale(
                      scale: 1.12 - 0.12 * _ramp(t, 0.10, 0.45),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 1 - dim), BlendMode.darken),
                        child: Image.asset('assets/images/stadium_clubera.jpg', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -1.15),
                    child: Opacity(
                      opacity: flash.clamp(0.0, 1.0),
                      child: Container(
                        width: 520,
                        height: 520,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [Color(0x8CFFFFFF), Color(0x00FFFFFF)], stops: [0, 0.62]),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: shieldOpacity,
                          child: Transform.scale(
                            scale: 0.55 + 0.45 * shieldIn,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4ADE80).withValues(alpha: 0.35 * shieldOpacity),
                                    blurRadius: 60,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: Image.asset('assets/images/shield.png', width: 190, height: 190),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Opacity(
                          opacity: word,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - word)),
                            child: const Column(
                              children: [
                                Text(
                                  'CLUBERA',
                                  style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 6),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Η ομάδα σου. Η πόλη σου.',
                                  style: TextStyle(color: Color(0xFFC7D2F0), fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28,
                    child: Text(
                      'Πατήστε για παράλειψη',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFAFBEE6), fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
