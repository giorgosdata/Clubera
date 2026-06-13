import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/match_model.dart';
import '../../../models/player_model.dart';
import '../../../models/prediction_model.dart';
import '../../operator/ui/match_operator_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').doc(widget.matchId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('Match not found'));
          final match = MatchModel.fromMap(snap.data!.data() as Map<String, dynamic>, widget.matchId);
          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              _buildAppBar(ctx, match, user),
              SliverToBoxAdapter(child: _MatchHeader(match: match)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(TabBar(
                  controller: _tab,
                  indicatorColor: AppTheme.accent,
                  labelColor: AppTheme.accent,
                  unselectedLabelColor: AppTheme.textSecondary,
                  tabs: const [Tab(text: 'Events'), Tab(text: 'Line-Up'), Tab(text: 'Predict'), Tab(text: 'MVP'), Tab(text: 'Photos'), Tab(text: 'Ratings')],
                )),
              ),
            ],
            body: TabBarView(
              controller: _tab,
              children: [
                _EventsSection(matchId: widget.matchId, match: match),
                _LineupSection(match: match),
                _PredictSection(match: match, userId: user?.uid ?? ''),
                _MvpSection(matchId: widget.matchId, match: match, userId: user?.uid ?? ''),
                _PhotosSection(matchId: widget.matchId, match: match, user: user),
                _RatingsSection(matchId: widget.matchId, match: match, userId: user?.uid ?? ''),
              ],
            ),
          );
        },
      ),
    );
  }

  void _shareMatch(MatchModel match) {
    String text;
    if (match.isFinished) {
      text = '⚽ ${match.homeClubName} ${match.homeScore} – ${match.awayScore} ${match.awayClubName}\nFull Time on Clubera!';
    } else if (match.isLive) {
      text = '🔴 LIVE: ${match.homeClubName} ${match.homeScore} – ${match.awayScore} ${match.awayClubName} (${match.minute ?? 0}\')';
    } else {
      final date = DateFormat('d MMM, HH:mm').format(match.scheduledAt);
      text = '📅 ${match.homeClubName} vs ${match.awayClubName} – $date\nFollow on Clubera!';
    }
    Share.share(text);
  }

  SliverAppBar _buildAppBar(BuildContext context, MatchModel match, user) {
    final canOperate = user != null &&
        (user.role == 'admin' || (user.role == 'club' &&
            (user.clubId == match.homeClubId || user.clubId == match.awayClubId)));
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          tooltip: 'Share match',
          onPressed: () => _shareMatch(match),
        ),
        if (canOperate && !match.isFinished)
          IconButton(
            icon: const Icon(Icons.sports, color: AppTheme.primaryLight),
            tooltip: 'Operate Match',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MatchOperatorScreen(matchId: match.id),
            )),
          ),
      ],
    );
  }
}

class _MatchHeader extends StatelessWidget {
  final MatchModel match;
  const _MatchHeader({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, Color(0xFF0D1B0D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          _statusBadge(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _teamCol(match.homeClubName, match.homeClubLogo)),
              Column(
                children: [
                  if (!match.isUpcoming)
                    Text('${match.homeScore}  –  ${match.awayScore}',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900))
                  else
                    const Text('vs', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (!match.isUpcoming && match.minute != null)
                    Text("${match.minute}'", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              Expanded(child: _teamCol(match.awayClubName, match.awayClubLogo)),
            ],
          ),
          const SizedBox(height: 16),
          Text(match.league, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (match.venue != null)
            Text(match.venue!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (match.isUpcoming)
            Text(DateFormat('EEEE, dd MMMM yyyy • HH:mm').format(match.scheduledAt),
              style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          if (match.isUpcoming)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MatchWeatherWidget(homeClubId: match.homeClubId, matchTime: match.scheduledAt),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    if (match.isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: AppTheme.liveRed, borderRadius: BorderRadius.circular(20)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.white, size: 8),
            SizedBox(width: 6),
            Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }
    if (match.status == 'halftime') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
        child: const Text('HALF TIME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    if (match.isFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(20)),
        child: const Text('FULL TIME', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _teamCol(String name, String? logo) => Column(
    children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          image: safeNetworkImage(logo) != null ? DecorationImage(image: safeNetworkImage(logo)!, fit: BoxFit.cover) : null,
        ),
        child: safeNetworkImage(logo) == null ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 36) : null,
      ),
      const SizedBox(height: 8),
      Text(name, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        maxLines: 2, overflow: TextOverflow.ellipsis),
    ],
  );
}

class _EventsSection extends StatelessWidget {
  final String matchId;
  final MatchModel match;
  const _EventsSection({required this.matchId, required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches').doc(matchId).collection('events')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snap) {
        final events = (snap.data?.docs ?? [])
            .map((d) => MatchEvent.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No events yet', style: TextStyle(color: AppTheme.textSecondary))),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Match Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...events.map((e) => _EventRow(event: e, match: match)),
            ],
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final MatchEvent event;
  final MatchModel match;
  const _EventRow({required this.event, required this.match});

  ({IconData icon, Color color, String label}) _meta() {
    switch (event.type) {
      case 'goal':
        return (icon: Icons.sports_soccer, color: AppTheme.primaryLight, label: 'Goal');
      case 'yellow_card':
        return (icon: Icons.square, color: Colors.amber, label: 'Yellow');
      case 'red_card':
        return (icon: Icons.square, color: AppTheme.red, label: 'Red');
      case 'penalty':
        return (icon: Icons.sports_soccer, color: AppTheme.accent, label: 'Penalty');
      case 'foul':
        return (icon: Icons.warning_amber, color: AppTheme.liveRed, label: 'Foul');
      case 'offside':
        return (icon: Icons.flag_outlined, color: Colors.deepPurple, label: 'Offside');
      case 'corner':
        return (icon: Icons.crop_din, color: AppTheme.primaryLight, label: 'Corner');
      case 'throw_in':
        return (icon: Icons.swap_horiz, color: AppTheme.textSecondary, label: 'Throw-in');
      case 'goal_cancelled':
        return (icon: Icons.cancel_outlined, color: AppTheme.red, label: 'Goal cancelled');
      case 'substitution':
        return (icon: Icons.swap_vert, color: AppTheme.supportGreen, label: 'Substitution');
      default:
        return (icon: Icons.fiber_manual_record, color: AppTheme.textSecondary, label: event.type);
    }
  }

  String _description() {
    if (event.type == 'substitution') {
      final out = event.playerName.isEmpty ? '—' : event.playerName;
      final inP = event.playerIn?.isEmpty == false ? event.playerIn! : '—';
      return '$out ⇣  $inP ⇡';
    }
    if (event.type == 'goal_cancelled') {
      final p = event.playerName.isEmpty ? '' : event.playerName;
      final r = event.reason ?? '';
      return r.isEmpty ? p : (p.isEmpty ? r : '$p ($r)');
    }
    if (event.type == 'corner' || event.type == 'throw_in') {
      final m = _meta();
      return event.playerName.isEmpty ? m.label : event.playerName;
    }
    return event.playerName.isEmpty ? '—' : event.playerName;
  }

  @override
  Widget build(BuildContext context) {
    final isHome = event.clubId == match.homeClubId;
    final meta = _meta();
    final text = _description();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (isHome) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(meta.icon, color: meta.color, size: 18),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text("${event.minute}'",
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ] else ...[
            const Expanded(child: SizedBox()),
            Text("${event.minute}'",
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Icon(meta.icon, color: meta.color, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── TAB BAR DELEGATE ────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: const Color(0xCC0A1628), child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}

// ─── LINEUP SECTION ──────────────────────────────────────────────────────────

class _LineupSection extends StatelessWidget {
  final MatchModel match;
  const _LineupSection({required this.match});

  // Formation position templates: normalized (x: 0-1, y: 0-1) where y=0 is top.
  // Each team occupies its half (y range ~0.10 to 0.95). Players spread to avoid overlap.
  static const Map<String, List<Offset>> _formations = {
    '4-3-3': [
      Offset(0.5, 0.92),  // GK
      Offset(0.12, 0.75), Offset(0.37, 0.78), Offset(0.63, 0.78), Offset(0.88, 0.75), // DEF
      Offset(0.22, 0.55), Offset(0.5, 0.50), Offset(0.78, 0.55), // MID
      Offset(0.18, 0.22), Offset(0.5, 0.15), Offset(0.82, 0.22), // FWD
    ],
    '4-4-2': [
      Offset(0.5, 0.92),
      Offset(0.12, 0.75), Offset(0.37, 0.78), Offset(0.63, 0.78), Offset(0.88, 0.75),
      Offset(0.12, 0.52), Offset(0.37, 0.50), Offset(0.63, 0.50), Offset(0.88, 0.52),
      Offset(0.32, 0.20), Offset(0.68, 0.20),
    ],
    '3-5-2': [
      Offset(0.5, 0.92),
      Offset(0.22, 0.78), Offset(0.5, 0.80), Offset(0.78, 0.78),
      Offset(0.10, 0.55), Offset(0.30, 0.52), Offset(0.5, 0.48), Offset(0.70, 0.52), Offset(0.90, 0.55),
      Offset(0.32, 0.20), Offset(0.68, 0.20),
    ],
    '4-2-3-1': [
      Offset(0.5, 0.92),
      Offset(0.12, 0.75), Offset(0.37, 0.78), Offset(0.63, 0.78), Offset(0.88, 0.75),
      Offset(0.32, 0.58), Offset(0.68, 0.58),
      Offset(0.12, 0.38), Offset(0.5, 0.36), Offset(0.88, 0.38),
      Offset(0.5, 0.15),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final hasLineup = match.homeLineup.isNotEmpty || match.awayLineup.isNotEmpty;
    final homeFormation = match.homeFormation ?? '4-3-3';
    final awayFormation = match.awayFormation ?? '4-4-2';
    final homePositions = _formations[homeFormation] ?? _formations['4-3-3']!;
    final awayPositions = _formations[awayFormation] ?? _formations['4-4-2']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Formation labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.homeClubName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(homeFormation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(match.awayClubName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(awayFormation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Football field
          AspectRatio(
            aspectRatio: 0.58,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Field background
                        CustomPaint(
                          size: Size(w, h),
                          painter: _FootballFieldPainter(),
                        ),
                        // Home players (bottom half - y positions normal)
                        ...List.generate(
                          homePositions.length.clamp(0, match.homeLineup.isNotEmpty ? match.homeLineup.length : homePositions.length),
                          (i) {
                            final pos = homePositions[i];
                            final player = match.homeLineup.isNotEmpty && i < match.homeLineup.length
                                ? match.homeLineup[i]
                                : null;
                            return _PlayerDot(
                              x: pos.dx * w,
                              y: pos.dy * h,
                              number: player?['number']?.toString() ?? '${i + 1}',
                              name: player?['name'] ?? _defaultPosition(i),
                              isHome: true,
                            );
                          },
                        ),
                        // Away players (top half - y positions inverted)
                        ...List.generate(
                          awayPositions.length.clamp(0, match.awayLineup.isNotEmpty ? match.awayLineup.length : awayPositions.length),
                          (i) {
                            final pos = awayPositions[i];
                            final player = match.awayLineup.isNotEmpty && i < match.awayLineup.length
                                ? match.awayLineup[i]
                                : null;
                            return _PlayerDot(
                              x: pos.dx * w,
                              y: (1.0 - pos.dy) * h, // Mirror for away team
                              number: player?['number']?.toString() ?? '${i + 1}',
                              name: player?['name'] ?? _defaultPosition(i),
                              isHome: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!hasLineup) ...[
            const SizedBox(height: 12),
            const Text('Lineup not set yet — showing formation positions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  String _defaultPosition(int index) {
    const positions = ['GK', 'RB', 'CB', 'CB', 'LB', 'DM', 'CM', 'CM', 'RW', 'ST', 'LW'];
    return index < positions.length ? positions[index] : 'P${index + 1}';
  }
}

class _PlayerDot extends StatelessWidget {
  final double x;
  final double y;
  final String number;
  final String name;
  final bool isHome;
  const _PlayerDot({required this.x, required this.y, required this.number, required this.name, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final color = isHome ? AppTheme.primaryLight : AppTheme.liveRed;
    // Show last name only when name has multiple parts to save horizontal space.
    final displayName = () {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return '—';
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length > 1) return parts.last;
      return trimmed;
    }();
    return Positioned(
      left: x - 36,
      top: y - 16,
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for football field
class _FootballFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Alternating green stripes
    final stripeCount = 8;
    final stripeH = h / stripeCount;
    for (int i = 0; i < stripeCount; i++) {
      final paint = Paint()
        ..color = i.isEven ? const Color(0xFF2D6A27) : const Color(0xFF2A6024)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, w, stripeH), paint);
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Border
    canvas.drawRect(Rect.fromLTRB(8, 8, w - 8, h - 8), line);

    // Center line
    canvas.drawLine(Offset(8, h / 2), Offset(w - 8, h / 2), line);

    // Center circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.15, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = Colors.white.withOpacity(0.5)..style = PaintingStyle.fill);

    // Top penalty area
    final penW = w * 0.55;
    final penH = h * 0.18;
    canvas.drawRect(Rect.fromLTRB((w - penW) / 2, 8, (w + penW) / 2, 8 + penH), line);

    // Top goal area
    final goalW = w * 0.28;
    final goalH = h * 0.07;
    canvas.drawRect(Rect.fromLTRB((w - goalW) / 2, 8, (w + goalW) / 2, 8 + goalH), line);

    // Top penalty spot
    canvas.drawCircle(Offset(w / 2, 8 + penH * 0.55), 2.5, Paint()..color = Colors.white.withOpacity(0.5)..style = PaintingStyle.fill);

    // Bottom penalty area
    canvas.drawRect(Rect.fromLTRB((w - penW) / 2, h - 8 - penH, (w + penW) / 2, h - 8), line);

    // Bottom goal area
    canvas.drawRect(Rect.fromLTRB((w - goalW) / 2, h - 8 - goalH, (w + goalW) / 2, h - 8), line);

    // Bottom penalty spot
    canvas.drawCircle(Offset(w / 2, h - 8 - penH * 0.55), 2.5, Paint()..color = Colors.white.withOpacity(0.5)..style = PaintingStyle.fill);

    // Corner arcs
    final corner = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(Rect.fromCircle(center: const Offset(8, 8), radius: 12), 0, 1.57, false, corner);
    canvas.drawArc(Rect.fromCircle(center: Offset(w - 8, 8), radius: 12), 1.57, 1.57, false, corner);
    canvas.drawArc(Rect.fromCircle(center: Offset(8, h - 8), radius: 12), -1.57, -1.57, false, corner);
    canvas.drawArc(Rect.fromCircle(center: Offset(w - 8, h - 8), radius: 12), 3.14, 1.57, false, corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── PREDICT SECTION ─────────────────────────────────────────────────────────

class _PredictSection extends StatefulWidget {
  final MatchModel match;
  final String userId;
  const _PredictSection({required this.match, required this.userId});

  @override
  State<_PredictSection> createState() => _PredictSectionState();
}

class _PredictSectionState extends State<_PredictSection> {
  int _homeGuess = 0;
  int _awayGuess = 0;
  bool _submitting = false;
  ScorePrediction? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('score_predictions')
        .where('userId', isEqualTo: widget.userId)
        .where('matchId', isEqualTo: widget.match.id)
        .limit(1).get();
    if (!mounted) return;
    if (snap.docs.isNotEmpty) {
      final p = ScorePrediction.fromMap(snap.docs.first.data(), snap.docs.first.id);
      setState(() {
        _existing = p;
        _homeGuess = p.homeScore;
        _awayGuess = p.awayScore;
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _submit() async {
    if (widget.userId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final doc = FirebaseFirestore.instance.collection('score_predictions').doc('${widget.userId}_${widget.match.id}');
      final prediction = ScorePrediction(
        id: doc.id,
        userId: widget.userId,
        matchId: widget.match.id,
        homeScore: _homeGuess,
        awayScore: _awayGuess,
        createdAt: DateTime.now(),
      );
      await doc.set(prediction.toMap());
      if (mounted) {
        setState(() { _existing = prediction; _submitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prediction saved! Points awarded after match.'), backgroundColor: AppTheme.primaryLight),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save prediction: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    final canPredict = widget.match.isUpcoming && widget.userId.isNotEmpty;
    final alreadyPredicted = _existing != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.sports_score, color: AppTheme.accent, size: 36),
                const SizedBox(height: 10),
                const Text('Predict the Score', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('10 pts for exact score • 5 pts for correct outcome', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (widget.match.isFinished)
            Column(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 48),
                const SizedBox(height: 12),
                const Text('Match finished', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                if (_existing != null) ...[
                  const SizedBox(height: 8),
                  Text('Your prediction: ${_existing!.homeScore} - ${_existing!.awayScore}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (_existing!.pointsEarned != null)
                    Text('Points earned: ${_existing!.pointsEarned}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ],
            )
          else if (!canPredict)
            Column(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 48),
                const SizedBox(height: 12),
                Text(widget.userId.isEmpty ? 'Login to predict' : 'Predictions unavailable', style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ScorePicker(
                  label: widget.match.homeClubName,
                  value: _homeGuess,
                  onChanged: alreadyPredicted ? null : (v) => setState(() => _homeGuess = v),
                ),
                Text(':', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                _ScorePicker(
                  label: widget.match.awayClubName,
                  value: _awayGuess,
                  onChanged: alreadyPredicted ? null : (v) => setState(() => _awayGuess = v),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (!alreadyPredicted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.supportGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.supportGreen.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.supportGreen, size: 20),
                    const SizedBox(width: 8),
                    Text('Prediction saved: $_homeGuess - $_awayGuess', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScorePicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;
  const _ScorePicker({required this.label, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Column(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: enabled && value > 0 ? () => onChanged!(value - 1) : null,
              icon: Icon(Icons.remove_circle, color: enabled && value > 0 ? AppTheme.primaryLight : AppTheme.divider, size: 28),
            ),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('$value', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
            ),
            IconButton(
              onPressed: enabled && value < 20 ? () => onChanged!(value + 1) : null,
              icon: Icon(Icons.add_circle, color: enabled ? AppTheme.primaryLight : AppTheme.divider, size: 28),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── MVP SECTION ─────────────────────────────────────────────────────────────

class _MvpSection extends StatefulWidget {
  final String matchId;
  final MatchModel match;
  final String userId;
  const _MvpSection({
    required this.matchId,
    required this.match,
    required this.userId,
  });

  @override
  State<_MvpSection> createState() => _MvpSectionState();
}

class _MvpSectionState extends State<_MvpSection> {
  late final Future<List<PlayerModel>> _playersFuture;
  String get matchId => widget.matchId;
  MatchModel get match => widget.match;
  String get userId => widget.userId;

  @override
  void initState() {
    super.initState();
    _playersFuture = _loadPlayers();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = match.status == 'finished';
    if (!isFinished) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 64, color: AppTheme.cardBg2),
              SizedBox(height: 12),
              Text(
                'MVP voting opens when the match ends',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('mvp_votes')
          .snapshots(),
      builder: (ctx, votesSnap) {
        final votes = votesSnap.data?.docs ?? [];
        final myVote = votes.where((d) => d.id == userId).firstOrNull;
        final myVotedPlayerId = myVote?.data() != null
            ? (myVote!.data() as Map)['playerId'] as String?
            : null;

        // tally
        final tally = <String, int>{};
        for (final v in votes) {
          final pid = (v.data() as Map)['playerId'] as String?;
          if (pid != null) tally[pid] = (tally[pid] ?? 0) + 1;
        }
        final maxVotes = tally.values.fold(0, (a, b) => a > b ? a : b);

        return FutureBuilder<List<PlayerModel>>(
          future: _playersFuture,
          builder: (ctx, playersSnap) {
            final players = playersSnap.data ?? [];
            if (players.isEmpty && playersSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Player of the Match · ${votes.length} votes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (players.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No players in lineup',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ...players.map((p) {
                    final voteCount = tally[p.id] ?? 0;
                    final isWinner = voteCount > 0 && voteCount == maxVotes;
                    final isMyPick = myVotedPlayerId == p.id;
                    final pct = votes.isEmpty ? 0.0 : voteCount / votes.length;
                    return _MvpPlayerRow(
                      player: p,
                      voteCount: voteCount,
                      pct: pct,
                      isWinner: isWinner,
                      isMyPick: isMyPick,
                      canVote: userId.isNotEmpty && myVotedPlayerId == null,
                      onVote: () => _vote(p.id),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<PlayerModel>> _loadPlayers() async {
    final results = <PlayerModel>[];
    for (final clubId in [match.homeClubId, match.awayClubId]) {
      if (clubId.isEmpty) continue;
      final snap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('players')
          .where('isActive', isEqualTo: true)
          .limit(40)
          .get();
      for (final d in snap.docs) {
        results.add(PlayerModel.fromMap(d.data(), d.id));
      }
    }
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  Future<void> _vote(String playerId) async {
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('mvp_votes')
        .doc(userId)
        .set({
      'playerId': playerId,
      'votedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _MvpPlayerRow extends StatelessWidget {
  final PlayerModel player;
  final int voteCount;
  final double pct;
  final bool isWinner;
  final bool isMyPick;
  final bool canVote;
  final VoidCallback onVote;
  const _MvpPlayerRow({
    required this.player,
    required this.voteCount,
    required this.pct,
    required this.isWinner,
    required this.isMyPick,
    required this.canVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.amber.withValues(alpha: 0.12)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMyPick
              ? AppTheme.primaryLight.withValues(alpha: 0.6)
              : isWinner
                  ? Colors.amber.withValues(alpha: 0.5)
                  : AppTheme.divider,
          width: isMyPick || isWinner ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('🏆', style: TextStyle(fontSize: 18)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      player.position,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$voteCount vote${voteCount != 1 ? 's' : ''}',
                style: TextStyle(
                  color: isWinner ? Colors.amber : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              if (canVote)
                ElevatedButton(
                  onPressed: onVote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Vote', style: TextStyle(fontSize: 12)),
                )
              else if (isMyPick)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Your pick',
                    style: TextStyle(color: AppTheme.primaryLight, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.cardBg2,
              color: isWinner ? Colors.amber : AppTheme.primaryLight,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PHOTOS SECTION ───────────────────────────────────────────────────────────

class _PhotosSection extends StatefulWidget {
  final String matchId;
  final MatchModel match;
  final dynamic user; // UserModel?
  const _PhotosSection({required this.matchId, required this.match, required this.user});

  @override
  State<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<_PhotosSection> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _uploading = false;

  bool get _canUpload {
    final u = widget.user;
    if (u == null) return false;
    return u.role == 'admin' ||
        (u.role == 'club' &&
            (u.clubId == widget.match.homeClubId || u.clubId == widget.match.awayClubId));
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1280);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref('match_photos/${widget.matchId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .collection('photos')
          .add({
        'url': url,
        'uploadedBy': widget.user?.uid ?? '',
        'uploaderName': widget.user?.name ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Φωτογραφία ανέβηκε!'), backgroundColor: AppTheme.supportGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .collection('photos')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        final photos = snap.data?.docs ?? [];
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _canUpload
              ? FloatingActionButton(
                  backgroundColor: AppTheme.primaryLight,
                  onPressed: _uploading ? null : _pickAndUpload,
                  tooltip: 'Ανέβασε φωτογραφία',
                  child: _uploading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_photo_alternate_outlined),
                )
              : null,
          body: photos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: AppTheme.cardBg2),
                      SizedBox(height: 12),
                      Text('Δεν υπάρχουν φωτογραφίες', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                      SizedBox(height: 6),
                      Text('Οι διαχειριστές μπορούν να ανεβάσουν', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (ctx, i) {
                    final data = photos[i].data() as Map<String, dynamic>;
                    final url = data['url'] as String? ?? '';
                    return GestureDetector(
                      onTap: () => _showFullscreen(context, url, photos, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(url, fit: BoxFit.cover,
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : Container(color: AppTheme.cardBg2, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg2, child: const Icon(Icons.broken_image, color: AppTheme.textSecondary)),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showFullscreen(BuildContext context, String url, List<QueryDocumentSnapshot> photos, int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullscreenPhoto(photos: photos, initialIndex: index),
    ));
  }
}

class _FullscreenPhoto extends StatefulWidget {
  final List<QueryDocumentSnapshot> photos;
  final int initialIndex;
  const _FullscreenPhoto({required this.photos, required this.initialIndex});

  @override
  State<_FullscreenPhoto> createState() => _FullscreenPhotoState();
}

class _FullscreenPhotoState extends State<_FullscreenPhoto> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        itemBuilder: (ctx, i) {
          final data = widget.photos[i].data() as Map<String, dynamic>;
          final url = data['url'] as String? ?? '';
          return InteractiveViewer(
            child: Center(child: Image.network(url, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}

// ─── RATINGS SECTION ──────────────────────────────────────────────────────────

class _RatingsSection extends StatefulWidget {
  final String matchId;
  final MatchModel match;
  final String userId;
  const _RatingsSection({required this.matchId, required this.match, required this.userId});

  @override
  State<_RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends State<_RatingsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, int> _myRatings = {};

  @override
  void initState() {
    super.initState();
    if (widget.userId.isNotEmpty) _loadMyRatings();
  }

  Future<void> _loadMyRatings() async {
    final doc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('ratings')
        .doc(widget.userId)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _myRatings = (doc.data() ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        );
      });
    }
  }

  Future<void> _rate(String playerName, int stars) async {
    if (widget.userId.isEmpty) return;
    setState(() => _myRatings[playerName] = stars);
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('ratings')
        .doc(widget.userId)
        .set({playerName: stars}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allPlayers = [
      ...widget.match.homeLineup,
      ...widget.match.awayLineup,
    ];
    if (allPlayers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_soccer_outlined, size: 48, color: AppTheme.cardBg2),
              SizedBox(height: 12),
              Text(
                'Δεν έχει καταχωρηθεί ενδεκάδα για αυτόν τον αγώνα',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .collection('ratings')
          .snapshots(),
      builder: (ctx, snap) {
        final Map<String, List<int>> byPlayer = {};
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            for (final e in data.entries) {
              byPlayer.putIfAbsent(e.key, () => []).add((e.value as num).toInt());
            }
          }
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.match.isFinished)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Η αξιολόγηση είναι διαθέσιμη μετά το τέλος του αγώνα',
                  style: TextStyle(color: AppTheme.accent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            _RatingTeamHeader(name: widget.match.homeClubName),
            ...widget.match.homeLineup.map((p) {
              final name = p['name'] as String? ?? '';
              final ratings = byPlayer[name] ?? [];
              final avg = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
              return _PlayerRatingTile(
                playerName: name,
                number: p['number'],
                position: p['position'] as String? ?? '',
                avgRating: avg,
                ratingCount: ratings.length,
                myRating: _myRatings[name] ?? 0,
                canRate: widget.match.isFinished && widget.userId.isNotEmpty,
                onRate: (s) => _rate(name, s),
              );
            }),
            const SizedBox(height: 16),
            _RatingTeamHeader(name: widget.match.awayClubName),
            ...widget.match.awayLineup.map((p) {
              final name = p['name'] as String? ?? '';
              final ratings = byPlayer[name] ?? [];
              final avg = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
              return _PlayerRatingTile(
                playerName: name,
                number: p['number'],
                position: p['position'] as String? ?? '',
                avgRating: avg,
                ratingCount: ratings.length,
                myRating: _myRatings[name] ?? 0,
                canRate: widget.match.isFinished && widget.userId.isNotEmpty,
                onRate: (s) => _rate(name, s),
              );
            }),
          ],
        );
      },
    );
  }
}

class _RatingTeamHeader extends StatelessWidget {
  final String name;
  const _RatingTeamHeader({required this.name});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      name.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );
}

class _PlayerRatingTile extends StatelessWidget {
  final String playerName;
  final dynamic number;
  final String position;
  final double avgRating;
  final int ratingCount;
  final int myRating;
  final bool canRate;
  final void Function(int) onRate;
  const _PlayerRatingTile({
    required this.playerName,
    required this.number,
    required this.position,
    required this.avgRating,
    required this.ratingCount,
    required this.myRating,
    required this.canRate,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (number != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  playerName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              if (avgRating > 0) ...[
                const Icon(Icons.star_rounded, color: AppTheme.accent, size: 16),
                const SizedBox(width: 2),
                Text(
                  avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ' ($ratingCount)',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
          if (canRate) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => onRate(star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      myRating >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: myRating >= star ? AppTheme.accent : AppTheme.cardBg2,
                      size: 28,
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchWeatherWidget extends StatelessWidget {
  final String homeClubId;
  final DateTime matchTime;
  const _MatchWeatherWidget({required this.homeClubId, required this.matchTime});

  Future<WeatherData?> _load() async {
    // Get home club city
    final snap = await FirebaseFirestore.instance.collection('clubs').doc(homeClubId).get();
    if (!snap.exists) return null;
    final city = snap.data()?['city'] as String? ?? '';
    if (city.isEmpty) return null;
    return WeatherService.forMatch(city, matchTime);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData?>(
      future: _load(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
        final w = snap.data!;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(w.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${w.tempC}°C  •  ${w.description}  •  ${w.windKmh} km/h',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
