import 'package:clubera/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/eps_competition_model.dart';
import 'eps_competition_screen.dart';

/// Shows the championships read automatically from the ΕΠΣ website
/// (eps_associations/{assocId}). When there are none yet, shows [fallback]
/// (the manually maintained list).
class EpsAssociationGate extends StatelessWidget {
  final String assocId;
  final Widget fallback;

  const EpsAssociationGate({super.key, required this.assocId, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eps_associations')
          .doc(assocId)
          .snapshots(),
      builder: (context, snap) {
        // No data, no permission (rules not deployed yet) or still loading:
        // keep the existing screen.
        if (snap.hasError || !snap.hasData) return fallback;
        final data = snap.data!.data() as Map<String, dynamic>?;
        final list = ((data?['competitions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => EpsCompetitionEntry.fromMap(Map<String, dynamic>.from(e)))
            .where((e) => e.id.isNotEmpty)
            .toList();
        if (list.isEmpty) return fallback;
        return EpsAssociationList(
          competitions: list,
          assocName: data?['name'] as String? ?? '',
        );
      },
    );
  }
}

class EpsAssociationList extends StatelessWidget {
  final List<EpsCompetitionEntry> competitions;
  final String assocName;

  const EpsAssociationList({super.key, required this.competitions, required this.assocName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final men = competitions.where((c) => !c.isYouth && !c.isWomen).toList();
    final women = competitions.where((c) => !c.isYouth && c.isWomen).toList();
    final youth = competitions.where((c) => c.isYouth).toList()
      ..sort((a, b) {
        // K17 before K8: older age groups first, then keep the site's order.
        final na = int.tryParse((a.ageGroup ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;
        final nb = int.tryParse((b.ageGroup ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;
        return nb.compareTo(na);
      });

    Widget header(String text, Color color, {bool first = false}) => Padding(
          padding: EdgeInsets.only(top: first ? 0 : 20, bottom: 8),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
        );

    final children = <Widget>[];
    void section(String title, Color color, List<EpsCompetitionEntry> items) {
      if (items.isEmpty) return;
      children.add(header(title, color, first: children.isEmpty));
      children.addAll(items.map((c) => _EpsCompetitionTile(entry: c, assocName: assocName)));
    }

    section(l.eps_section_men, AppTheme.textSecondary, men);
    section(l.eps_section_women, const Color(0xFFf472b6), women);
    section(l.eps_section_youth, AppTheme.primaryLight, youth);
    children.add(Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Text(
        l.eps_source(assocName),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    ));

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class _EpsCompetitionTile extends StatelessWidget {
  final EpsCompetitionEntry entry;
  final String assocName;

  const _EpsCompetitionTile({required this.entry, required this.assocName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sub = [
      if (entry.season != null) entry.season!,
      if (entry.teams > 0) l.eps_teams_count(entry.teams),
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EpsCompetitionScreen(competitionId: entry.id, title: entry.name),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.navyGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.isYouth ? Icons.child_care : Icons.emoji_events,
                    color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
