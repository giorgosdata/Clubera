class MatchModel {
  final String id;
  final String homeClubId;
  final String homeClubName;
  final String? homeClubLogo;
  final String awayClubId;
  final String awayClubName;
  final String? awayClubLogo;
  final int homeScore;
  final int awayScore;
  final String status; // 'upcoming' | 'live' | 'halftime' | 'finished'
  final String? minute;
  final DateTime scheduledAt;
  final String league;
  final String? venue;
  final String? homeFormation; // e.g. '4-3-3'
  final String? awayFormation;
  final List<Map<String, dynamic>> homeLineup; // [{name, number, position}]
  final List<Map<String, dynamic>> awayLineup;

  const MatchModel({
    required this.id,
    required this.homeClubId,
    required this.homeClubName,
    this.homeClubLogo,
    required this.awayClubId,
    required this.awayClubName,
    this.awayClubLogo,
    this.homeScore = 0,
    this.awayScore = 0,
    this.status = 'upcoming',
    this.minute,
    required this.scheduledAt,
    required this.league,
    this.venue,
    this.homeFormation,
    this.awayFormation,
    this.homeLineup = const [],
    this.awayLineup = const [],
  });

  bool get isLive => status == 'live' || status == 'halftime';
  bool get isFinished => status == 'finished';
  bool get isUpcoming => status == 'upcoming';

  factory MatchModel.fromMap(Map<String, dynamic> m, String id) => MatchModel(
    id: id,
    homeClubId: m['homeClubId'] ?? '',
    homeClubName: m['homeClubName'] ?? '',
    homeClubLogo: m['homeClubLogo'],
    awayClubId: m['awayClubId'] ?? '',
    awayClubName: m['awayClubName'] ?? '',
    awayClubLogo: m['awayClubLogo'],
    homeScore: m['homeScore'] ?? 0,
    awayScore: m['awayScore'] ?? 0,
    status: m['status'] ?? 'upcoming',
    minute: m['minute'],
    scheduledAt: (m['scheduledAt'] as dynamic)?.toDate() ?? DateTime.now(),
    league: m['league'] ?? '',
    venue: m['venue'],
    homeFormation: m['homeFormation'],
    awayFormation: m['awayFormation'],
    homeLineup: List<Map<String, dynamic>>.from(m['homeLineup'] ?? []),
    awayLineup: List<Map<String, dynamic>>.from(m['awayLineup'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'homeClubId': homeClubId,
    'homeClubName': homeClubName,
    'homeClubLogo': homeClubLogo,
    'awayClubId': awayClubId,
    'awayClubName': awayClubName,
    'awayClubLogo': awayClubLogo,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'status': status,
    'minute': minute,
    'scheduledAt': scheduledAt,
    'league': league,
    'venue': venue,
    'homeFormation': homeFormation,
    'awayFormation': awayFormation,
    'homeLineup': homeLineup,
    'awayLineup': awayLineup,
  };
}

class MatchEvent {
  final String id;
  // 'goal' | 'yellow_card' | 'red_card' | 'foul' | 'penalty' | 'offside' |
  // 'corner' | 'throw_in' | 'goal_cancelled' | 'substitution'
  final String type;
  final String clubId;
  final String playerName;
  final String? playerIn; // substitution only
  final String? reason; // goal_cancelled only
  final String minute;
  final DateTime createdAt;

  const MatchEvent({
    required this.id,
    required this.type,
    required this.clubId,
    required this.playerName,
    this.playerIn,
    this.reason,
    required this.minute,
    required this.createdAt,
  });

  factory MatchEvent.fromMap(Map<String, dynamic> m, String id) => MatchEvent(
    id: id,
    type: m['type'] ?? 'goal',
    clubId: m['clubId'] ?? '',
    playerName: m['playerName'] ?? '',
    playerIn: m['playerIn'],
    reason: m['reason'],
    minute: m['minute'] ?? '',
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'clubId': clubId,
    'playerName': playerName,
    if (playerIn != null) 'playerIn': playerIn,
    if (reason != null) 'reason': reason,
    'minute': minute,
    'createdAt': createdAt,
  };
}
