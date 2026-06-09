class AcademyModel {
  final String id;
  final String name;
  final String category; // K14–K19
  final DateTime createdAt;

  const AcademyModel({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
  });

  factory AcademyModel.fromMap(Map<String, dynamic> m, String id) => AcademyModel(
    id: id,
    name: m['name'] ?? '',
    category: m['category'] ?? 'K14',
    createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'createdAt': createdAt,
  };
}
