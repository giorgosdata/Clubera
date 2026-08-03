class PrizeModel {
  final String id;
  final String title;
  final String emoji;
  final String type; // 'points' | 'physical' | 'digital' | 'nothing'
  final int pointsValue;
  final String description;
  final int weight;
  final String? photoUrl;       // physical: image of the prize
  final String? digitalContent; // digital: the actual code/link/voucher text
  final DateTime? redeemByDate; // optional expiry for redemption

  const PrizeModel({
    required this.id,
    required this.title,
    this.emoji = '🎁',
    this.type = 'points',
    this.pointsValue = 0,
    this.description = '',
    this.weight = 1,
    this.photoUrl,
    this.digitalContent,
    this.redeemByDate,
  });

  bool get isNothing  => type == 'nothing';
  bool get isPoints   => type == 'points';
  bool get isPhysical => type == 'physical';
  bool get isDigital  => type == 'digital';

  bool get isExpiredForRedeem =>
      redeemByDate != null && DateTime.now().isAfter(redeemByDate!);

  String get typeLabel {
    switch (type) {
      case 'points':   return 'Πόντοι';
      case 'physical': return 'Φυσικό Δώρο';
      case 'digital':  return 'Ψηφιακό';
      case 'nothing':  return 'Δοκίμασε Ξανά';
      default:         return type;
    }
  }

  factory PrizeModel.fromMap(Map<String, dynamic> m) => PrizeModel(
    id: m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: m['title'] ?? '',
    emoji: m['emoji'] ?? '🎁',
    type: m['type'] ?? 'points',
    pointsValue: (m['pointsValue'] as num?)?.toInt() ?? 0,
    description: m['description'] ?? '',
    weight: (m['weight'] as num?)?.toInt() ?? 1,
    photoUrl: m['photoUrl'],
    digitalContent: m['digitalContent'],
    redeemByDate: (m['redeemByDate'] as dynamic)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'type': type,
    'pointsValue': pointsValue,
    'description': description,
    'weight': weight,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (digitalContent != null) 'digitalContent': digitalContent,
    if (redeemByDate != null) 'redeemByDate': redeemByDate,
  };
}
