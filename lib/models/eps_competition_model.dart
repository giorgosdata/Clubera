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

class EpsScorer {
  final String name;
  final String team;
  final String? clubId;
  final int goals;
  final int? firstHalf;
  final int? secondHalf;

  const EpsScorer({
    required this.name,
    required this.team,
    this.clubId,
    required this.goals,
    this.firstHalf,
    this.secondHalf,
  });

  factory EpsScorer.fromMap(Map<String, dynamic> m) => EpsScorer(
        name: m['name'] as String? ?? '',
        team: m['team'] as String? ?? '',
        clubId: m['clubId'] as String?,
        goals: _int(m['goals']),
        firstHalf: _intOrNull(m['firstHalf']),
        secondHalf: _intOrNull(m['secondHalf']),
      );
}

/// Neutral season statistics computed from the played matches.
class EpsCompetitionStats {
  final int played;
  final int totalGoals;
  final int homeWins;
  final int draws;
  final int awayWins;
  final int homeGoals;
  final int awayGoals;
  final int threePlusGoals; // matches with 3 or more goals
  final int bothScored; // matches where both teams scored
  final int cleanSheets; // teams that conceded no goal in a match
  final EpsStanding? bestAttack;
  final EpsStanding? bestDefence;
  final EpsMatch? biggestWin;
  final EpsMatch? highestScoring;
  final String? mostCleanSheetsTeam;
  final String? mostCleanSheetsClubId;
  final int mostCleanSheets;

  const EpsCompetitionStats({
    required this.played,
    required this.totalGoals,
    required this.homeWins,
    required this.draws,
    required this.awayWins,
    this.homeGoals = 0,
    this.awayGoals = 0,
    this.threePlusGoals = 0,
    this.bothScored = 0,
    this.cleanSheets = 0,
    this.bestAttack,
    this.bestDefence,
    this.biggestWin,
    this.highestScoring,
    this.mostCleanSheetsTeam,
    this.mostCleanSheetsClubId,
    this.mostCleanSheets = 0,
  });

  int get upToTwoGoals => played - threePlusGoals;

  double get goalsPerMatch => played == 0 ? 0 : totalGoals / played;
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
  final List<EpsScorer> scorers;
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
    this.scorers = const [],
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
      scorers: ((m['scorers'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EpsScorer.fromMap(Map<String, dynamic>.from(e)))
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

  List<EpsScorer> scorersOf(String clubId, {int limit = 3}) =>
      scorers.where((s) => s.clubId == clubId).take(limit).toList();

  EpsCompetitionStats get stats {
    final done = matches.where((m) => m.isFinished).toList();
    var goals = 0, home = 0, draw = 0, away = 0;
    EpsMatch? biggest;
    var biggestDiff = -1;
    var biggestTotal = -1;
    var homeGoals = 0, awayGoals = 0, threePlus = 0, both = 0, clean = 0;
    EpsMatch? highest;
    final cleanByTeam = <String, int>{};
    final clubOfTeam = <String, String?>{};
    for (final m in done) {
      final h = m.homeScore!, a = m.awayScore!;
      goals += h + a;
      if (h > a) {
        home++;
      } else if (h < a) {
        away++;
      } else {
        draw++;
      }
      homeGoals += h;
      awayGoals += a;
      if (h + a >= 3) threePlus++;
      if (h > 0 && a > 0) both++;
      if (a == 0) {
        clean++;
        cleanByTeam[m.homeTeam] = (cleanByTeam[m.homeTeam] ?? 0) + 1;
        clubOfTeam[m.homeTeam] = m.homeClubId;
      }
      if (h == 0) {
        clean++;
        cleanByTeam[m.awayTeam] = (cleanByTeam[m.awayTeam] ?? 0) + 1;
        clubOfTeam[m.awayTeam] = m.awayClubId;
      }
      if (highest == null || h + a > highest.homeScore! + highest.awayScore!) {
        highest = m;
      }
      final diff = (h - a).abs();
      // Biggest margin; on a tie, the one with more goals.
      if (diff > 0 && (diff > biggestDiff || (diff == biggestDiff && h + a > biggestTotal))) {
        biggest = m;
        biggestDiff = diff;
        biggestTotal = h + a;
      }
    }
    final played = standings.where((s) => s.played > 0).toList();
    EpsStanding? attack, defence;
    for (final s in played) {
      if (attack == null || s.goalsFor > attack.goalsFor) attack = s;
      if (defence == null || s.goalsAgainst < defence.goalsAgainst) defence = s;
    }
    String? cleanTeam;
    var cleanMax = 0;
    cleanByTeam.forEach((team, n) {
      if (n > cleanMax) {
        cleanMax = n;
        cleanTeam = team;
      }
    });
    return EpsCompetitionStats(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      threePlusGoals: threePlus,
      bothScored: both,
      cleanSheets: clean,
      highestScoring: highest,
      mostCleanSheetsTeam: cleanTeam,
      mostCleanSheetsClubId: cleanTeam == null ? null : clubOfTeam[cleanTeam],
      mostCleanSheets: cleanMax,
      played: done.length,
      totalGoals: goals,
      homeWins: home,
      draws: draw,
      awayWins: away,
      bestAttack: attack,
      bestDefence: defence,
      biggestWin: biggest,
    );
  }
}
