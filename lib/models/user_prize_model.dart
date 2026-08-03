class UserPrizeModel {
  final String id;
  final String userId;
  final String gameId;
  final String gameTitle;
  final String gameType;
  final String prizeTitle;
  final String prizeEmoji;
  final String prizeType; // 'points' | 'physical' | 'digital'
  final int pointsValue;
  final String description;
  final String? clubId;
  final String? clubName;
  final DateTime wonAt;
  final DateTime? redeemedAt;
  final String status; // 'pending' | 'redeemed'
  final String? photoUrl;       // physical: image of the prize
  final String? digitalContent; // digital: the actual code/link/voucher
  final DateTime? redeemByDate; // optional expiry for redemption

  const UserPrizeModel({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.gameTitle,
    required this.gameType,
    required this.prizeTitle,
    required this.prizeEmoji,
    required this.prizeType,
    this.pointsValue = 0,
    this.description = '',
    this.clubId,
    this.clubName,
    required this.wonAt,
    this.redeemedAt,
    this.status = 'pending',
    this.photoUrl,
    this.digitalContent,
    this.redeemByDate,
  });

  bool get isRedeemed => status == 'redeemed';
  bool get isPending  => status == 'pending';
  bool get isExpiredForRedeem =>
      redeemByDate != null && DateTime.now().isAfter(redeemByDate!);

  factory UserPrizeModel.fromMap(Map<String, dynamic> m, String id) => UserPrizeModel(
    id: id,
    userId: m['userId'] ?? '',
    gameId: m['gameId'] ?? '',
    gameTitle: m['gameTitle'] ?? '',
    gameType: m['gameType'] ?? '',
    prizeTitle: m['prizeTitle'] ?? '',
    prizeEmoji: m['prizeEmoji'] ?? '🎁',
    prizeType: m['prizeType'] ?? 'physical',
    pointsValue: (m['pointsValue'] as num?)?.toInt() ?? 0,
    description: m['description'] ?? '',
    clubId: m['clubId'],
    clubName: m['clubName'],
    wonAt: (m['wonAt'] as dynamic)?.toDate() ?? DateTime.now(),
    redeemedAt: (m['redeemedAt'] as dynamic)?.toDate(),
    status: m['status'] ?? 'pending',
    photoUrl: m['photoUrl'],
    digitalContent: m['digitalContent'],
    redeemByDate: (m['redeemByDate'] as dynamic)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'gameId': gameId,
    'gameTitle': gameTitle,
    'gameType': gameType,
    'prizeTitle': prizeTitle,
    'prizeEmoji': prizeEmoji,
    'prizeType': prizeType,
    'pointsValue': pointsValue,
    'description': description,
    if (clubId != null) 'clubId': clubId,
    if (clubName != null) 'clubName': clubName,
    'wonAt': wonAt,
    'status': status,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (digitalContent != null) 'digitalContent': digitalContent,
    if (redeemByDate != null) 'redeemByDate': redeemByDate,
  };
}
