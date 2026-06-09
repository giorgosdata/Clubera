import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/news_model.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: article.imageUrl != null ? 240 : 100,
            backgroundColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: article.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(article.imageUrl!, fit: BoxFit.cover),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, AppTheme.surface],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: AppTheme.cardBg),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: article.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryLight.withOpacity(0.4)),
                        ),
                        child: Text(tag, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                      )).toList(),
                    ),
                  if (article.tags.isNotEmpty) const SizedBox(height: 14),
                  Text(article.title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: AppTheme.cardBg2, shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: AppTheme.textSecondary, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(article.author, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text(DateFormat('d MMMM yyyy').format(article.publishedAt),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppTheme.divider),
                  const SizedBox(height: 20),
                  Text(
                    article.body.isNotEmpty ? article.body : article.excerpt,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.7),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
