import 'package:flutter/material.dart';

class FanTier {
  final String name;
  final String emoji;
  final Color color;
  final int minPoints;
  const FanTier({
    required this.name,
    required this.emoji,
    required this.color,
    required this.minPoints,
  });
}

const List<FanTier> kFanTiers = [
  FanTier(name: 'Bronze',   emoji: '🥉', color: Color(0xFFCD7F32), minPoints: 0),
  FanTier(name: 'Silver',   emoji: '🥈', color: Color(0xFFC0C0C0), minPoints: 50),
  FanTier(name: 'Gold',     emoji: '🥇', color: Color(0xFFFFD700), minPoints: 200),
  FanTier(name: 'Platinum', emoji: '💎', color: Color(0xFF7DF9FF), minPoints: 500),
];

FanTier tierForPoints(int pts) {
  var current = kFanTiers.first;
  for (final t in kFanTiers) {
    if (pts >= t.minPoints) current = t;
  }
  return current;
}

class FanStatsModel {
  final String id;            // "{userId}_{clubId}"
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String clubId;
  final String clubName;
  final int clubScore;
  final int predictionsCorrect;
  final int predictionsExact;
  final double donations;
  final int votes;
  final bool isFollower;
  final DateTime? followedAt;
  final DateTime updatedAt;

  const FanStatsModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.clubId,
    required this.clubName,
    required this.clubScore,
    required this.predictionsCorrect,
    required this.predictionsExact,
    required this.donations,
    required this.votes,
    required this.isFollower,
    this.followedAt,
    required this.updatedAt,
  });

  FanTier get tier => tierForPoints(clubScore);

  factory FanStatsModel.fromMap(Map<String, dynamic> m, String id) => FanStatsModel(
    id: id,
    userId: m['userId'] ?? '',
    userName: m['userName'] ?? '',
    userPhotoUrl: m['userPhotoUrl'] ?? '',
    clubId: m['clubId'] ?? '',
    clubName: m['clubName'] ?? '',
    clubScore: (m['clubScore'] as num?)?.toInt() ?? 0,
    predictionsCorrect: (m['predictionsCorrect'] as num?)?.toInt() ?? 0,
    predictionsExact: (m['predictionsExact'] as num?)?.toInt() ?? 0,
    donations: (m['donations'] as num?)?.toDouble() ?? 0.0,
    votes: (m['votes'] as num?)?.toInt() ?? 0,
    isFollower: m['isFollower'] ?? false,
    followedAt: (m['followedAt'] as dynamic)?.toDate(),
    updatedAt: (m['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );
}
