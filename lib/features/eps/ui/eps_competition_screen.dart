import 'package:clubera/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/eps_competition_model.dart';
import '../../clubs/ui/club_profile_screen.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// "21/11 · 15:00" (or only the date when the ΕΠΣ has not set a time).
String epsDateLabel(BuildContext context, EpsMatch m) {
  final d = m.scheduledAt;
  if (d == null) return AppLocalizations.of(context).eps_date_tbd;
  final date = '${_two(d.day)}/${_two(d.month)}';
  return m.hasTime ? '$date · ${_two(d.hour)}:${_two(d.minute)}' : date;
}

String _host(String? url) {
  if (url == null) return '';
  return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
}

void _openClub(BuildContext context, String? clubId) {
  if (clubId == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId)),
  );
}

/// One ΕΠΣ championship: standings + matches by matchday.
class EpsCompetitionScreen extends StatelessWidget {
  final String competitionId;
  final String title;

  /// Club to highlight (e.g. when opened from a club page).
  final String? highlightClubId;

  const EpsCompetitionScreen({
    super.key,
    required this.competitionId,
    required this.title,
    this.highlightClubId,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: l.eps_standings),
              Tab(text: l.eps_fixtures),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('eps_competitions')
              .doc(competitionId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text(l.m_error('${snap.error}'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              return Center(
                child: Text(l.eps_no_standings,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              );
            }
            final comp = EpsCompetition.fromMap(data, snap.data!.id);
            return TabBarView(
              children: [
                _StandingsTab(comp: comp, highlightClubId: highlightClubId),
                _FixturesTab(comp: comp, highlightClubId: highlightClubId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  final EpsCompetition comp;
  const _SourceNote({required this.comp});

  @override
  Widget build(BuildContext context) {
    final host = _host(comp.sourceUrl);
    final source = host.isEmpty ? comp.assocName : '${comp.assocName} ($host)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Text(
        AppLocalizations.of(context).eps_source(source),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}

// ─── Standings ──────────────────────────────────────────────────────────────

class _StandingsTab extends StatelessWidget {
  final EpsCompetition comp;
  final String? highlightClubId;
  const _StandingsTab({required this.comp, this.highlightClubId});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (comp.standings.isEmpty) {
      return Center(
        child: Text(l.eps_no_standings,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    const head = TextStyle(
        color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700);
    Widget cell(String s, {double w = 26, TextStyle? style}) => SizedBox(
          width: w,
          child: Text(s, textAlign: TextAlign.center, style: style),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              cell('#', w: 24, style: head),
              Expanded(child: Text(l.eps_col_team, style: head)),
              cell(l.eps_col_played, style: head),
              cell(l.eps_col_won, style: head),
              cell(l.eps_col_drawn, style: head),
              cell(l.eps_col_lost, style: head),
              cell(l.eps_col_goals, w: 46, style: head),
              cell(l.eps_col_points, w: 30, style: head),
            ],
          ),
        ),
        ...comp.standings.map((s) {
          final mine = highlightClubId != null && s.clubId == highlightClubId;
          final linked = s.clubId != null;
          final text = TextStyle(
            color: mine ? AppTheme.accent : Colors.white,
            fontSize: 13,
            fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
          );
          return InkWell(
            onTap: linked ? () => _openClub(context, s.clubId) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: mine
                    ? AppTheme.accent.withValues(alpha: 0.10)
                    : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: mine ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.divider),
              ),
              child: Row(
                children: [
                  cell('${s.position}', w: 24, style: text),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(s.team,
                              overflow: TextOverflow.ellipsis, style: text),
                        ),
                        if (linked)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified,
                                size: 13, color: AppTheme.primaryLight),
                          ),
                      ],
                    ),
                  ),
                  cell('${s.played}', style: text),
                  cell('${s.won}', style: text),
                  cell('${s.drawn}', style: text),
                  cell('${s.lost}', style: text),
                  cell('${s.goalsFor}-${s.goalsAgainst}', w: 46, style: text),
                  cell('${s.points}',
                      w: 30,
                      style: text.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        }),
        _SourceNote(comp: comp),
      ],
    );
  }
}

// ─── Fixtures ───────────────────────────────────────────────────────────────

class _FixturesTab extends StatefulWidget {
  final EpsCompetition comp;
  final String? highlightClubId;
  const _FixturesTab({required this.comp, this.highlightClubId});

  @override
  State<_FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<_FixturesTab> {
  int? _round;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rounds = widget.comp.rounds;
    final round = _round ?? widget.comp.currentRound;
    if (rounds.isEmpty || round == null) {
      return Center(
        child: Text(l.eps_no_matches,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    final idx = rounds.indexOf(round);
    final matches = widget.comp.matchesOfRound(round);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: idx > 0 ? () => setState(() => _round = rounds[idx - 1]) : null,
            ),
            Expanded(
              child: Text(
                l.eps_round(round),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: idx >= 0 && idx < rounds.length - 1
                  ? () => setState(() => _round = rounds[idx + 1])
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.eps_no_matches,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ...matches.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EpsMatchTile(match: m, highlightClubId: widget.highlightClubId),
            )),
        _SourceNote(comp: widget.comp),
      ],
    );
  }
}

/// A single ΕΠΣ match: teams, score (or date) and ground.
class EpsMatchTile extends StatelessWidget {
  final EpsMatch match;
  final String? highlightClubId;
  final bool showRound;

  const EpsMatchTile({
    super.key,
    required this.match,
    this.highlightClubId,
    this.showRound = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = match;
    TextStyle teamStyle(String? clubId) {
      final mine = highlightClubId != null && clubId == highlightClubId;
      return TextStyle(
        color: mine ? AppTheme.accent : Colors.white,
        fontSize: 13,
        fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
      );
    }

    Widget team(String name, String? clubId, TextAlign align) => Expanded(
          child: InkWell(
            onTap: clubId != null ? () => _openClub(context, clubId) : null,
            child: Text(
              name,
              textAlign: align,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: teamStyle(clubId),
            ),
          ),
        );

    final info = <String>[
      if (showRound && m.round != null) l.eps_round(m.round!),
      epsDateLabel(context, m),
      if (m.venue != null && m.venue!.isNotEmpty) m.venue!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              team(m.homeTeam, m.homeClubId, TextAlign.right),
              Container(
                width: 64,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: m.isFinished
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.isFinished ? '${m.homeScore} - ${m.awayScore}' : (m.note ?? '–'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: m.isFinished ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: m.isFinished ? 15 : 12,
                  ),
                ),
              ),
              team(m.awayTeam, m.awayClubId, TextAlign.left),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
