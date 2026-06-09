import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: () async {
                try {
                  await _markAllRead(user.uid);
                } catch (_) {}
              },
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('Login required',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Σφάλμα: ${snap.error}',
                          style: const TextStyle(color: AppTheme.textSecondary)),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 64, color: AppTheme.cardBg2),
                        SizedBox(height: 12),
                        Text('No notifications yet',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final read = d['read'] as bool? ?? false;
                    final title = d['title'] as String? ?? '';
                    final body = d['body'] as String? ?? '';
                    final emoji = d['emoji'] as String? ?? '🔔';
                    final ts = (d['createdAt'] as Timestamp?)?.toDate();
                    return GestureDetector(
                      onTap: () => _markRead(docs[i].id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: read ? AppTheme.cardBg : AppTheme.cardBg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: read
                                ? AppTheme.divider
                                : AppTheme.primaryLight.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: read
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (body.isNotEmpty)
                                    Text(body,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                  if (ts != null)
                                    Text(
                                      DateFormat('d MMM HH:mm').format(ts),
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                            if (!read)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static Future<void> _markRead(String id) =>
      FirebaseFirestore.instance.collection('notifications').doc(id).update({
        'read': true,
      }).catchError((_) {});

  static Future<void> _markAllRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    const chunkSize = 450;
    for (int i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (i + chunkSize).clamp(0, snap.docs.length);
      for (final d in snap.docs.sublist(i, end)) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    }
  }
}
