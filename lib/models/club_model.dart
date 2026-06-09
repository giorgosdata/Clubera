const kCategories = [
  'Α΄ Ομάδα',
  'Β΄ Ομάδα',
  'Γυναικεία',
];

const kAcademyCategories = [
  'K19', 'K18', 'K17', 'K16', 'K15', 'K14',
];

class ClubModel {
  final String id;
  final String name;
  final String city;
  final String country;
  final String league;
  final String category;
  final String? logoUrl;
  final String? coverUrl;
  final String description;
  final String adminUid;
  final int followers;
  final int votes;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final DateTime createdAt;
  final String? inviteCode;
  final List<String> staffUids;

  const ClubModel({
    required this.id,
    required this.name,
    required this.city,
    this.country = 'Greece',
    required this.league,
    this.category = 'K14',
    this.logoUrl,
    this.coverUrl,
    this.description = '',
    required this.adminUid,
    this.followers = 0,
    this.votes = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    required this.createdAt,
    this.inviteCode,
    this.staffUids = const [],
  });

  int get played => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;

  factory ClubModel.fromMap(Map<String, dynamic> m, String id) => ClubModel(
    id: id,
    name: m['name'] ?? '',
    city: m['city'] ?? '',
    country: m['country'] ?? 'Greece',
    league: m['league'] ?? '',
    category: m['category'] is String ? m['category'] as String : 'K14',
    logoUrl: m['logoUrl'],
    coverUrl: m['coverUrl'],
    description: m['description'] ?? '',
    adminUid: m['adminUid'] ?? '',
    followers: (m['followers'] as num?)?.toInt() ?? 0,
    votes: (m['votes'] as num?)?.toInt() ?? 0,
    wins: (m['wins'] as num?)?.toInt() ?? 0,
    draws: (m['draws'] as num?)?.toInt() ?? 0,
    losses: (m['losses'] as num?)?.toInt() ?? 0,
    goalsFor: (m['goalsFor'] as num?)?.toInt() ?? 0,
    goalsAgainst: (m['goalsAgainst'] as num?)?.toInt() ?? 0,
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    inviteCode: m['inviteCode'],
    staffUids: List<String>.from(m['staffUids'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'city': city,
    'country': country,
    'league': league,
    'category': category,
    'logoUrl': logoUrl,
    'coverUrl': coverUrl,
    'description': description,
    'adminUid': adminUid,
    'followers': followers,
    'votes': votes,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'createdAt': createdAt,
    'inviteCode': inviteCode,
    'staffUids': staffUids,
  };
}

class TransferModel {
  final String id;
  final String playerName;
  final String type; // 'in' | 'out'
  final String? fromClub;
  final String? toClub;
  final DateTime date;

  const TransferModel({
    required this.id,
    required this.playerName,
    required this.type,
    this.fromClub,
    this.toClub,
    required this.date,
  });

  factory TransferModel.fromMap(Map<String, dynamic> m, String id) => TransferModel(
    id: id,
    playerName: m['playerName'] ?? '',
    type: m['type'] ?? 'in',
    fromClub: m['fromClub'],
    toClub: m['toClub'],
    date: (m['date'] as dynamic)?.toDate() ?? DateTime.now(),
  );
}
