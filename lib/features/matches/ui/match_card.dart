import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/match_model.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;

  const MatchCard({super.key, required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: match.isLive
              ? Border.all(color: AppTheme.liveRed.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statusBadge(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _teamWidget(match.homeClubName, match.homeClubLogo, Alignment.centerLeft)),
                _scoreWidget(),
                Expanded(child: _teamWidget(match.awayClubName, match.awayClubLogo, Alignment.centerRight)),
              ],
            ),
            const SizedBox(height: 8),
            Text(match.league, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge() {
    if (match.isLive) {
      final minute = match.minute ?? '';
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.liveRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 6),
                const SizedBox(width: 4),
                Text(match.status == 'halftime' ? 'HT' : 'LIVE ${minute.isNotEmpty ? "$minute'" : ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      );
    }
    if (match.isFinished) {
      return const Center(
        child: Text('FULL TIME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Center(
      child: Text(
        DateFormat('EEE dd MMM • HH:mm').format(match.scheduledAt),
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }

  Widget _scoreWidget() {
    if (match.isUpcoming) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('vs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('${match.homeScore}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const Text(' – ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 20)),
          Text('${match.awayScore}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _teamWidget(String name, String? logo, Alignment align) {
    final isLeft = align == Alignment.centerLeft;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.cardBg2,
            shape: BoxShape.circle,
            image: safeNetworkImage(logo) != null
                ? DecorationImage(image: safeNetworkImage(logo)!, fit: BoxFit.cover)
                : null,
          ),
          child: safeNetworkImage(logo) == null
              ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 22)
              : null,
        ),
        const SizedBox(height: 4),
        Text(name, textAlign: isLeft ? TextAlign.left : TextAlign.right,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
