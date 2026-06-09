class DonationModel {
  final String id;
  final String userId;
  final String userName;
  final String clubId;
  final String clubName;
  final double amount;
  final String type; // 'donate' | 'support' | 'membership'
  final String? message;
  final DateTime createdAt;

  const DonationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.clubId,
    required this.clubName,
    required this.amount,
    required this.type,
    this.message,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case 'donate': return 'Donation';
      case 'support': return 'Support';
      case 'membership': return 'Membership';
      default: return type;
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'donate': return '❤️';
      case 'support': return '⚽';
      case 'membership': return '🌟';
      default: return '💙';
    }
  }

  factory DonationModel.fromMap(Map<String, dynamic> m, String id) => DonationModel(
    id: id,
    userId: m['userId'] ?? '',
    userName: m['userName'] ?? '',
    clubId: m['clubId'] ?? '',
    clubName: m['clubName'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
    type: m['type'] ?? 'donate',
    message: m['message'],
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'clubId': clubId,
    'clubName': clubName,
    'amount': amount,
    'type': type,
    'message': message,
    'createdAt': createdAt,
  };
}
