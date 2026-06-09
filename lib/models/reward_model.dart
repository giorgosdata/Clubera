class RewardModel {
  final String id;
  final String title;
  final String description;
  final int pointsCost;
  final String emoji;
  final String? clubId;   // null = global (app-level) reward
  final String? clubName;
  final bool isActive;
  final bool topFansOnly;
  final DateTime createdAt;

  const RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    this.emoji = '🎁',
    this.clubId,
    this.clubName,
    this.isActive = true,
    this.topFansOnly = false,
    required this.createdAt,
  });

  bool get isGlobal => clubId == null;

  factory RewardModel.fromMap(Map<String, dynamic> m, String id) => RewardModel(
    id: id,
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    pointsCost: m['pointsCost'] ?? 0,
    emoji: m['emoji'] ?? '🎁',
    clubId: m['clubId'],
    clubName: m['clubName'],
    isActive: m['isActive'] ?? true,
    topFansOnly: m['topFansOnly'] ?? false,
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'pointsCost': pointsCost,
    'emoji': emoji,
    'clubId': clubId,
    'clubName': clubName,
    'isActive': isActive,
    'topFansOnly': topFansOnly,
    'createdAt': createdAt,
  };
}
