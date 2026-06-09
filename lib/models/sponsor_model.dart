class SponsorModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? website;
  final String tier; // 'platinum' | 'gold' | 'silver' | 'bronze'
  final String? clubId; // null = global/app sponsor
  final String? pdfUrl;
  final String? pdfName;
  final bool isActive;

  const SponsorModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.website,
    this.tier = 'bronze',
    this.clubId,
    this.pdfUrl,
    this.pdfName,
    this.isActive = true,
  });

  factory SponsorModel.fromMap(Map<String, dynamic> m, String id) =>
      SponsorModel(
        id: id,
        name: m['name'] ?? '',
        logoUrl: m['logoUrl'],
        website: m['website'],
        tier: m['tier'] ?? 'bronze',
        clubId: m['clubId'],
        pdfUrl: m['pdfUrl'],
        pdfName: m['pdfName'],
        isActive: m['isActive'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'logoUrl': logoUrl,
        'website': website,
        'tier': tier,
        'clubId': clubId,
        'pdfUrl': pdfUrl,
        'pdfName': pdfName,
        'isActive': isActive,
      };
}
