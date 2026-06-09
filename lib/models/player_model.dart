class PlayerModel {
  final String id;
  final String name;
  final String position; // 'GK' | 'DEF' | 'MID' | 'FWD'
  final int? number;
  final String? photoUrl;
  final int? age;
  final String? nationality;
  final bool isActive;
  // Career stats (aggregated by Cloud Functions from match events)
  final int goals;
  final int yellowCards;
  final int redCards;
  final int appearances;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.position,
    this.number,
    this.photoUrl,
    this.age,
    this.nationality,
    this.isActive = true,
    this.goals = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.appearances = 0,
  });

  String get positionLabel {
    switch (position) {
      case 'GK': return 'Goalkeeper';
      case 'DEF': return 'Defender';
      case 'MID': return 'Midfielder';
      case 'FWD': return 'Forward';
      default: return position;
    }
  }

  factory PlayerModel.fromMap(Map<String, dynamic> m, String id) => PlayerModel(
    id: id,
    name: m['name'] ?? '',
    position: m['position'] ?? 'MID',
    number: m['number'],
    photoUrl: m['photoUrl'],
    age: m['age'],
    nationality: m['nationality'],
    isActive: m['isActive'] ?? true,
    goals: (m['goals'] as num?)?.toInt() ?? 0,
    yellowCards: (m['yellowCards'] as num?)?.toInt() ?? 0,
    redCards: (m['redCards'] as num?)?.toInt() ?? 0,
    appearances: (m['appearances'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'position': position,
    'number': number,
    'photoUrl': photoUrl,
    'age': age,
    'nationality': nationality,
    'isActive': isActive,
    'goals': goals,
    'yellowCards': yellowCards,
    'redCards': redCards,
    'appearances': appearances,
  };
}
