class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'fan' | 'club' | 'admin'
  final String? photoUrl;
  final String? clubId;
  final int points;
  final int seasonScore;
  final int streak;
  final List<String> followedClubs;
  final double balance;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    this.clubId,
    this.points = 0,
    this.seasonScore = 0,
    this.streak = 0,
    this.followedClubs = const [],
    this.balance = 0.0,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> m, String uid) => UserModel(
    uid: uid,
    email: m['email'] ?? '',
    name: m['name'] ?? '',
    role: m['role'] ?? 'fan',
    photoUrl: m['photoUrl'],
    clubId: m['clubId'],
    points: (m['points'] as num?)?.toInt() ?? 0,
    seasonScore: (m['seasonScore'] as num?)?.toInt() ?? 0,
    streak: (m['streak'] as num?)?.toInt() ?? 0,
    followedClubs: List<String>.from(m['followedClubs'] ?? []),
    balance: (m['balance'] as num?)?.toDouble() ?? 0.0,
    createdAt: (m['createdAt'] as dynamic)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'role': role,
    'photoUrl': photoUrl,
    'clubId': clubId,
    'points': points,
    'seasonScore': seasonScore,
    'streak': streak,
    'followedClubs': followedClubs,
    'balance': balance,
    'createdAt': createdAt,
  };

  UserModel copyWith({
    String? name,
    String? role,
    String? photoUrl,
    String? clubId,
    int? points,
    int? seasonScore,
    int? streak,
    List<String>? followedClubs,
    double? balance,
  }) => UserModel(
    uid: uid,
    email: email,
    name: name ?? this.name,
    role: role ?? this.role,
    photoUrl: photoUrl ?? this.photoUrl,
    clubId: clubId ?? this.clubId,
    points: points ?? this.points,
    seasonScore: seasonScore ?? this.seasonScore,
    streak: streak ?? this.streak,
    followedClubs: followedClubs ?? this.followedClubs,
    balance: balance ?? this.balance,
    createdAt: createdAt,
  );
}
