import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/prediction_model.dart';

class PredictionHistoryScreen extends StatelessWidget {
  const PredictionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AppProvider>().user!.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Prediction History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Score Predictions'),
              Tab(text: 'Coupons'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ScorePredictionsTab(uid: uid),
            _CouponPicksTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

// ─── Score Predictions Tab ───────────────────────────────────────────────────

class _ScorePredictionsTab extends StatefulWidget {
  final String uid;
  const _ScorePredictionsTab({required this.uid});

  @override
  State<_ScorePredictionsTab> createState() => _ScorePredictionsTabState();
}

class _ScorePredictionsTabState extends State<_ScorePredictionsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<ScorePrediction>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<List<ScorePrediction>> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('score_predictions')
        .where('userId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) => ScorePrediction.fromMap(d.data(), d.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<ScorePrediction>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        final resolved = items.where((p) => !p.isPending).toList();
        final correct = resolved.where((p) => (p.pointsEarned ?? 0) > 0).length;
        final exact = resolved.where((p) => (p.pointsEarned ?? 0) >= kPredictExactPoints).length;
        final totalPts = resolved.fold<int>(0, (s, p) => s + (p.pointsEarned ?? 0));

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primaryLight,
          child: CustomScrollView(
            slivers: [
              if (resolved.isNotEmpty)
                SliverToBoxAdapter(
                  child: _StatsHeader(
                    children: [
                      _StatChip(label: 'Picks', value: '${items.length}', color: AppTheme.textSecondary),
                      _StatChip(label: 'Correct', value: '$correct', color: AppTheme.supportGreen),
                      _StatChip(label: 'Exact', value: '$exact', color: AppTheme.accent),
                      _StatChip(label: 'Points', value: '$totalPts', color: AppTheme.primaryLight),
                    ],
                  ),
                ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_soccer_outlined, size: 64, color: AppTheme.cardBg2),
                        SizedBox(height: 12),
                        Text('No score predictions yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ScorePredictionTile(prediction: items[i]),
                    childCount: items.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Coupon Picks Tab ─────────────────────────────────────────────────────────

class _CouponPicksTab extends StatefulWidget {
  final String uid;
  const _CouponPicksTab({required this.uid});

  @override
  State<_CouponPicksTab> createState() => _CouponPicksTabState();
}

class _CouponPicksTabState extends State<_CouponPicksTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<CouponPick>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<List<CouponPick>> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('coupon_picks')
        .where('userId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) => CouponPick.fromMap(d.data(), d.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<CouponPick>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        final resolved = items.where((p) => p.resolved == true).toList();
        final correct = resolved.where((p) => (p.pointsEarned ?? 0) > 0).length;
        final exact = resolved.where((p) => (p.pointsEarned ?? 0) >= kPredictExactPoints).length;
        final totalPts = resolved.fold<int>(0, (s, p) => s + (p.pointsEarned ?? 0));
        final accuracy = resolved.isEmpty ? 0.0 : correct / resolved.length * 100;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primaryLight,
          child: CustomScrollView(
            slivers: [
              if (resolved.isNotEmpty)
                SliverToBoxAdapter(
                  child: _StatsHeader(
                    children: [
                      _StatChip(label: 'Picks', value: '${items.length}', color: AppTheme.textSecondary),
                      _StatChip(label: 'Correct', value: '$correct', color: AppTheme.supportGreen),
                      _StatChip(label: 'Exact', value: '$exact', color: AppTheme.accent),
                      _StatChip(label: 'Win %', value: '${accuracy.toStringAsFixed(0)}%', color: AppTheme.primaryLight),
                      _StatChip(label: 'Points', value: '$totalPts', color: AppTheme.accent),
                    ],
                  ),
                ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.cardBg2),
                        SizedBox(height: 12),
                        Text('No coupon picks yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _CouponPickTile(pick: items[i]),
                    childCount: items.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Score Prediction Tile ────────────────────────────────────────────────────

class _ScorePredictionTile extends StatelessWidget {
  final ScorePrediction prediction;
  const _ScorePredictionTile({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final isPending = prediction.isPending;
    final pts = prediction.pointsEarned ?? 0;
    final isCorrect = pts > 0;
    final isExact = pts >= kPredictExactPoints;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isPending) {
      statusColor = AppTheme.textSecondary;
      statusLabel = 'Pending';
      statusIcon = Icons.hourglass_empty;
    } else if (isExact) {
      statusColor = AppTheme.accent;
      statusLabel = 'Exact! +$pts';
      statusIcon = Icons.star;
    } else if (isCorrect) {
      statusColor = AppTheme.supportGreen;
      statusLabel = 'Correct +$pts';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppTheme.red;
      statusLabel = 'Wrong • 0';
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? AppTheme.divider : statusColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match ${prediction.matchId.length > 12 ? prediction.matchId.substring(0, 12) : prediction.matchId}…',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Predicted: ${prediction.homeScore} – ${prediction.awayScore}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM yy').format(prediction.createdAt),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Coupon Pick Tile ─────────────────────────────────────────────────────────

class _CouponPickTile extends StatelessWidget {
  final CouponPick pick;
  const _CouponPickTile({required this.pick});

  @override
  Widget build(BuildContext context) {
    final isPending = pick.isPending;
    final pts = pick.pointsEarned ?? 0;
    final isCorrect = pts > 0;
    final isExact = pts >= kPredictExactPoints;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isPending) {
      statusColor = AppTheme.textSecondary;
      statusLabel = 'Pending';
      statusIcon = Icons.hourglass_empty;
    } else if (isExact) {
      statusColor = AppTheme.accent;
      statusLabel = 'Exact! +$pts';
      statusIcon = Icons.star;
    } else if (isCorrect) {
      statusColor = AppTheme.supportGreen;
      statusLabel = 'Correct +$pts';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppTheme.red;
      statusLabel = 'Wrong • 0';
      statusIcon = Icons.cancel;
    }

    final pickLabel = pick.pick == '1' ? 'Home Win' : pick.pick == '2' ? 'Away Win' : 'Draw';
    final hasExact = pick.hasExactPrediction;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? AppTheme.divider : statusColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pick.homeClubName} vs ${pick.awayClubName}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasExact
                      ? '$pickLabel • ${pick.predictedHomeScore}–${pick.predictedAwayScore}'
                      : pickLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM yy').format(pick.createdAt),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final List<Widget> children;
  const _StatsHeader({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}
