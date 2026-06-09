import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/fan_stats_model.dart';

/// Compact "Fan Card" showing a user's engagement with a club:
/// tier badge, total club score, ranking, key counters.
class FanCard extends StatelessWidget {
  final String userId;
  final String clubId;
  final bool showRank;
  const FanCard({
    super.key,
    required this.userId,
    required this.clubId,
    this.showRank = true,
  });

  @override
  Widget build(BuildContext context) {
    final id = '${userId}_$clubId';
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('fan_stats').doc(id).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _FanCardSkeleton();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final stats = FanStatsModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          snap.data!.id,
        );
        return _FanCardContent(stats: stats, showRank: showRank);
      },
    );
  }
}

class _FanCardContent extends StatelessWidget {
  final FanStatsModel stats;
  final bool showRank;
  const _FanCardContent({required this.stats, required this.showRank});

  @override
  Widget build(BuildContext context) {
    final tier = stats.tier;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cardBg, AppTheme.cardGlow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tier.color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tier.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fan of ${stats.clubName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tier.name} Tier',
                      style: TextStyle(
                        color: tier.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.clubScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'pts',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                emoji: '🎯',
                value: '${stats.predictionsCorrect}',
                label: 'Predicts',
              ),
              _Stat(
                emoji: '💎',
                value: '${stats.predictionsExact}',
                label: 'Exact',
              ),
              _Stat(
                emoji: '❤️',
                value: '€${stats.donations.toStringAsFixed(0)}',
                label: 'Donated',
              ),
              _Stat(
                emoji: '⭐',
                value: '${stats.votes}',
                label: 'Votes',
              ),
            ],
          ),
          if (showRank) ...[
            const SizedBox(height: 12),
            _RankRow(clubId: stats.clubId, userScore: stats.clubScore),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _Stat({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String clubId;
  final int userScore;
  const _RankRow({required this.clubId, required this.userScore});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('fan_stats')
          .where('clubId', isEqualTo: clubId)
          .where('clubScore', isGreaterThan: userScore)
          .count()
          .get(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 16);
        }
        final ahead = snap.data!.count ?? 0;
        final rank = ahead + 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.leaderboard, color: AppTheme.primaryLight, size: 16),
              const SizedBox(width: 6),
              Text(
                'Ranked #$rank in this club',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FanCardSkeleton extends StatelessWidget {
  const _FanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 140,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

/// Mini chip used in "Top Fans" lists — row item with rank, avatar, name, score.
class TopFanRow extends StatelessWidget {
  final int rank;
  final FanStatsModel stats;
  const TopFanRow({super.key, required this.rank, required this.stats});

  @override
  Widget build(BuildContext context) {
    final tier = stats.tier;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tier.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                medal,
                style: TextStyle(
                  fontSize: rank <= 3 ? 22 : 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardBg,
            backgroundImage: stats.userPhotoUrl.isNotEmpty
                ? NetworkImage(stats.userPhotoUrl)
                : null,
            child: stats.userPhotoUrl.isEmpty
                ? Text(
                    stats.userName.isNotEmpty
                        ? stats.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${tier.emoji} ${tier.name}',
                  style: TextStyle(color: tier.color, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${stats.clubScore} pts',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
