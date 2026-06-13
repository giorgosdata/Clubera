import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/match_model.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../matches/ui/match_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool _loading = false;

  List<ClubModel> _clubs = [];
  List<MatchModel> _matches = [];
  // Players are stored in subcollections; we'll search from club results

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() { _clubs = []; _matches = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      // Firestore doesn't support full-text search, so we use prefix range query
      final end = trimmed.substring(0, trimmed.length - 1) +
          String.fromCharCode(trimmed.codeUnitAt(trimmed.length - 1) + 1);

      final clubSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .orderBy('name')
          .startAt([trimmed])
          .endAt([end])
          .limit(10)
          .get();

      final matchSnap = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('homeClubName')
          .startAt([trimmed])
          .endAt([end])
          .limit(10)
          .get();

      final matchSnap2 = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('awayClubName')
          .startAt([trimmed])
          .endAt([end])
          .limit(10)
          .get();

      final clubs = clubSnap.docs
          .map((d) => ClubModel.fromMap(d.data(), d.id))
          .toList();

      final matchIds = <String>{};
      final matches = <MatchModel>[];
      for (final d in [...matchSnap.docs, ...matchSnap2.docs]) {
        if (matchIds.add(d.id)) {
          matches.add(MatchModel.fromMap(d.data(), d.id));
        }
      }
      matches.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

      if (mounted) setState(() { _clubs = clubs; _matches = matches; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _clubs.isNotEmpty || _matches.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Σωματεία, αγώνες...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
            filled: false,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() { _query = ''; _clubs = []; _matches = []; });
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() => _query = v);
            _search(v);
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? const _SearchEmptyState()
              : !hasResults
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: AppTheme.cardBg2),
                          const SizedBox(height: 12),
                          Text('Δεν βρέθηκαν αποτελέσματα για "$_query"',
                              style: const TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_clubs.isNotEmpty) ...[
                          const _SectionHeader('Σωματεία'),
                          ..._clubs.map((c) => _ClubResult(club: c)),
                        ],
                        if (_matches.isNotEmpty) ...[
                          if (_clubs.isNotEmpty) const SizedBox(height: 16),
                          const _SectionHeader('Αγώνες'),
                          ..._matches.map((m) => _MatchResult(match: m)),
                        ],
                      ],
                    ),
    );
  }
}

// ─── Result Tiles ─────────────────────────────────────────────────────────────

class _ClubResult extends StatelessWidget {
  final ClubModel club;
  const _ClubResult({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: AppTheme.cardBg2,
          backgroundImage: safeNetworkImage(club.logoUrl),
          child: safeNetworkImage(club.logoUrl) == null
              ? Text(club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              : null,
        ),
        title: Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(club.league.isNotEmpty ? club.league : club.city,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
        ),
      ),
    );
  }
}

class _MatchResult extends StatelessWidget {
  final MatchModel match;
  const _MatchResult({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isFinished = match.isFinished;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: isLive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.liveRed, borderRadius: BorderRadius.circular(6)),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
              )
            : Icon(
                isFinished ? Icons.sports_score : Icons.sports_soccer_outlined,
                color: isFinished ? AppTheme.textSecondary : AppTheme.primaryLight,
              ),
        title: Text(
          '${match.homeClubName} vs ${match.awayClubName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          isFinished || isLive
              ? '${match.homeScore} – ${match.awayScore}'
              : match.scheduledAt.toString().substring(0, 16),
          style: TextStyle(
            color: isLive ? AppTheme.liveRed : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id)),
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search, size: 64, color: AppTheme.cardBg2),
        SizedBox(height: 12),
        Text('Αναζήτησε σωματεία & αγώνες', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      ],
    ),
  );
}
