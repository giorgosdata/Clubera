import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentModel {
  final String id;
  final String name;
  final String? description;
  final String season;
  final String format; // 'knockout' | 'groups' | 'groups_knockout'
  final String status; // 'setup' | 'groups' | 'knockout' | 'finished'
  final String createdBy;
  final String? createdByClubId;
  final List<TournamentTeam> teams;
  final int groupCount;
  final int totalRounds; // knockout rounds (e.g. 3 = QF+SF+F for 8 teams)
  final DateTime createdAt;

  const TournamentModel({
    required this.id,
    required this.name,
    this.description,
    required this.season,
    required this.format,
    required this.status,
    required this.createdBy,
    this.createdByClubId,
    required this.teams,
    required this.groupCount,
    required this.totalRounds,
    required this.createdAt,
  });

  bool get hasGroups => format == 'groups' || format == 'groups_knockout';
  bool get hasKnockout => format == 'knockout' || format == 'groups_knockout';
  bool get isSetup => status == 'setup';

  factory TournamentModel.fromMap(Map<String, dynamic> m, String id) =>
      TournamentModel(
        id: id,
        name: m['name'] ?? '',
        description: m['description'],
        season: m['season'] ?? '',
        format: m['format'] ?? 'knockout',
        status: m['status'] ?? 'setup',
        createdBy: m['createdBy'] ?? '',
        createdByClubId: m['createdByClubId'],
        teams: ((m['teams'] as List?) ?? [])
            .map((t) => TournamentTeam.fromMap(Map<String, dynamic>.from(t)))
            .toList(),
        groupCount: (m['groupCount'] as num?)?.toInt() ?? 2,
        totalRounds: (m['totalRounds'] as num?)?.toInt() ?? 3,
        createdAt:
            (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'season': season,
        'format': format,
        'status': status,
        'createdBy': createdBy,
        'createdByClubId': createdByClubId,
        'teams': teams.map((t) => t.toMap()).toList(),
        'groupCount': groupCount,
        'totalRounds': totalRounds,
        'createdAt': createdAt,
      };
}

class TournamentTeam {
  final String id;
  final String name;
  final String? logoUrl;

  const TournamentTeam({required this.id, required this.name, this.logoUrl});

  factory TournamentTeam.fromMap(Map<String, dynamic> m) => TournamentTeam(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        logoUrl: m['logoUrl'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
      };
}

class TournamentMatch {
  final String id;
  final String phase; // 'group' | 'knockout'
  final String? groupName;
  final int bracketRound; // 0 = first knockout round; -1 for group matches
  final int bracketPosition; // 0-indexed within round
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final int homeScore;
  final int awayScore;
  final String status; // 'scheduled' | 'finished' | 'tbd'
  final String? winnerId;
  final String? winnerName;

  const TournamentMatch({
    required this.id,
    required this.phase,
    this.groupName,
    required this.bracketRound,
    required this.bracketPosition,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    this.homeScore = 0,
    this.awayScore = 0,
    required this.status,
    this.winnerId,
    this.winnerName,
  });

  bool get isFinished => status == 'finished';
  bool get isTbd => status == 'tbd';
  bool get isScheduled => status == 'scheduled';

  factory TournamentMatch.fromMap(Map<String, dynamic> m, String id) =>
      TournamentMatch(
        id: id,
        phase: m['phase'] ?? 'group',
        groupName: m['groupName'],
        bracketRound: (m['bracketRound'] as num?)?.toInt() ?? -1,
        bracketPosition: (m['bracketPosition'] as num?)?.toInt() ?? 0,
        homeTeamId: m['homeTeamId'] ?? '',
        homeTeamName: m['homeTeamName'] ?? '',
        awayTeamId: m['awayTeamId'] ?? '',
        awayTeamName: m['awayTeamName'] ?? '',
        homeScore: (m['homeScore'] as num?)?.toInt() ?? 0,
        awayScore: (m['awayScore'] as num?)?.toInt() ?? 0,
        status: m['status'] ?? 'scheduled',
        winnerId: m['winnerId'],
        winnerName: m['winnerName'],
      );

  Map<String, dynamic> toMap() => {
        'phase': phase,
        'groupName': groupName,
        'bracketRound': bracketRound,
        'bracketPosition': bracketPosition,
        'homeTeamId': homeTeamId,
        'homeTeamName': homeTeamName,
        'awayTeamId': awayTeamId,
        'awayTeamName': awayTeamName,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': status,
        'winnerId': winnerId,
        'winnerName': winnerName,
      };
}

class GroupStanding {
  final String teamId;
  final String teamName;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;

  GroupStanding({
    required this.teamId,
    required this.teamName,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get goalDiff => goalsFor - goalsAgainst;
  int get points => won * 3 + drawn;

  static List<GroupStanding> compute(
      String groupName, List<TournamentMatch> matches) {
    final map = <String, GroupStanding>{};
    for (final m in matches) {
      if (m.phase != 'group' || m.groupName != groupName || !m.isFinished) {
        continue;
      }
      map.putIfAbsent(m.homeTeamId,
          () => GroupStanding(teamId: m.homeTeamId, teamName: m.homeTeamName));
      map.putIfAbsent(m.awayTeamId,
          () => GroupStanding(teamId: m.awayTeamId, teamName: m.awayTeamName));
      final h = map[m.homeTeamId]!;
      final a = map[m.awayTeamId]!;
      h.played++;
      a.played++;
      h.goalsFor += m.homeScore;
      h.goalsAgainst += m.awayScore;
      a.goalsFor += m.awayScore;
      a.goalsAgainst += m.homeScore;
      if (m.homeScore > m.awayScore) {
        h.won++;
        a.lost++;
      } else if (m.homeScore < m.awayScore) {
        a.won++;
        h.lost++;
      } else {
        h.drawn++;
        a.drawn++;
      }
    }
    return map.values.toList()
      ..sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.goalDiff != a.goalDiff) return b.goalDiff.compareTo(a.goalDiff);
        return b.goalsFor.compareTo(a.goalsFor);
      });
  }
}
