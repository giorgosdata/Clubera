import 'package:clubera/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/eps_competition_model.dart';
import 'eps_competition_screen.dart';

/// On a club page: the club's ΕΠΣ championships with position, next match
/// and latest results. Shows nothing if the club is not in any.
class ClubEpsSection extends StatelessWidget {
  final String clubId;
  const ClubEpsSection({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eps_competitions')
          .where('clubIds', arrayContains: clubId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
        final comps = snap.data!.docs
            .map((d) => EpsCompetition.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList()
          // Senior first, then youth by age group (K17 before K8).
          ..sort((a, b) {
            if (a.level != b.level) return a.level == 'senior' ? -1 : 1;
            return b.name.compareTo(a.name);
          });
        if (comps.isEmpty) return const SizedBox.shrink();
        return Column(
          children: comps.map((c) => _ClubCompetitionCard(comp: c, clubId: clubId)).toList(),
        );
      },
    );
  }
}

class _ClubCompetitionCard extends StatelessWidget {
  final EpsCompetition comp;
  final String clubId;
  const _ClubCompetitionCard({required this.comp, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final standing = comp.standingOf(clubId);
    final next = comp.nextMatchOf(clubId);
    final last = comp.lastResultsOf(clubId);
    final scorers = comp.scorersOf(clubId);

    const label = TextStyle(
        color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(comp.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          if (standing != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(
                l.eps_position(standing.position, standing.points),
                style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Text(l.eps_next_match.toUpperCase(), style: label),
            const SizedBox(height: 6),
            EpsMatchTile(match: next, highlightClubId: clubId, showRound: true),
          ],
          if (last.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.eps_last_results.toUpperCase(), style: label),
            const SizedBox(height: 6),
            ...last.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: EpsMatchTile(match: m, highlightClubId: clubId, showRound: true),
                )),
          ],
          if (scorers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.eps_club_scorers.toUpperCase(), style: label),
            const SizedBox(height: 6),
            ...scorers.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_soccer, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      Text(l.eps_goals_count(s.goals),
                          style: const TextStyle(
                              color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EpsCompetitionScreen(
                    competitionId: comp.id,
                    title: comp.name,
                    highlightClubId: clubId,
                  ),
                ),
              ),
              icon: const Icon(Icons.leaderboard, size: 16, color: AppTheme.accent),
              label: Text(l.eps_view_competition,
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
