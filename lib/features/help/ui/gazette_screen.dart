import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/user_model.dart';

const _ink = Color(0xFF1C1007);
const _paper = Color(0xFFF2E8D5);
const _paperDark = Color(0xFFE4D4A8);

class GazetteScreen extends StatelessWidget {
  const GazetteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().user;
    final today = DateFormat('d MMM yyyy').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Masthead ─────────────────────────────────────────
            _ornamentRow(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'OFFICIAL CLUB CONTROL ROOM',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'THE CLUBERA\nGAZETTE',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          height: 0.95,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: _ink, width: 1.5)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('EDITION', style: TextStyle(color: _ink, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const Text('No.01', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 3),
                      Container(height: 1, width: 64, color: _ink),
                      const SizedBox(height: 3),
                      const Text("TODAY'S DATE", style: TextStyle(color: _ink, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Text(today, style: const TextStyle(color: _ink, fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(height: 2.5, color: _ink),
            const SizedBox(height: 2),
            const Text(
              '★  ★  ★   YOUR CLUB. YOUR LEGACY. OUR SYSTEM.   ★  ★  ★',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Container(height: 3.5, color: _ink),
            const SizedBox(height: 14),

            // ── Featured Profile ──────────────────────────────────
            if (user != null) ...[
              _SectionHeader(title: 'FEATURED PROFILE'),
              const SizedBox(height: 10),
              _ProfileCard(user: user),
              const SizedBox(height: 14),
            ],

            // ── Two-column top block ──────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: How to Use
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: 'USER GUIDE'),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: _ink)),
                          child: Column(
                            children: [
                              _GuideRow(
                                icon: Icons.home,
                                title: 'HOME FRONT',
                                body: 'Live scores, upcoming fixtures & top clubs by votes.',
                              ),
                              _guideDivider(),
                              _GuideRow(
                                icon: Icons.sports_soccer,
                                title: 'MATCHES & PREDICTIONS',
                                body: 'Pick 1, X or 2 per match. Earn 5pts correct 1X2, 10pts exact score.',
                              ),
                              _guideDivider(),
                              _GuideRow(
                                icon: Icons.shield,
                                title: 'TEAMS & STANDINGS',
                                body: 'Browse by country, search clubs or players, see live standings.',
                              ),
                              _guideDivider(),
                              _GuideRow(
                                icon: Icons.person,
                                title: 'PROFILE & WALLET',
                                body: 'Support clubs from your wallet. Redeem points for rewards.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right sidebar
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Headline box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border.all(color: _ink)),
                          child: Column(
                            children: [
                              const _TinyHeader(text: '★  TODAY\'S HEADLINE  ★'),
                              const SizedBox(height: 8),
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _paperDark,
                                  border: Border.all(color: _ink, width: 0.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.stadium, color: _ink, size: 36),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'EVERY CLUB\nHAS A STORY.\nYOURS STARTS HERE.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // System Notice
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border.all(color: _ink)),
                          child: const Column(
                            children: [
                              _TinyHeader(text: '★  SYSTEM NOTICE  ★'),
                              SizedBox(height: 6),
                              Text(
                                'Stay active, manage your club, and earn your place in history.',
                                style: TextStyle(color: _ink, fontSize: 11, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // The System Speaks
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border.all(color: _ink)),
                          child: const Column(
                            children: [
                              _TinyHeader(text: '★  THE SYSTEM SPEAKS  ★'),
                              SizedBox(height: 6),
                              Text(
                                '" CONTROL\n  TODAY.\n  ACHIEVE\n  TOMORROW. "',
                                style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900, height: 1.3),
                              ),
                              SizedBox(height: 6),
                              Text('⚽', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Points System ────────────────────────────────────
            _SectionHeader(title: 'POINTS SYSTEM'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _paperDark,
                border: Border.all(color: _ink),
              ),
              child: Column(
                children: [
                  _PointsRow(action: 'Correct outcome (1X2)', pts: '+5 pts'),
                  _PointsRow(action: 'Correct exact score', pts: '+10 pts'),
                  _PointsRow(action: 'Vote for a club', pts: '+2 pts'),
                  _PointsRow(action: 'Active daily streak', pts: '+1 pt/day'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Contact ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: _ink)),
              child: Column(
                children: const [
                  _TinyHeader(text: '→  EXIT THE SYSTEM  ←'),
                  SizedBox(height: 8),
                  Text(
                    'For any assistance, contact the editorial team at:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _ink, fontSize: 11),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'support@clubera.app',
                    style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'We respond within 24 hours.',
                    style: TextStyle(color: _ink, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Footer ───────────────────────────────────────────
            Container(height: 3, color: _ink),
            const SizedBox(height: 10),
            Row(
              children: [
                Image.asset('assets/images/logo.jpeg', height: 38),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE CLUBERA GAZETTE',
                        style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                      ),
                      Text(
                        "More than a platform. It's a legacy in the making.",
                        style: TextStyle(color: _ink, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const Text('⚽', style: TextStyle(fontSize: 26)),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1.5, color: _ink),
            const SizedBox(height: 10),
            // Bottom nav legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _NavLegend(icon: Icons.home, label: 'HOME', sub: 'Main page'),
                _NavLegend(icon: Icons.sports_soccer, label: 'MATCHES', sub: 'Live & upcoming'),
                _NavLegend(icon: Icons.shield, label: 'TEAMS', sub: 'Your clubs'),
                _NavLegend(icon: Icons.person, label: 'PROFILE', sub: 'Your space'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _ornamentRow() => const Padding(
  padding: EdgeInsets.symmetric(vertical: 4),
  child: Text(
    '+ ★ + ★ + ★ + ★ + ★ + ★ + ★ + ★ + ★ + ★ +',
    textAlign: TextAlign.center,
    style: TextStyle(color: _ink, fontSize: 9, letterSpacing: 2),
  ),
);

Widget _guideDivider() => Container(
  height: 1,
  color: _ink.withValues(alpha: 0.25),
);

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _ink, thickness: 1.5, endIndent: 0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '★  $title  ★',
            style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _ink, thickness: 1.5, indent: 0)),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'System Administrator';
      case 'club': return 'Club Representative';
      default: return 'Registered Member of the Clubera System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: _ink, width: 1)),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
              color: _paperDark,
              image: safeNetworkImage(user.photoUrl) != null
                  ? DecorationImage(image: safeNetworkImage(user.photoUrl)!, fit: BoxFit.cover)
                  : null,
            ),
            child: safeNetworkImage(user.photoUrl) == null
                ? Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.toUpperCase(),
                  style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5, height: 1.1),
                ),
                Text(
                  _roleLabel(user.role),
                  style: const TextStyle(color: _ink, fontSize: 10, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatBadge(label: 'STATUS', value: 'ACTIVE'),
                    const SizedBox(width: 14),
                    _StatBadge(label: 'REWARD TIER', value: '${user.points} POINTS'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _ink, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        Text(value, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _GuideRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: _paper, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: _ink, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _ink, size: 18),
        ],
      ),
    );
  }
}

class _PointsRow extends StatelessWidget {
  final String action;
  final String pts;
  const _PointsRow({required this.action, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Text('→ ', style: TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.bold)),
          Expanded(child: Text(action, style: const TextStyle(color: _ink, fontSize: 12))),
          Text(pts, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TinyHeader extends StatelessWidget {
  final String text;
  const _TinyHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _ink, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }
}

class _NavLegend extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _NavLegend({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _ink, size: 20),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _ink, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(sub, style: const TextStyle(color: _ink, fontSize: 7)),
      ],
    );
  }
}
