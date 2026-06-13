import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/player_model.dart';
import 'player_compare_screen.dart';

class PlayerProfileScreen extends StatelessWidget {
  final PlayerModel player;
  final String clubId;
  final String clubName;
  const PlayerProfileScreen({
    super.key,
    required this.player,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    final posColor = _posColor(player.position);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(player.name),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Σύγκριση',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerCompareScreen(clubId: clubId, playerA: player),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Header card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: posColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: posColor, width: 2),
                  ),
                  child: ClipOval(
                    child: safeNetworkImage(player.photoUrl) != null
                        ? Image(image: safeNetworkImage(player.photoUrl)!, fit: BoxFit.cover)
                        : Container(
                            color: posColor.withValues(alpha: 0.15),
                            child: Center(
                              child: Text(
                                player.number != null ? '#${player.number}' : player.position,
                                style: TextStyle(
                                  color: posColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: posColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: posColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          player.positionLabel.toUpperCase(),
                          style: TextStyle(color: posColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        clubName,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Info row ────────────────────────────────────────────────────
          Row(
            children: [
              if (player.number != null)
                Expanded(child: _InfoCard(label: 'Νούμερο', value: '#${player.number}', color: posColor)),
              if (player.number != null) const SizedBox(width: 10),
              if (player.age != null)
                Expanded(child: _InfoCard(label: 'Ηλικία', value: '${player.age} ετών', color: AppTheme.primaryLight)),
              if (player.age != null) const SizedBox(width: 10),
              if (player.nationality != null)
                Expanded(child: _InfoCard(label: 'Εθνικότητα', value: player.nationality!, color: AppTheme.textSecondary)),
            ],
          ),
          if (player.number != null || player.age != null || player.nationality != null)
            const SizedBox(height: 16),

          // ─── Career stats ─────────────────────────────────────────────────
          const _SectionTitle('Στατιστικά Καριέρας'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              _StatCard(icon: Icons.sports_soccer, label: 'Γκολ', value: player.goals, color: AppTheme.supportGreen),
              _StatCard(icon: Icons.sports, label: 'Συμμετοχές', value: player.appearances, color: AppTheme.primaryLight),
              _StatCard(icon: Icons.square, label: 'Κίτρινες', value: player.yellowCards, color: AppTheme.accent),
              _StatCard(icon: Icons.square, label: 'Κόκκινες', value: player.redCards, color: AppTheme.red),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Goals per match chart ────────────────────────────────────────
          const _SectionTitle('ΓΚΟΛ ΑΝΑ ΑΓΩΝΑ'),
          const SizedBox(height: 10),
          _PlayerGoalChart(clubId: clubId, playerName: player.name, totalGoals: player.goals, appearances: player.appearances),
          const SizedBox(height: 24),

          // ─── Match events history ─────────────────────────────────────────
          const _SectionTitle('ΙΣΤΟΡΙΚΟ ΑΓΩΝΩΝ'),
          const SizedBox(height: 10),
          _PlayerMatchHistory(clubId: clubId, playerName: player.name),
        ],
      ),
    );
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }
}

// ─── Match history for player ─────────────────────────────────────────────────

class _PlayerMatchHistory extends StatelessWidget {
  final String clubId;
  final String playerName;
  const _PlayerMatchHistory({required this.clubId, required this.playerName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }
        final events = snap.data ?? [];
        if (events.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Δεν υπάρχουν καταγεγραμμένα events', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return Column(
          children: events.map((e) => _EventRow(event: e)).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // Get all matches for this club
    final homeSnap = await FirebaseFirestore.instance
        .collection('matches').where('homeClubId', isEqualTo: clubId).get();
    final awaySnap = await FirebaseFirestore.instance
        .collection('matches').where('awayClubId', isEqualTo: clubId).get();
    final matchIds = [...homeSnap.docs.map((d) => d.id), ...awaySnap.docs.map((d) => d.id)];
    if (matchIds.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    await Future.wait(matchIds.map((matchId) async {
      final eventsSnap = await FirebaseFirestore.instance
          .collection('matches').doc(matchId)
          .collection('events')
          .where('playerName', isEqualTo: playerName)
          .get();
      for (final e in eventsSnap.docs) {
        final d = e.data();
        // Get match info
        final matchDoc = homeSnap.docs.firstWhere(
          (m) => m.id == matchId,
          orElse: () => awaySnap.docs.firstWhere((m) => m.id == matchId),
        );
        final matchData = matchDoc.data();
        results.add({
          'type': d['type'],
          'minute': d['minute'],
          'homeClubName': matchData['homeClubName'] ?? '',
          'awayClubName': matchData['awayClubName'] ?? '',
          'homeScore': matchData['homeScore'] ?? 0,
          'awayScore': matchData['awayScore'] ?? 0,
          'scheduledAt': matchData['scheduledAt'],
        });
      }
    }));
    results.sort((a, b) {
      final ta = (a['scheduledAt'] as dynamic)?.toDate() ?? DateTime(2000);
      final tb = (b['scheduledAt'] as dynamic)?.toDate() ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return results;
  }
}

// ─── Goal chart ───────────────────────────────────────────────────────────────

class _MatchGoalEntry {
  final String opponent;
  final int goals;
  _MatchGoalEntry({required this.opponent, required this.goals});
}

class _PlayerGoalChart extends StatelessWidget {
  final String clubId;
  final String playerName;
  final int totalGoals;
  final int appearances;
  const _PlayerGoalChart({
    required this.clubId,
    required this.playerName,
    required this.totalGoals,
    required this.appearances,
  });

  Future<List<_MatchGoalEntry>> _load() async {
    final homeSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('homeClubId', isEqualTo: clubId)
        .where('status', isEqualTo: 'finished')
        .get();
    final awaySnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('awayClubId', isEqualTo: clubId)
        .where('status', isEqualTo: 'finished')
        .get();

    final allDocs = [...homeSnap.docs, ...awaySnap.docs];
    allDocs.sort((a, b) {
      final ta = (a.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tb = (b.data()['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return ta.compareTo(tb);
    });

    final recent = allDocs.length > 10 ? allDocs.sublist(allDocs.length - 10) : allDocs;

    final results = await Future.wait(recent.map((doc) async {
      final d = doc.data();
      final isHome = d['homeClubId'] == clubId;
      final opponent = (isHome ? d['awayClubName'] : d['homeClubName']) as String? ?? '?';
      final eventsSnap = await FirebaseFirestore.instance
          .collection('matches')
          .doc(doc.id)
          .collection('events')
          .where('playerName', isEqualTo: playerName)
          .where('type', isEqualTo: 'goal')
          .get();
      return _MatchGoalEntry(
        opponent: opponent.length > 5 ? opponent.substring(0, 5) : opponent,
        goals: eventsSnap.docs.length,
      );
    }));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final goalRate = appearances > 0
        ? (totalGoals / appearances).toStringAsFixed(2)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rate summary row
        Row(
          children: [
            _RateTile(label: 'Ρυθμός γκολ', value: goalRate, unit: '/ αγώνα', color: AppTheme.supportGreen),
            const SizedBox(width: 10),
            _RateTile(
              label: 'Συνεισφορά',
              value: appearances > 0 ? '${((totalGoals / appearances) * 100).round()}%' : '—',
              unit: 'αγώνων με γκολ',
              color: AppTheme.primaryLight,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bar chart
        FutureBuilder<List<_MatchGoalEntry>>(
          future: _load(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final entries = snap.data ?? [];
            if (entries.isEmpty || entries.every((e) => e.goals == 0)) {
              return Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Δεν υπάρχουν καταγεγραμμένα γκολ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              );
            }
            final maxY = (entries.map((e) => e.goals).reduce((a, b) => a > b ? a : b) + 1).toDouble();
            return Container(
              height: 140,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entries[i].opponent,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.cardBg2,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final e = entries[group.x];
                        return BarTooltipItem(
                          '${e.opponent}\n${rod.toY.toInt()} γκολ',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  barGroups: entries.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.goals.toDouble(),
                        color: e.value.goals > 0
                            ? AppTheme.supportGreen
                            : AppTheme.divider,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  )).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RateTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _RateTile({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(unit, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ],
      ),
    ),
  );
}

// ─── Event history row ────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? '';
    final minute = event['minute'];
    IconData icon;
    Color color;
    String label;
    switch (type) {
      case 'goal':
        icon = Icons.sports_soccer; color = AppTheme.supportGreen; label = 'Γκολ';
      case 'assist':
        icon = Icons.sports; color = AppTheme.primaryLight; label = 'Ασίστ';
      case 'yellow_card':
        icon = Icons.square; color = AppTheme.accent; label = 'Κίτρινη';
      case 'red_card':
        icon = Icons.square; color = AppTheme.red; label = 'Κόκκινη';
      default:
        icon = Icons.info_outline; color = AppTheme.textSecondary; label = type;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${event['homeClubName']} ${event['homeScore']}–${event['awayScore']} ${event['awayClubName']}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            minute != null ? "$minute' • $label" : label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      gradient: AppTheme.navyGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: AppTheme.navyGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
  );
}
