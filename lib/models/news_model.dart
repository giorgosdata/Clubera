class NewsModel {
  final String id;
  final String title;
  final String excerpt;
  final String body;
  final String? imageUrl;
  final String author;
  final DateTime publishedAt;
  final String? clubId; // null = general news
  final List<String> tags;

  const NewsModel({
    required this.id,
    required this.title,
    required this.excerpt,
    this.body = '',
    this.imageUrl,
    required this.author,
    required this.publishedAt,
    this.clubId,
    this.tags = const [],
  });

  factory NewsModel.fromMap(Map<String, dynamic> m, String id) => NewsModel(
    id: id,
    title: m['title'] ?? '',
    excerpt: m['excerpt'] ?? '',
    body: m['body'] ?? '',
    imageUrl: m['imageUrl'],
    author: m['author'] ?? 'Clubera',
    publishedAt: (m['publishedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    clubId: m['clubId'],
    tags: List<String>.from(m['tags'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'excerpt': excerpt,
    'body': body,
    'imageUrl': imageUrl,
    'author': author,
    'publishedAt': publishedAt,
    'clubId': clubId,
    'tags': tags,
  };
}
