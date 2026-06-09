import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/badge_model.dart';

/// Displays all badges earned by a user — compact grid with tooltips.
class BadgesSection extends StatelessWidget {
  final String userId;
  const BadgesSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_badges')
          .where('userId', isEqualTo: userId)
          .orderBy('awardedAt', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final badges = docs
            .map((d) => UserBadge.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((b) => b.def != null)
            .toList();

        if (badges.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: AppTheme.primaryLight, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Badges (${badges.length})',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges.map((b) => _BadgeChip(badge: b)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final UserBadge badge;
  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final def = badge.def!;
    return Tooltip(
      message: badge.clubName != null
          ? '${def.description} (${badge.clubName})'
          : def.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: def.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: def.color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(def.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(
              def.name,
              style: TextStyle(
                color: def.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
