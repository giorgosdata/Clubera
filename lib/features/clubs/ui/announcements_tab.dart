import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class AnnouncementsTab extends StatelessWidget {
  final String clubId;
  final bool canAdmin;
  final String authorName;
  const AnnouncementsTab({
    super.key,
    required this.clubId,
    this.canAdmin = false,
    this.authorName = 'Club Admin',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAdmin
          ? FloatingActionButton.small(
              heroTag: 'addAnnouncement',
              backgroundColor: AppTheme.primaryLight,
              onPressed: () => _showCreateSheet(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text(
                    'Δεν υπάρχουν ανακοινώσεις ακόμα',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }
          // Sort: pinned first, then by date (already sorted by date from query)
          final sorted = [...docs]..sort((a, b) {
            final aPin = (a.data() as Map)['pinned'] as bool? ?? false;
            final bPin = (b.data() as Map)['pinned'] as bool? ?? false;
            if (aPin == bPin) return 0;
            return aPin ? -1 : 1;
          });
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final doc = sorted[i];
              final d = doc.data() as Map<String, dynamic>;
              final pinned = d['pinned'] as bool? ?? false;
              final date = (d['createdAt'] as Timestamp?)?.toDate();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pinned
                      ? AppTheme.primaryLight.withValues(alpha: 0.06)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: pinned
                        ? AppTheme.primaryLight.withValues(alpha: 0.35)
                        : AppTheme.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pinned) ...[
                          const Icon(Icons.push_pin, size: 14, color: AppTheme.primaryLight),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            d['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (canAdmin)
                          PopupMenuButton<String>(
                            color: AppTheme.cardBg2,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            onSelected: (v) async {
                              if (v == 'delete') {
                                await doc.reference.delete();
                              } else if (v == 'pin') {
                                await doc.reference.update({'pinned': !pinned});
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(
                                  pinned ? 'Ξεκαρφίτσωσε' : 'Καρφίτσωσε',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Διαγραφή',
                                  style: TextStyle(color: AppTheme.red),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d['body'] ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            d['authorName'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('d MMM yyyy, HH:mm').format(date),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool pinned = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Νέα Ανακοίνωση',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Τίτλος',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardBg2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Κείμενο ανακοίνωσης',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardBg2,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: pinned,
                    onChanged: (v) => setSt(() => pinned = v ?? false),
                    activeColor: AppTheme.primaryLight,
                  ),
                  const Text(
                    'Καρφίτσωμένη ανακοίνωση',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                    await FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(clubId)
                        .collection('announcements')
                        .add({
                          'title': titleCtrl.text.trim(),
                          'body': bodyCtrl.text.trim(),
                          'pinned': pinned,
                          'authorName': authorName,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Δημοσίευση',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
