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
    AppBar appBar([List<Widget>? tabs]) => AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: tabs == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppTheme.accent,
                  labelColor: AppTheme.accent,
                  unselectedLabelColor: AppTheme.textSecondary,
                  tabs: tabs,
                ),
        );
    Widget message(String text) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar(),
          body: Center(
            child: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        );

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eps_competitions')
          .doc(competitionId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return message(l.m_error('${snap.error}'));
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return message(l.eps_no_standings);
        final comp = EpsCompetition.fromMap(data, snap.data!.id);

        // Scorers tab only where the ΕΠΣ publishes scorers (senior leagues).
        final hasScorers = comp.scorers.isNotEmpty;
        final tabs = <Widget>[
          Tab(text: l.eps_standings),
          Tab(text: l.eps_fixtures),
          if (hasScorers) Tab(text: l.eps_scorers),
          Tab(text: l.eps_stats),
        ];
        final views = <Widget>[
          _StandingsTab(comp: comp, highlightClubId: highlightClubId),
          _FixturesTab(comp: comp, highlightClubId: highlightClubId),
          if (hasScorers) _ScorersTab(comp: comp, highlightClubId: highlightClubId),
          _StatsTab(comp: comp),
        ];
        return DefaultTabController(
          key: ValueKey(tabs.length),
          length: tabs.length,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar(tabs),
            body: TabBarView(children: views),
          ),
        );
      },
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

// ─── Scorers ────────────────────────────────────────────────────────────────

class _ScorersTab extends StatelessWidget {
  final EpsCompetition comp;
  final String? highlightClubId;
  const _ScorersTab({required this.comp, this.highlightClubId});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (comp.scorers.isEmpty) {
      return Center(
        child: Text(l.eps_no_scorers, style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    final total = comp.scorers.fold<int>(0, (sum, s) => sum + s.goals);
    const head = TextStyle(
        color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700);

    // Same goals = same position (1, 2, 2, 4 ...).
    final positions = <int>[];
    for (var i = 0; i < comp.scorers.length; i++) {
      positions.add(i > 0 && comp.scorers[i].goals == comp.scorers[i - 1].goals
          ? positions[i - 1]
          : i + 1);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l.eps_scorers_summary(comp.scorers.length, total),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              const SizedBox(width: 28, child: Text('#', style: head)),
              Expanded(child: Text(l.eps_col_player, style: head)),
              SizedBox(
                width: 44,
                child: Text(l.eps_col_goals, textAlign: TextAlign.center, style: head),
              ),
            ],
          ),
        ),
        for (var i = 0; i < comp.scorers.length; i++)
          _scorerRow(context, comp.scorers[i], positions[i]),
        _SourceNote(comp: comp),
      ],
    );
  }

  Widget _scorerRow(BuildContext context, EpsScorer s, int position) {
    final mine = highlightClubId != null && s.clubId == highlightClubId;
    final halves = s.firstHalf != null && s.secondHalf != null
        ? '(${s.firstHalf}+${s.secondHalf})'
        : '';
    return InkWell(
      onTap: s.clubId != null ? () => _openClub(context, s.clubId) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? AppTheme.accent.withValues(alpha: 0.10) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: mine ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$position',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: mine ? AppTheme.accent : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(s.team,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text('${s.goals}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  if (halves.isNotEmpty)
                    Text(halves,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Statistics ─────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final EpsCompetition comp;
  const _StatsTab({required this.comp});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = comp.stats;
    if (st.played == 0) {
      return Center(
        child: Text(l.eps_no_stats, style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }

    Widget tile(String label, String value) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.accent, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        );

    Widget highlight(IconData icon, String label, String team, String detail, String? clubId) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: InkWell(
            onTap: clubId != null ? () => _openClub(context, clubId) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label.toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 3),
                        Text(team,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(detail,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    final big = st.biggestWin;
    final top = st.highestScoring;
    String matchLine(EpsMatch m) => '${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}';
    String matchInfo(EpsMatch m) =>
        [if (m.round != null) l.eps_round(m.round!), epsDateLabel(context, m)].join(' · ');
    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          tile(l.eps_matches_played, '${st.played}'),
          tile(l.eps_total_goals, '${st.totalGoals}'),
          tile(l.eps_goals_per_match, st.goalsPerMatch.toStringAsFixed(2)),
        ]),
        section(l.eps_section_results),
        Row(children: [
          tile(l.eps_home_wins, '${st.homeWins}'),
          tile(l.eps_draws, '${st.draws}'),
          tile(l.eps_away_wins, '${st.awayWins}'),
        ]),
        section(l.eps_section_goals),
        Row(children: [
          tile(l.eps_home_goals, '${st.homeGoals}'),
          tile(l.eps_away_goals, '${st.awayGoals}'),
        ]),
        Row(children: [
          tile(l.eps_three_plus, '${st.threePlusGoals}'),
          tile(l.eps_up_to_two, '${st.upToTwoGoals}'),
        ]),
        Row(children: [
          tile(l.eps_both_scored, '${st.bothScored}'),
          tile(l.eps_clean_sheets, '${st.cleanSheets}'),
        ]),
        section(l.eps_section_records),
        if (st.bestAttack != null)
          highlight(Icons.sports_soccer, l.eps_best_attack, st.bestAttack!.team,
              l.eps_goals_count(st.bestAttack!.goalsFor), st.bestAttack!.clubId),
        if (st.bestDefence != null)
          highlight(Icons.shield, l.eps_best_defence, st.bestDefence!.team,
              l.eps_goals_conceded(st.bestDefence!.goalsAgainst), st.bestDefence!.clubId),
        if (st.mostCleanSheetsTeam != null)
          highlight(Icons.lock, l.eps_most_clean_sheets, st.mostCleanSheetsTeam!,
              l.eps_matches_count(st.mostCleanSheets), st.mostCleanSheetsClubId),
        if (big != null)
          highlight(Icons.bolt, l.eps_biggest_win, matchLine(big), matchInfo(big), null),
        if (top != null)
          highlight(Icons.local_fire_department, l.eps_highest_scoring, matchLine(top),
              matchInfo(top), null),
        _SourceNote(comp: comp),
      ],
    );
  }
}
