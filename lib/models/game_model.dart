class GameModel {
  final String id;
  final String title;
  final String description;
  final String type; // 'spin_wheel' | 'scratch_card' | 'daily_bonus' | 'trivia'
  final String emoji;
  final int minPoints;
  final int maxPoints;
  final int dailyLimit;
  final bool isActive;
  final DateTime createdAt;
  final String? clubId; // null = global (admin-only), non-null = club-specific

  const GameModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.emoji = '🎮',
    this.minPoints = 1,
    this.maxPoints = 100,
    this.dailyLimit = 1,
    this.isActive = true,
    required this.createdAt,
    this.clubId,
  });

  String get typeLabel {
    switch (type) {
      case 'spin_wheel':
        return 'Τυχερός Τροχός';
      case 'scratch_card':
        return 'Ξυστό';
      case 'daily_bonus':
        return 'Ημερήσιο Bonus';
      case 'trivia':
        return 'Trivia Quiz';
      default:
        return type;
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'spin_wheel':
        return '🎡';
      case 'scratch_card':
        return '🎫';
      case 'daily_bonus':
        return '🎁';
      case 'trivia':
        return '🧠';
      default:
        return emoji;
    }
  }

  factory GameModel.fromMap(Map<String, dynamic> m, String id) => GameModel(
    id: id,
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    type: m['type'] ?? 'spin_wheel',
    emoji: m['emoji'] ?? '🎮',
    minPoints: (m['minPoints'] as num?)?.toInt() ?? 1,
    maxPoints: (m['maxPoints'] as num?)?.toInt() ?? 100,
    dailyLimit: (m['dailyLimit'] as num?)?.toInt() ?? 1,
    isActive: m['isActive'] ?? true,
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    clubId: m['clubId'],
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'type': type,
    'emoji': emoji,
    'minPoints': minPoints,
    'maxPoints': maxPoints,
    'dailyLimit': dailyLimit,
    'isActive': isActive,
    'createdAt': createdAt,
    if (clubId != null) 'clubId': clubId,
  };
}
