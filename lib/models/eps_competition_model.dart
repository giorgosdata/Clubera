// Championships, standings and matches read automatically from ΕΠΣ websites
// by tools/eps-sync (GitHub Actions) and stored in Firestore:
//   eps_associations/{assocId}     light list of an ΕΠΣ's championships
//   eps_competitions/{id}          one championship: standings + all matches

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(dynamic v) => v is num ? v.toInt() : (v == null ? null : int.tryParse('$v'));

/// One championship in the list of an ΕΠΣ (eps_associations.competitions).
class EpsCompetitionEntry {
  final String id;
  final String name;
  final String? season;
  final String level; // 'senior' | 'youth'
  final String? ageGroup; // 'K17' ...
  final String gender; // 'men' | 'women'
  final int teams;
  final int rounds;

  const EpsCompetitionEntry({
    required this.id,
    required this.name,
    this.season,
    required this.level,
    this.ageGroup,
    required this.gender,
    required this.teams,
    required this.rounds,
  });

  bool get isYouth => level == 'youth';
  bool get isWomen => gender == 'women';

  factory EpsCompetitionEntry.fromMap(Map<String, dynamic> m) => EpsCompetitionEntry(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        season: m['season'] as String?,
        level: m['level'] as String? ?? 'senior',
        ageGroup: m['ageGroup'] as String?,
        gender: m['gender'] as String? ?? 'men',
        teams: _int(m['teams']),
        rounds: _int(m['rounds']),
      );
}

class EpsStanding {
  final int position;
  final String team;
  final String? clubId;
  final int points;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final String? zone; // e.g. 'ΠΛΕΪ-ΟΦ'
  final String form; // e.g. 'ΝΝΗΙΝ'

  const EpsStanding({
    required this.position,
    required this.team,
    this.clubId,
    required this.points,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    this.zone,
    this.form = '',
  });

  int get goalDiff => goalsFor - goalsAgainst;

  factory EpsStanding.fromMap(Map<String, dynamic> m) => EpsStanding(
        position: _int(m['position']),
        team: m['team'] as String? ?? '',
        clubId: m['clubId'] as String?,
        points: _int(m['points']),
        played: _int(m['played']),
        won: _int(m['won']),
        drawn: _int(m['drawn']),
        lost: _int(m['lost']),
        goalsFor: _int(m['goalsFor']),
        goalsAgainst: _int(m['goalsAgainst']),
        zone: m['zone'] as String?,
        form: m['form'] as String? ?? '',
      );
}

class EpsMatch {
  final String? id;
  final int? round;
  final String homeTeam;
  final String awayTeam;
  final String? homeClubId;
  final String? awayClubId;
  final int? homeScore;
  final int? awayScore;
  final String status; // 'finished' | 'upcoming'
  final String? note;
  final DateTime? scheduledAt; // local time
  final bool hasTime;
  final String? venue;

  const EpsMatch({
    this.id,
    this.round,
    required this.homeTeam,
    required this.awayTeam,
    this.homeClubId,
    this.awayClubId,
    this.homeScore,
    this.awayScore,
    required this.status,
    this.note,
    this.scheduledAt,
    this.hasTime = false,
    this.venue,
  });

  bool get isFinished => status == 'finished' && homeScore != null && awayScore != null;

  bool involves(String clubId) => homeClubId == clubId || awayClubId == clubId;

  factory EpsMatch.fromMap(Map<String, dynamic> m) {
    final raw = m['scheduledAt'];
    return EpsMatch(
      id: m['id'] as String?,
      round: _intOrNull(m['round']),
      homeTeam: m['homeTeam'] as String? ?? '',
      awayTeam: m['awayTeam'] as String? ?? '',
      homeClubId: m['homeClubId'] as String?,
      awayClubId: m['awayClubId'] as String?,
      homeScore: _intOrNull(m['homeScore']),
      awayScore: _intOrNull(m['awayScore']),
      status: m['status'] as String? ?? 'upcoming',
      note: m['note'] as String?,
      scheduledAt: raw is String ? DateTime.tryParse(raw)?.toLocal() : null,
      hasTime: m['hasTime'] == true,
      venue: m['venue'] as String?,
    );
  }
}

class EpsCompetition {
  final String id;
  final String assocId;
  final String assocName;
  final String name;
  final String? season;
  final String level;
  final String? ageGroup;
  final String gender;
  final String? sourceUrl;
  final List<EpsStanding> standings;
  final List<EpsMatch> matches;
  final List<String> clubIds;
  final DateTime? updatedAt;

  const EpsCompetition({
    required this.id,
    required this.assocId,
    required this.assocName,
    required this.name,
    this.season,
    required this.level,
    this.ageGroup,
    required this.gender,
    this.sourceUrl,
    required this.standings,
    required this.matches,
    required this.clubIds,
    this.updatedAt,
  });

  factory EpsCompetition.fromMap(Map<String, dynamic> m, String id) {
    final updated = m['updatedAt'];
    return EpsCompetition(
      id: id,
      assocId: m['assocId'] as String? ?? '',
      assocName: m['assocName'] as String? ?? '',
      name: m['name'] as String? ?? '',
      season: m['season'] as String?,
      level: m['level'] as String? ?? 'senior',
      ageGroup: m['ageGroup'] as String?,
      gender: m['gender'] as String? ?? 'men',
      sourceUrl: m['sourceUrl'] as String?,
      standings: ((m['standings'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EpsStanding.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      matches: ((m['matches'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EpsMatch.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      clubIds: List<String>.from((m['clubIds'] as List?) ?? const []),
      updatedAt: (updated as dynamic)?.toDate() as DateTime?,
    );
  }

  /// Sorted round numbers present in the fixtures.
  List<int> get rounds {
    final s = matches.map((m) => m.round).whereType<int>().toSet().toList()..sort();
    return s;
  }

  /// The round to open first: the earliest round that still has an
  /// unplayed match, or the last round if the season is over.
  int? get currentRound {
    final r = rounds;
    if (r.isEmpty) return null;
    for (final n in r) {
      if (matches.any((m) => m.round == n && !m.isFinished)) return n;
    }
    return r.last;
  }

  List<EpsMatch> matchesOfRound(int round) {
    final list = matches.where((m) => m.round == round).toList();
    list.sort((a, b) {
      final da = a.scheduledAt, db = b.scheduledAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  List<EpsMatch> matchesOf(String clubId) => matches.where((m) => m.involves(clubId)).toList();

  /// Next unplayed match of the club (dated ones first, by date).
  EpsMatch? nextMatchOf(String clubId) {
    final list = matchesOf(clubId).where((m) => !m.isFinished).toList()
      ..sort((a, b) {
        final ra = a.round ?? 999, rb = b.round ?? 999;
        if (ra != rb) return ra.compareTo(rb);
        final da = a.scheduledAt, db = b.scheduledAt;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    return list.isEmpty ? null : list.first;
  }

  /// Most recent results of the club, newest first.
  List<EpsMatch> lastResultsOf(String clubId, {int limit = 3}) {
    final list = matchesOf(clubId).where((m) => m.isFinished).toList()
      ..sort((a, b) => (b.round ?? 0).compareTo(a.round ?? 0));
    return list.take(limit).toList();
  }

  EpsStanding? standingOf(String clubId) {
    for (final s in standings) {
      if (s.clubId == clubId) return s;
    }
    return null;
  }
}
