// Unified scoring: 10 pts for exact score, 5 pts for correct outcome only.
const int kPredictExactPoints = 10;
const int kPredictOutcomePoints = 5;

class CouponPick {
  final String id;
  final String userId;
  final String matchId;
  final String homeClubName;
  final String awayClubName;
  final String pick; // '1' = home win, 'X' = draw, '2' = away win
  final int? predictedHomeScore; // optional exact score
  final int? predictedAwayScore;
  final bool? resolved;
  final int? pointsEarned;
  final DateTime createdAt;

  const CouponPick({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.homeClubName,
    required this.awayClubName,
    required this.pick,
    this.predictedHomeScore,
    this.predictedAwayScore,
    this.resolved,
    this.pointsEarned,
    required this.createdAt,
  });

  bool get isPending => resolved != true;
  bool get hasExactPrediction =>
      predictedHomeScore != null && predictedAwayScore != null;

  /// Unified: exact score = 10 pts, correct outcome only = 5 pts.
  static int calculatePoints(
    String pick,
    int homeScore,
    int awayScore, {
    int? predictedHomeScore,
    int? predictedAwayScore,
  }) {
    if (predictedHomeScore != null && predictedAwayScore != null) {
      if (predictedHomeScore == homeScore && predictedAwayScore == awayScore) {
        return kPredictExactPoints;
      }
    }
    final outcome = homeScore > awayScore
        ? '1'
        : homeScore < awayScore
            ? '2'
            : 'X';
    return pick == outcome ? kPredictOutcomePoints : 0;
  }

  factory CouponPick.fromMap(Map<String, dynamic> m, String id) => CouponPick(
    id: id,
    userId: m['userId'] ?? '',
    matchId: m['matchId'] ?? '',
    homeClubName: m['homeClubName'] ?? '',
    awayClubName: m['awayClubName'] ?? '',
    pick: m['pick'] ?? '1',
    predictedHomeScore: m['predictedHomeScore'],
    predictedAwayScore: m['predictedAwayScore'],
    resolved: m['resolved'],
    pointsEarned: m['pointsEarned'],
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'matchId': matchId,
    'homeClubName': homeClubName,
    'awayClubName': awayClubName,
    'pick': pick,
    'predictedHomeScore': predictedHomeScore,
    'predictedAwayScore': predictedAwayScore,
    'resolved': resolved,
    'pointsEarned': pointsEarned,
    'createdAt': createdAt,
  };
}

class ScorePrediction {
  final String id;
  final String userId;
  final String matchId;
  final int homeScore;
  final int awayScore;
  final int? pointsEarned; // null until match finishes
  final DateTime createdAt;

  const ScorePrediction({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    this.pointsEarned,
    required this.createdAt,
  });

  bool get isPending => pointsEarned == null;

  /// Unified: exact score = 10 pts, correct outcome only = 5 pts.
  static int calculatePoints(int pH, int pA, int rH, int rA) {
    if (pH == rH && pA == rA) return kPredictExactPoints;
    final pw = pH > pA
        ? '1'
        : pH < pA
            ? '2'
            : 'X';
    final rw = rH > rA
        ? '1'
        : rH < rA
            ? '2'
            : 'X';
    return pw == rw ? kPredictOutcomePoints : 0;
  }

  factory ScorePrediction.fromMap(Map<String, dynamic> m, String id) =>
      ScorePrediction(
        id: id,
        userId: m['userId'] ?? '',
        matchId: m['matchId'] ?? '',
        homeScore: m['homeScore'] ?? 0,
        awayScore: m['awayScore'] ?? 0,
        pointsEarned: m['pointsEarned'],
        createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'matchId': matchId,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'pointsEarned': pointsEarned,
        'createdAt': createdAt,
      };
}
