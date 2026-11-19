import 'package:clubera/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/eps_competition_model.dart';
import '../../../models/match_model.dart';
import 'eps_association_list.dart';
import 'eps_competition_screen.dart';

/// One match of an ΕΠΣ day list (eps_days/{assocId}__{yyyy-MM-dd}).
class EpsDayMatch {
  final EpsMatch match;
  final String competitionId;
  final String competitionName;
  final String level; // 'senior' | 'youth'

  const EpsDayMatch({
    required this.match,
    required this.competitionId,
    required this.competitionName,
    required this.level,
  });

  bool get isSenior => level == 'senior';
  String get id => match.id ?? '';

  factory EpsDayMatch.fromMap(Map<String, dynamic> m) => EpsDayMatch(
        match: EpsMatch.fromMap(m),
        competitionId: m['competitionId'] as String? ?? '',
        competitionName: m['competitionName'] as String? ?? '',
        level: m['level'] as String? ?? 'senior',
      );

  /// For the existing coupon widgets, which work with [MatchModel].
  MatchModel toMatchModel() => MatchModel(
        id: id,
        homeClubId: match.homeClubId ?? '',
        homeClubName: match.homeTeam,
        awayClubId: match.awayClubId ?? '',
        awayClubName: match.awayTeam,
        homeScore: match.homeScore ?? 0,
        awayScore: match.awayScore ?? 0,
        status: match.isFinished ? 'finished' : 'upcoming',
        scheduledAt: match.scheduledAt ?? DateTime.now(),
        league: competitionName,
        venue: match.venue,
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

String epsDayId(String assocId, DateTime day) =>
    '${assocId}__${day.year}-${_two(day.month)}-${_two(day.day)}';

List<EpsDayMatch> epsDayMatchesFrom(Map<String, dynamic>? data) =>
    ((data?['matches'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => EpsDayMatch.fromMap(Map<String, dynamic>.from(e)))
        .where((m) => m.id.isNotEmpty)
        .toList();

/// The ΕΠΣ to show to this user: the one of their club or a followed club,
/// otherwise the first one with data. Calls [builder] with null while there
/// is none (or the rules do not allow reading yet).
class EpsAssociationScope extends StatefulWidget {
  final Widget Function(BuildContext context, String? assocId, String? assocName) builder;
  const EpsAssociationScope({super.key, required this.builder});

  @override
  State<EpsAssociationScope> createState() => _EpsAssociationScopeState();
}

class _EpsAssociationScopeState extends State<EpsAssociationScope> {
  // One stream for the widget's life, so parent rebuilds don't re-query.
  final Stream<QuerySnapshot> _associations =
      FirebaseFirestore.instance.collection('eps_associations').snapshots();

  Widget Function(BuildContext context, String? assocId, String? assocName) get builder =>
      widget.builder;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return StreamBuilder<QuerySnapshot>(
      stream: _associations,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.hasError || docs.isEmpty) return builder(context, null, null);
        final mine = <String>{
          if (user?.clubId != null) user!.clubId!,
          ...?user?.followedClubs,
        };
        QueryDocumentSnapshot? pick;
        for (final d in docs) {
          final clubIds = List<String>.from(
              ((d.data() as Map<String, dynamic>)['clubIds'] as List?) ?? const []);
          if (clubIds.any(mine.contains)) {
            pick = d;
            break;
          }
        }
        pick ??= docs.first;
        final name = (pick.data() as Map<String, dynamic>)['name'] as String? ?? '';
        return builder(context, pick.id, name);
      },
    );
  }
}

/// Header row "ΕΠΣ Αχαΐας · Πρωταθλήματα ›" above the ΕΠΣ matches.
class EpsChampionshipsLink extends StatelessWidget {
  final String assocId;
  final String assocName;
  const EpsChampionshipsLink({super.key, required this.assocId, required this.assocName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(
              title: Text(assocName),
              backgroundColor: Colors.transparent,
            ),
            body: EpsAssociationGate(
              assocId: assocId,
              fallback: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(assocName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            Text(l.eps_championships,
                style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
            const Icon(Icons.chevron_right, color: AppTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

/// ΕΠΣ matches of one day, grouped by championship (senior first).
class EpsDayMatchesList extends StatelessWidget {
  final List<EpsDayMatch> matches;
  const EpsDayMatchesList({super.key, required this.matches});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<EpsDayMatch>>{};
    for (final m in matches) {
      groups.putIfAbsent(m.competitionId, () => []).add(m);
    }
    final ids = groups.keys.toList()
      ..sort((a, b) {
        final ga = groups[a]!.first, gb = groups[b]!.first;
        if (ga.isSenior != gb.isSenior) return ga.isSenior ? -1 : 1;
        return ga.competitionName.compareTo(gb.competitionName);
      });
    final user = context.watch<AppProvider>().user;
    final highlight = user?.clubId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in ids) ...[
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EpsCompetitionScreen(
                  competitionId: id,
                  title: groups[id]!.first.competitionName,
                  highlightClubId: highlight,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      groups[id]!.first.competitionName.toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0),
                    ),
                  ),
                  const Icon(Icons.leaderboard, size: 15, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          for (final m in groups[id]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EpsCompetitionScreen(
                      competitionId: id,
                      title: m.competitionName,
                      highlightClubId: highlight,
                    ),
                  ),
                ),
                child: EpsMatchTile(match: m.match, highlightClubId: highlight),
              ),
            ),
        ],
      ],
    );
  }
}
