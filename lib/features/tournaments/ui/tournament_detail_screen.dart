import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/tournament_model.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with TickerProviderStateMixin {
  TabController? _tab;
  String? _lastFormat;

  void _initTabs(TournamentModel t) {
    final tabCount = _tabCount(t);
    if (_tab == null || t.format != _lastFormat) {
      _tab?.dispose();
      _tab = TabController(length: tabCount, vsync: this);
      _lastFormat = t.format;
    }
  }

  int _tabCount(TournamentModel t) {
    int c = 2; // Αγώνες + Πληροφορίες
    if (t.hasGroups) c++;   // Βαθμολογία
    if (t.hasKnockout) c++; // Κλήρωση
    return c;
  }

  List<Tab> _tabs(TournamentModel t) {
    return [
      const Tab(text: 'Αγώνες'),
      if (t.hasGroups) const Tab(text: 'Βαθμολογία'),
      if (t.hasKnockout) const Tab(text: 'Κλήρωση'),
      const Tab(text: 'Πληροφορίες'),
    ];
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final canAdmin = user?.role == 'admin' ||
        (user?.role == 'club' && user?.clubId != null);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .snapshots(),
      builder: (ctx, tSnap) {
        if (!tSnap.hasData) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!tSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: Text('Δεν βρέθηκε το τουρνουά')),
          );
        }
        final tournament = TournamentModel.fromMap(
            tSnap.data!.data() as Map<String, dynamic>, widget.tournamentId);
        _initTabs(tournament);
        final tab = _tab!;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('matches')
              .snapshots(),
          builder: (ctx, mSnap) {
            final allMatches = mSnap.hasData
                ? mSnap.data!.docs
                    .map((d) => TournamentMatch.fromMap(
                        d.data() as Map<String, dynamic>, d.id))
                    .toList()
                : <TournamentMatch>[];

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppTheme.surface,
                    title: Text(tournament.name),
                    actions: [
                      if (canAdmin && tournament.status == 'groups' && tournament.hasKnockout)
                        TextButton(
                          onPressed: () => _advanceToKnockout(ctx, tournament, allMatches),
                          child: const Text('→ Νοκ-Άουτ',
                              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                        ),
                      if (canAdmin && tournament.status == 'knockout')
                        TextButton(
                          onPressed: () => _finishTournament(tournament),
                          child: const Text('Λήξη',
                              style: TextStyle(color: AppTheme.supportGreen, fontWeight: FontWeight.bold)),
                        ),
                    ],
                    bottom: TabBar(
                      controller: tab,
                      indicatorColor: AppTheme.accent,
                      labelColor: AppTheme.accent,
                      unselectedLabelColor: AppTheme.textSecondary,
                      isScrollable: true,
                      tabs: _tabs(tournament),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: tab,
                  children: [
                    _MatchesTab(
                      tournamentId: widget.tournamentId,
                      matches: allMatches,
                      canAdmin: canAdmin,
                      tournament: tournament,
                    ),
                    if (tournament.hasGroups)
                      _StandingsTab(tournament: tournament, matches: allMatches),
                    if (tournament.hasKnockout)
                      _BracketTab(tournament: tournament, matches: allMatches),
                    _InfoTab(tournament: tournament),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _advanceToKnockout(BuildContext context, TournamentModel t, List<TournamentMatch> matches) async {
    // Get group winners and runners-up
    final advancingTeams = <TournamentTeam>[];
    for (var g = 0; g < t.groupCount; g++) {
      final groupName = 'Group ${String.fromCharCode(65 + g)}';
      final standings = GroupStanding.compute(groupName, matches);
      if (standings.isNotEmpty) {
        advancingTeams.add(TournamentTeam(
            id: standings[0].teamId, name: standings[0].teamName));
      }
      if (standings.length > 1) {
        advancingTeams.add(TournamentTeam(
            id: standings[1].teamId, name: standings[1].teamName));
      }
    }

    if (advancingTeams.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Δεν υπάρχουν αποτελέσματα για να γίνει προαγωγή'),
          backgroundColor: AppTheme.red,
        ));
      }
      return;
    }

    // Update TBD knockout matches with actual teams
    final knockoutMatches = matches
        .where((m) => m.phase == 'knockout' && m.bracketRound == 0)
        .toList()
      ..sort((a, b) => a.bracketPosition.compareTo(b.bracketPosition));

    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < knockoutMatches.length && i * 2 + 1 < advancingTeams.length; i++) {
      final docRef = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(t.id)
          .collection('matches')
          .doc(knockoutMatches[i].id);
      batch.update(docRef, {
        'homeTeamId': advancingTeams[i * 2].id,
        'homeTeamName': advancingTeams[i * 2].name,
        'awayTeamId': advancingTeams[i * 2 + 1].id,
        'awayTeamName': advancingTeams[i * 2 + 1].name,
        'status': 'scheduled',
      });
    }
    await batch.commit();
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(t.id)
        .update({'status': 'knockout'});
  }

  Future<void> _finishTournament(TournamentModel t) async {
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(t.id)
        .update({'status': 'finished'});
  }
}

// ─── MATCHES TAB ──────────────────────────────────────────────────────────────

class _MatchesTab extends StatelessWidget {
  final String tournamentId;
  final List<TournamentMatch> matches;
  final bool canAdmin;
  final TournamentModel tournament;
  const _MatchesTab({
    required this.tournamentId,
    required this.matches,
    required this.canAdmin,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Text('Δεν υπάρχουν αγώνες', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    // Sort: group matches first (by groupName), then knockout (by round)
    final grouped = <String, List<TournamentMatch>>{};
    for (final m in matches) {
      if (m.phase == 'group') {
        final key = m.groupName ?? 'Group';
        grouped.putIfAbsent(key, () => []).add(m);
      } else {
        final label = _knockoutLabel(m.bracketRound, tournament.totalRounds);
        grouped.putIfAbsent(label, () => []).add(m);
      }
    }
    // Sort within each group
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.bracketPosition.compareTo(b.bracketPosition));
    }

    final sections = grouped.keys.toList()
      ..sort((a, b) {
        // Group A before Group B, groups before knockout rounds
        final aIsGroup = a.startsWith('Group');
        final bIsGroup = b.startsWith('Group');
        if (aIsGroup && !bIsGroup) return -1;
        if (!aIsGroup && bIsGroup) return 1;
        return a.compareTo(b);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections.expand((section) {
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(section.toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          ...grouped[section]!.map((m) => _MatchTile(
                match: m,
                canAdmin: canAdmin,
                tournamentId: tournamentId,
                tournament: tournament,
              )),
          const SizedBox(height: 8),
        ];
      }).toList(),
    );
  }

  String _knockoutLabel(int round, int totalRounds) {
    final roundsFromFinal = totalRounds - round - 1;
    if (roundsFromFinal == 0) return 'Τελικός';
    if (roundsFromFinal == 1) return 'Ημιτελικά';
    if (roundsFromFinal == 2) return 'Προημιτελικά';
    return 'Γύρος ${round + 1}';
  }
}

class _MatchTile extends StatelessWidget {
  final TournamentMatch match;
  final bool canAdmin;
  final String tournamentId;
  final TournamentModel tournament;
  const _MatchTile({
    required this.match,
    required this.canAdmin,
    required this.tournamentId,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    final m = match;
    final isFinished = m.isFinished;
    final isTbd = m.isTbd;
    Color borderColor = AppTheme.divider;
    if (isFinished) borderColor = AppTheme.supportGreen.withValues(alpha: 0.4);
    if (isTbd) borderColor = AppTheme.cardBg2;

    return GestureDetector(
      onTap: canAdmin && !isTbd ? () => _showResultSheet(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                m.homeTeamName,
                style: TextStyle(
                  color: isFinished && m.homeScore > m.awayScore
                      ? Colors.white
                      : isFinished
                          ? AppTheme.textSecondary
                          : Colors.white,
                  fontWeight: isFinished && m.homeScore > m.awayScore
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFinished
                    ? AppTheme.supportGreen.withValues(alpha: 0.1)
                    : isTbd
                        ? AppTheme.cardBg2
                        : AppTheme.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFinished
                      ? AppTheme.supportGreen.withValues(alpha: 0.3)
                      : AppTheme.divider,
                ),
              ),
              child: Text(
                isTbd
                    ? 'TBD'
                    : isFinished
                        ? '${m.homeScore} – ${m.awayScore}'
                        : 'VS',
                style: TextStyle(
                  color: isFinished ? AppTheme.supportGreen : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.awayTeamName,
                style: TextStyle(
                  color: isFinished && m.awayScore > m.homeScore
                      ? Colors.white
                      : isFinished
                          ? AppTheme.textSecondary
                          : Colors.white,
                  fontWeight: isFinished && m.awayScore > m.homeScore
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (canAdmin && !isTbd)
              const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  void _showResultSheet(BuildContext context) {
    final homeCtrl = TextEditingController(text: match.isFinished ? '${match.homeScore}' : '');
    final awayCtrl = TextEditingController(text: match.isFinished ? '${match.awayScore}' : '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('${match.homeTeamName} vs ${match.awayTeamName}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(match.homeTeamName,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextField(
                        controller: homeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          filled: true, fillColor: AppTheme.cardBg2,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('–', style: TextStyle(color: AppTheme.textSecondary, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(match.awayTeamName,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextField(
                        controller: awayCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          filled: true, fillColor: AppTheme.cardBg2,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.supportGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final hs = int.tryParse(homeCtrl.text) ?? 0;
                  final as_ = int.tryParse(awayCtrl.text) ?? 0;
                  final winnerId = hs > as_ ? match.homeTeamId : (as_ > hs ? match.awayTeamId : null);
                  final winnerName = hs > as_ ? match.homeTeamName : (as_ > hs ? match.awayTeamName : null);
                  await FirebaseFirestore.instance
                      .collection('tournaments')
                      .doc(tournament.id)
                      .collection('matches')
                      .doc(match.id)
                      .update({
                        'homeScore': hs,
                        'awayScore': as_,
                        'status': 'finished',
                        'winnerId': winnerId,
                        'winnerName': winnerName,
                      });
                  // Auto-advance winner to next knockout round
                  if (match.phase == 'knockout' && winnerId != null) {
                    await _advanceWinner(tournament.id, match, winnerId, winnerName!);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Αποθήκευση', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _advanceWinner(String tournamentId, TournamentMatch match,
      String winnerId, String winnerName) async {
    final nextRound = match.bracketRound + 1;
    final nextPos = match.bracketPosition ~/ 2;
    final isHome = match.bracketPosition % 2 == 0;

    // Find the next match
    final snap = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .where('phase', isEqualTo: 'knockout')
        .where('bracketRound', isEqualTo: nextRound)
        .where('bracketPosition', isEqualTo: nextPos)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;
    final nextMatchDoc = snap.docs.first;
    final field = isHome ? 'homeTeamId' : 'awayTeamId';
    final nameField = isHome ? 'homeTeamName' : 'awayTeamName';
    await nextMatchDoc.reference.update({
      field: winnerId,
      nameField: winnerName,
      'status': 'scheduled',
    });
  }
}

// ─── STANDINGS TAB ────────────────────────────────────────────────────────────

class _StandingsTab extends StatelessWidget {
  final TournamentModel tournament;
  final List<TournamentMatch> matches;
  const _StandingsTab({required this.tournament, required this.matches});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(tournament.groupCount, (g) {
        final groupName = 'Group ${String.fromCharCode(65 + g)}';
        final standings = GroupStanding.compute(groupName, matches);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(groupName.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _StandingsHeader(),
                  ...standings.asMap().entries.map((e) =>
                      _StandingsRow(rank: e.key + 1, standing: e.value)),
                  if (standings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Δεν υπάρχουν αποτελέσματα ακόμα',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppTheme.cardBg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: const Row(
          children: [
            SizedBox(width: 24, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(child: Text('Ομάδα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 28, child: Text('Α', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 28, child: Text('Ν', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 28, child: Text('Ι', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 28, child: Text('Η', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 36, child: Text('GD', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            SizedBox(width: 32, child: Text('ΒΑΘ', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
          ],
        ),
      );
}

class _StandingsRow extends StatelessWidget {
  final int rank;
  final GroupStanding standing;
  const _StandingsRow({required this.rank, required this.standing});

  @override
  Widget build(BuildContext context) {
    final isPromo = rank <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
        color: isPromo ? AppTheme.primaryLight.withValues(alpha: 0.04) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank',
                style: TextStyle(
                  color: isPromo ? AppTheme.primaryLight : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isPromo ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          Expanded(
            child: Text(standing.teamName,
                style: TextStyle(
                  color: isPromo ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isPromo ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis),
          ),
          _cell('${standing.played}'),
          _cell('${standing.won}', color: AppTheme.supportGreen),
          _cell('${standing.drawn}'),
          _cell('${standing.lost}', color: AppTheme.red),
          _cell('${standing.goalDiff >= 0 ? '+' : ''}${standing.goalDiff}',
              color: standing.goalDiff >= 0 ? AppTheme.supportGreen : AppTheme.red,
              width: 36),
          SizedBox(
            width: 32,
            child: Text('${standing.points}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {Color? color, double width = 28}) => SizedBox(
        width: width,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color ?? AppTheme.textSecondary, fontSize: 12)),
      );
}

// ─── BRACKET TAB ─────────────────────────────────────────────────────────────

class _BracketTab extends StatelessWidget {
  final TournamentModel tournament;
  final List<TournamentMatch> matches;
  const _BracketTab({required this.tournament, required this.matches});

  @override
  Widget build(BuildContext context) {
    final knockoutMatches = matches
        .where((m) => m.phase == 'knockout')
        .toList()
      ..sort((a, b) {
        if (a.bracketRound != b.bracketRound) {
          return a.bracketRound.compareTo(b.bracketRound);
        }
        return a.bracketPosition.compareTo(b.bracketPosition);
      });

    if (knockoutMatches.isEmpty) {
      return const Center(
        child: Text('Δεν υπάρχει κλήρωση ακόμα', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final totalRounds = tournament.totalRounds;
    if (totalRounds == 0) {
      return const Center(
        child: Text('Δεν υπάρχει κλήρωση', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    const cardW = 150.0;
    const cardH = 64.0;
    const slotH = 100.0; // height per first-round slot
    const colGap = 48.0;

    final firstRoundCount = pow(2, totalRounds - 1).toInt();
    final totalH = firstRoundCount * slotH + 40; // +40 for round labels
    final totalW = totalRounds * cardW + (totalRounds - 1) * colGap + 32;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            children: [
              // Lines
              Positioned.fill(
                child: CustomPaint(
                  painter: _BracketPainter(
                    totalRounds: totalRounds,
                    slotH: slotH,
                    cardW: cardW,
                    colGap: colGap,
                    labelH: 40,
                  ),
                ),
              ),
              // Round labels
              ...List.generate(totalRounds, (round) {
                final x = round * (cardW + colGap);
                final label = _roundLabel(round, totalRounds);
                return Positioned(
                  left: x,
                  top: 0,
                  width: cardW,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }),
              // Match cards
              ...knockoutMatches.map((m) {
                final x = m.bracketRound * (cardW + colGap);
                final centerY = (m.bracketPosition + 0.5) *
                    slotH *
                    pow(2, m.bracketRound).toDouble() +
                    40;
                final y = centerY - cardH / 2;
                return Positioned(
                  left: x,
                  top: y,
                  width: cardW,
                  height: cardH,
                  child: _BracketMatchCard(match: m),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _roundLabel(int round, int totalRounds) {
    final fromFinal = totalRounds - round - 1;
    if (fromFinal == 0) return 'ΤΕΛΙΚΟΣ';
    if (fromFinal == 1) return 'ΗΜΙΤΕΛΙΚΑ';
    if (fromFinal == 2) return 'ΠΡΟΗΜΙΤΕΛΙΚΑ';
    return 'ΓΥΡΟΣ ${round + 1}';
  }
}

class _BracketPainter extends CustomPainter {
  final int totalRounds;
  final double slotH;
  final double cardW;
  final double colGap;
  final double labelH;

  const _BracketPainter({
    required this.totalRounds,
    required this.slotH,
    required this.cardW,
    required this.colGap,
    required this.labelH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var round = 1; round < totalRounds; round++) {
      final numMatches = pow(2, totalRounds - round - 1).toInt();
      final midX = round * (cardW + colGap) - colGap / 2;
      final prevColRightX = (round - 1) * (cardW + colGap) + cardW;
      final currColLeftX = round * (cardW + colGap);

      for (var pos = 0; pos < numMatches; pos++) {
        final parentCenterY = (pos + 0.5) *
            slotH *
            pow(2, round).toDouble() +
            labelH;
        final child1CenterY = (2 * pos + 0.5) *
            slotH *
            pow(2, round - 1).toDouble() +
            labelH;
        final child2CenterY = (2 * pos + 1.5) *
            slotH *
            pow(2, round - 1).toDouble() +
            labelH;

        // Horizontal from child1 right to midX
        canvas.drawLine(Offset(prevColRightX, child1CenterY),
            Offset(midX, child1CenterY), paint);
        // Horizontal from child2 right to midX
        canvas.drawLine(Offset(prevColRightX, child2CenterY),
            Offset(midX, child2CenterY), paint);
        // Vertical connector at midX
        canvas.drawLine(Offset(midX, child1CenterY),
            Offset(midX, child2CenterY), paint);
        // Horizontal from midX to parent left
        canvas.drawLine(Offset(midX, parentCenterY),
            Offset(currColLeftX, parentCenterY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.totalRounds != totalRounds;
}

class _BracketMatchCard extends StatelessWidget {
  final TournamentMatch match;
  const _BracketMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final isTbd = m.isTbd;
    final isFinished = m.isFinished;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isTbd ? AppTheme.cardBg2 : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFinished
              ? AppTheme.supportGreen.withValues(alpha: 0.5)
              : AppTheme.divider,
        ),
      ),
      child: isTbd
          ? const Center(
              child: Text('TBD', style: TextStyle(color: AppTheme.cardBg2, fontWeight: FontWeight.bold)),
            )
          : Column(
              children: [
                Expanded(
                  child: _BracketTeamRow(
                    name: m.homeTeamName,
                    score: isFinished ? m.homeScore : null,
                    isWinner: isFinished && m.homeScore > m.awayScore,
                  ),
                ),
                Container(height: 0.5, color: AppTheme.divider),
                Expanded(
                  child: _BracketTeamRow(
                    name: m.awayTeamName,
                    score: isFinished ? m.awayScore : null,
                    isWinner: isFinished && m.awayScore > m.homeScore,
                  ),
                ),
              ],
            ),
    );
  }
}

class _BracketTeamRow extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;
  const _BracketTeamRow({required this.name, this.score, this.isWinner = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isWinner ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (score != null)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isWinner
                      ? AppTheme.supportGreen.withValues(alpha: 0.2)
                      : AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text('$score',
                      style: TextStyle(
                        color: isWinner ? AppTheme.supportGreen : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ),
          ],
        ),
      );
}

// ─── INFO TAB ─────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final TournamentModel tournament;
  const _InfoTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (t.description != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(t.description!,
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],
        _infoRow('Φορμά', _formatLabel(t.format)),
        _infoRow('Σεζόν', t.season),
        _infoRow('Ομάδες', '${t.teams.length}'),
        if (t.hasGroups) _infoRow('Αριθμός ομίλων', '${t.groupCount}'),
        const SizedBox(height: 20),
        const Text('ΟΜΑΔΕΣ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...t.teams.map((team) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                    backgroundImage: safeNetworkImage(team.logoUrl),
                    child: safeNetworkImage(team.logoUrl) == null
                        ? Text(team.name[0],
                            style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 130,
                child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _formatLabel(String format) {
    switch (format) {
      case 'knockout': return 'Νοκ-Άουτ';
      case 'groups': return 'Φάση Ομίλων';
      case 'groups_knockout': return 'Όμιλοι + Νοκ-Άουτ';
      default: return format;
    }
  }
}
