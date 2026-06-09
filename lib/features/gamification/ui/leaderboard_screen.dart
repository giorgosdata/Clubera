import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/user_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Points'),
            Tab(text: 'Predictions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _PointsTab(),
          _PredictionsTab(),
        ],
      ),
    );
  }
}

// ─── POINTS TAB ───────────────────────────────────────────────────────────────

class _PointsTab extends StatelessWidget {
  const _PointsTab();

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppProvider>().user;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Σφάλμα: ${snap.error}', style: const TextStyle(color: Colors.red)));
        }
        final users = (snap.data?.docs ?? [])
            .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        return Column(
          children: [
            if (me != null) _MyRankBanner(user: me, users: users),
            if (users.isNotEmpty) _Podium(top3: users.take(3).toList()),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
                color: AppTheme.primaryLight,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (ctx, i) => _LeaderRow(
                    user: users[i],
                    rank: i + 1,
                    isMe: users[i].uid == me?.uid,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── PREDICTIONS TAB ─────────────────────────────────────────────────────────

class _PredictionsTab extends StatefulWidget {
  const _PredictionsTab();

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  late final Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadStats();
  }

  Future<List<Map<String, dynamic>>> _loadStats() async {
    final snap = await FirebaseFirestore.instance
        .collection('coupon_picks')
        .where('resolved', isEqualTo: true)
        .get();

    final stats = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      if (userId.isEmpty) continue;
      stats.putIfAbsent(userId, () => {'userId': userId, 'total': 0, 'correct': 0});
      stats[userId]!['total'] = (stats[userId]!['total'] as int) + 1;
      if (((data['pointsEarned'] as num?)?.toInt() ?? 0) > 0) {
        stats[userId]!['correct'] = (stats[userId]!['correct'] as int) + 1;
      }
    }

    if (stats.isEmpty) return [];

    final userIds = stats.keys.toList();
    final userSnaps = await Future.wait(
      userIds.map((id) =>
          FirebaseFirestore.instance.collection('users').doc(id).get()),
    );

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < userIds.length; i++) {
      final uid = userIds[i];
      final userData = userSnaps[i].data();
      final total = stats[uid]!['total'] as int;
      final correct = stats[uid]!['correct'] as int;
      if (total < 3) continue; // skip users with too few picks
      result.add({
        'userId': uid,
        'name': userData?['name'] ?? 'Unknown',
        'photoUrl': userData?['photoUrl'],
        'total': total,
        'correct': correct,
        'winRate': (correct / total * 100).round(),
      });
    }

    result.sort((a, b) =>
        (b['winRate'] as int).compareTo(a['winRate'] as int));
    return result.take(30).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Σφάλμα: ${snap.error}', style: const TextStyle(color: Colors.red)));
        }
        final stats = snap.data ?? [];
        if (stats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text(
                  'No prediction data yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'Need at least 3 resolved picks per user',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Predictor', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                  SizedBox(width: 48, child: Center(child: Text('Correct', style: TextStyle(color: AppTheme.supportGreen, fontSize: 11, fontWeight: FontWeight.bold)))),
                  SizedBox(width: 48, child: Center(child: Text('Total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                  SizedBox(width: 52, child: Center(child: Text('Win %', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...stats.asMap().entries.map(
              (e) => _PredictorRow(data: e.value, rank: e.key + 1),
            ),
          ],
        );
      },
    );
  }
}

class _PredictorRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final int rank;
  const _PredictorRow({required this.data, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [AppTheme.accent, Colors.grey[400]!, Colors.brown[400]!];
    final winRate = data['winRate'] as int;
    final rateColor = winRate >= 60
        ? AppTheme.supportGreen
        : winRate >= 40
            ? AppTheme.accent
            : AppTheme.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? rankColors[rank - 1].withValues(alpha: 0.4) : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isTop3 ? rankColors[rank - 1] : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardBg2,
            backgroundImage: safeNetworkImage(data['photoUrl'] as String?),
            child: safeNetworkImage(data['photoUrl'] as String?) == null
                ? Text(
                    (data['name'] as String).isNotEmpty
                        ? (data['name'] as String)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data['name'] as String,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Text(
                '${data['correct']}',
                style: const TextStyle(color: AppTheme.supportGreen, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Text(
                '${data['total']}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rateColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$winRate%',
                  style: TextStyle(color: rateColor, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── POINTS TAB WIDGETS ───────────────────────────────────────────────────────

class _MyRankBanner extends StatelessWidget {
  final UserModel user;
  final List<UserModel> users;
  const _MyRankBanner({required this.user, required this.users});

  @override
  Widget build(BuildContext context) {
    final rank = users.indexWhere((u) => u.uid == user.uid) + 1;
    if (rank == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Ranking', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('#$rank of ${users.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${user.points}',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('pts', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<UserModel> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: AppTheme.cardBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top3.length > 1) _PodiumItem(user: top3[1], rank: 2, height: 70),
          if (top3.isNotEmpty) _PodiumItem(user: top3[0], rank: 1, height: 100),
          if (top3.length > 2) _PodiumItem(user: top3[2], rank: 3, height: 50),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final UserModel user;
  final int rank;
  final double height;
  const _PodiumItem({required this.user, required this.rank, required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = [AppTheme.accent, Colors.grey[400]!, Colors.brown[400]!];
    final color = colors[rank - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(rank == 1 ? '👑' : '', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: rank == 1 ? 30 : 22,
            backgroundColor: color.withValues(alpha: 0.2),
            backgroundImage: safeNetworkImage(user.photoUrl),
            child: safeNetworkImage(user.photoUrl) == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: rank == 1 ? 20 : 15),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(user.name.split(' ').first,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          Text('${user.points} pts', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text('#$rank', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final UserModel user;
  final int rank;
  final bool isMe;
  const _LeaderRow({required this.user, required this.rank, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryLight.withValues(alpha: 0.15) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#$rank',
                style: TextStyle(
                  color: rank <= 3 ? AppTheme.accent : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardBg2,
            backgroundImage: safeNetworkImage(user.photoUrl),
            child: safeNetworkImage(user.photoUrl) == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                if (user.streak > 0)
                  Text('🔥 ${user.streak} day streak',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text('${user.points}',
              style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w900, fontSize: 16)),
          const Text(' pts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
