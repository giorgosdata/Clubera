import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeCode {
  firstPrediction,
  exactScore,
  predictions10,
  predictions50,
  firstDonation,
  donor50,
  firstMvpVote,
  topFan3,
  topFan1,
  silverTier,
  goldTier,
  platinumTier,
}

class BadgeDef {
  final BadgeCode code;
  final String emoji;
  final String name;
  final String description;
  final Color color;

  const BadgeDef({
    required this.code,
    required this.emoji,
    required this.name,
    required this.description,
    required this.color,
  });
}

const List<BadgeDef> kBadgeDefs = [
  BadgeDef(
    code: BadgeCode.firstPrediction,
    emoji: '🎯',
    name: 'Πρώτη Πρόβλεψη',
    description: 'Έκανες την πρώτη σου πρόβλεψη',
    color: Color(0xFF64B5F6),
  ),
  BadgeDef(
    code: BadgeCode.exactScore,
    emoji: '💎',
    name: 'Exact Score',
    description: 'Μάντεψες ακριβές σκορ',
    color: Color(0xFF7DF9FF),
  ),
  BadgeDef(
    code: BadgeCode.predictions10,
    emoji: '🔮',
    name: '10 Σωστές',
    description: '10 σωστές προβλέψεις',
    color: Color(0xFFAB47BC),
  ),
  BadgeDef(
    code: BadgeCode.predictions50,
    emoji: '🧠',
    name: 'Αναλυτής',
    description: '50 σωστές προβλέψεις',
    color: Color(0xFF7E57C2),
  ),
  BadgeDef(
    code: BadgeCode.firstDonation,
    emoji: '❤️',
    name: 'Υποστηρικτής',
    description: 'Έκανες την πρώτη σου δωρεά',
    color: Color(0xFFEF5350),
  ),
  BadgeDef(
    code: BadgeCode.donor50,
    emoji: '💪',
    name: 'Μεγάλος Χορηγός',
    description: 'Συνολικές δωρεές άνω των €50',
    color: Color(0xFFFF7043),
  ),
  BadgeDef(
    code: BadgeCode.firstMvpVote,
    emoji: '⭐',
    name: 'Κριτής MVP',
    description: 'Ψήφισες τον πρώτο σου MVP',
    color: Color(0xFFFFEE58),
  ),
  BadgeDef(
    code: BadgeCode.topFan3,
    emoji: '🏅',
    name: 'Top 3 Fan',
    description: 'Ανέβηκες στους top 3 fans ομάδας',
    color: Color(0xFFFFD700),
  ),
  BadgeDef(
    code: BadgeCode.topFan1,
    emoji: '🏆',
    name: '#1 Fan',
    description: 'Έγινες ο #1 fan ομάδας',
    color: Color(0xFFFFD700),
  ),
  BadgeDef(
    code: BadgeCode.silverTier,
    emoji: '🥈',
    name: 'Silver Fan',
    description: 'Έφτασες το Silver tier',
    color: Color(0xFFC0C0C0),
  ),
  BadgeDef(
    code: BadgeCode.goldTier,
    emoji: '🥇',
    name: 'Gold Fan',
    description: 'Έφτασες το Gold tier',
    color: Color(0xFFFFD700),
  ),
  BadgeDef(
    code: BadgeCode.platinumTier,
    emoji: '💎',
    name: 'Platinum Fan',
    description: 'Έφτασες το Platinum tier',
    color: Color(0xFF7DF9FF),
  ),
];

BadgeDef? badgeDefFor(BadgeCode code) {
  try {
    return kBadgeDefs.firstWhere((d) => d.code == code);
  } catch (_) {
    return null;
  }
}

BadgeDef? badgeDefForString(String codeStr) {
  try {
    final code = BadgeCode.values.firstWhere((c) => c.name == codeStr);
    return badgeDefFor(code);
  } catch (_) {
    return null;
  }
}

class UserBadge {
  final String id;        // "{userId}_{badgeCode}"
  final String userId;
  final String badgeCode;
  final String? clubId;
  final String? clubName;
  final DateTime awardedAt;

  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeCode,
    this.clubId,
    this.clubName,
    required this.awardedAt,
  });

  BadgeDef? get def => badgeDefForString(badgeCode);

  factory UserBadge.fromMap(Map<String, dynamic> m, String id) => UserBadge(
    id: id,
    userId: m['userId'] ?? '',
    badgeCode: m['badgeCode'] ?? '',
    clubId: m['clubId'],
    clubName: m['clubName'],
    awardedAt: (m['awardedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
