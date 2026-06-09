import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_provider.dart';

class StreakResult {
  final int newStreak;
  final int bonusPoints;
  final bool isNewStreak;
  const StreakResult({
    required this.newStreak,
    required this.bonusPoints,
    required this.isNewStreak,
  });
}

class StreakService {
  static int _bonusFor(int streak) {
    if (streak >= 30) return 100;
    if (streak >= 14) return 50;
    if (streak >= 7) return 25;
    if (streak >= 3) return 15;
    return 10;
  }

  /// Call once per app open. Returns a StreakResult if streak was updated
  /// (login bonus awarded), or null if already logged in today.
  static Future<StreakResult?> check(AppProvider provider) async {
    final user = provider.user;
    if (user == null) return null;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await userRef.get();
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      final last = (data['lastLoginAt'] as Timestamp?)?.toDate();
      final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (last != null) {
        final lastDay = DateTime(last.year, last.month, last.day);
        if (lastDay == today) {
          // Already logged in today — no change.
          return null;
        }
        final diff = today.difference(lastDay).inDays;
        final newStreak = diff == 1 ? currentStreak + 1 : 1;
        final bonus = _bonusFor(newStreak);
        await userRef.update({
          'streak': newStreak,
          'points': FieldValue.increment(bonus),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        provider.updateUser(user.copyWith(
          streak: newStreak,
          points: user.points + bonus,
        ));
        return StreakResult(
          newStreak: newStreak,
          bonusPoints: bonus,
          isNewStreak: diff > 1,
        );
      } else {
        // First-ever login (no lastLoginAt recorded).
        final bonus = _bonusFor(1);
        await userRef.update({
          'streak': 1,
          'points': FieldValue.increment(bonus),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        provider.updateUser(user.copyWith(
          streak: 1,
          points: user.points + bonus,
        ));
        return StreakResult(newStreak: 1, bonusPoints: bonus, isNewStreak: true);
      }
    } catch (e) {
      debugPrint('StreakService error: $e');
      return null;
    }
  }
}
