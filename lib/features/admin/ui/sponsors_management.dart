import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../models/sponsor_model.dart';

const _kTiers = ['platinum', 'gold', 'silver', 'bronze'];

/// Lists sponsors filtered by [clubId]. When [clubId] is null and
/// [showOnlyGlobal] is true, only app-wide (clubId == null) sponsors show.
/// When [clubId] is set, only that club's sponsors show.
/// When both [clubId] and [showOnlyGlobal] are null/false, all club sponsors
/// (any clubId != null) show — used by admin for the "club sponsors" section.
class SponsorsList extends StatelessWidget {
  final String? clubId;
  final bool showOnlyGlobal;
  final bool showOnlyClubScoped;
  const SponsorsList({
    super.key,
    this.clubId,
    this.showOnlyGlobal = false,
    this.showOnlyClubScoped = false,
  });

  Query<Map<String, dynamic>> _query() {
    final col = FirebaseFirestore.instance.collection('sponsors');
    if (clubId != null) {
      return col.where('clubId', isEqualTo: clubId);
    }
    if (showOnlyGlobal) {
      return col.where('clubId', isNull: true);
    }
    return col; // showOnlyClubScoped: filter client-side below
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Σφάλμα: ${snap.error}',
                style: const TextStyle(color: AppTheme.textSecondary)),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        var sponsors = (snap.data?.docs ?? [])
            .map((d) => SponsorModel.fromMap(d.data(), d.id))
            .toList();
        if (showOnlyClubScoped) {
          sponsors = sponsors.where((s) => s.clubId != null).toList();
        }
        if (sponsors.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No sponsors yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sponsors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _SponsorTile(sponsor: sponsors[i]),
        );
      },
    );
  }
}

class _SponsorTile extends StatelessWidget {
  final SponsorModel sponsor;
  const _SponsorTile({required this.sponsor});

  Future<void> _openPdf(BuildContext context) async {
    final url = sponsor.pdfUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete sponsor?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove ${sponsor.name}?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('sponsors')
        .doc(sponsor.id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(sponsor.tier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tierColor.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.handshake, color: tierColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sponsor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sponsor.tier.toUpperCase(),
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (sponsor.pdfUrl != null)
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf,
                              color: AppTheme.accent, size: 12),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              sponsor.pdfName ?? 'contract.pdf',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (sponsor.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppTheme.accent),
              tooltip: 'Open PDF',
              onPressed: () => _openPdf(context),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.red),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'platinum':
        return Colors.cyan;
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      case 'bronze':
      default:
        return Colors.brown;
    }
  }
}

/// Bottom-sheet form to add a sponsor.
/// If [forcedClubId] is provided, the sponsor is locked to that club.
/// If [allowClubPicker] is true and forcedClubId is null, the user can pick a
/// club (or leave null for app-wide). If both are null/false, the sponsor is
/// app-wide (clubId stays null).
Future<void> showAddSponsorSheet(
  BuildContext context, {
  String? forcedClubId,
  bool allowClubPicker = false,
}) async {
  final nameCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  String tier = 'bronze';
  PickedPdf? pickedPdf;
  bool saving = false;
  String? selectedClubId = forcedClubId;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> handlePickPdf() async {
          try {
            final picked = await StorageUtils.pickPdf();
            if (picked != null) setS(() => pickedPdf = picked);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }
        }

        Future<void> handleSave() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Enter sponsor name')),
            );
            return;
          }
          setS(() => saving = true);
          try {
            final docRef =
                FirebaseFirestore.instance.collection('sponsors').doc();
            String? pdfUrl;
            String? pdfName;
            if (pickedPdf != null) {
              pdfUrl = await StorageUtils.uploadSponsorPdf(
                file: pickedPdf!.file,
                sponsorId: docRef.id,
                fileName: pickedPdf!.name,
              );
              pdfName = pickedPdf!.name;
            }
            await docRef.set({
              'name': name,
              'website': websiteCtrl.text.trim().isEmpty
                  ? null
                  : websiteCtrl.text.trim(),
              'tier': tier,
              'clubId': selectedClubId,
              'pdfUrl': pdfUrl,
              'pdfName': pdfName,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Failed: $e')),
              );
              setS(() => saving = false);
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Sponsor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Sponsor name',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: websiteCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tier',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _kTiers
                      .map((t) => ChoiceChip(
                            label: Text(t),
                            selected: tier == t,
                            selectedColor: AppTheme.primaryLight,
                            labelStyle: TextStyle(
                              color: tier == t
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: tier == t
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) => setS(() => tier = t),
                          ))
                      .toList(),
                ),
                if (allowClubPicker && forcedClubId == null) ...[
                  const SizedBox(height: 16),
                  _ClubPickerDropdown(
                    selectedClubId: selectedClubId,
                    onChanged: (v) => setS(() => selectedClubId = v),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pickedPdf != null
                            ? Icons.picture_as_pdf
                            : Icons.upload_file,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pickedPdf?.name ?? 'No PDF selected',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: handlePickPdf,
                        child: Text(pickedPdf == null ? 'Pick PDF' : 'Change'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.supportGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Save Sponsor',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  nameCtrl.dispose();
  websiteCtrl.dispose();
}

class _ClubPickerDropdown extends StatelessWidget {
  final String? selectedClubId;
  final ValueChanged<String?> onChanged;
  const _ClubPickerDropdown({
    required this.selectedClubId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('clubs').orderBy('name').snapshots(),
      builder: (ctx, snap) {
        final clubs = snap.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: DropdownButton<String?>(
            value: selectedClubId,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppTheme.cardBg,
            hint: const Text(
              'App-wide (no club)',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'App-wide (no club)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ...clubs.map((d) => DropdownMenuItem<String?>(
                    value: d.id,
                    child: Text(
                      d.data()['name']?.toString() ?? d.id,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )),
            ],
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}
