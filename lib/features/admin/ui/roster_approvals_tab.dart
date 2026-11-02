// Super Admin: the latest roster and logo uploads by clubs.
//
// Club Admins are verified once, when the club is claimed, so their uploads
// are published at once; this tab is the record of who uploaded what and
// when. Uploads left "pending" by the earlier approval flow can still be
// reviewed here.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../club_admin/roster/roster_service.dart';

class RosterApprovalsTab extends StatelessWidget {
  const RosterApprovalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .orderBy('rosterUpload.at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Σφάλμα: ${snap.error}', style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt, size: 56, color: AppTheme.cardBg2),
                SizedBox(height: 10),
                Text('Κανένα ανέβασμα ρόστερ ακόμα', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PendingClubCard(clubId: docs[i].id, club: docs[i].data()),
        );
      },
    );
  }
}

class _PendingClubCard extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> club;
  const _PendingClubCard({required this.clubId, required this.club});

  @override
  Widget build(BuildContext context) {
    final upload = (club['rosterUpload'] as Map?) ?? const {};
    final at = upload['at'] is Timestamp ? (upload['at'] as Timestamp).toDate() : null;
    final pending = club['rosterStatus'] == 'pending';
    final undone = club['rosterStatus'] == 'undone';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: pending
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RosterReviewScreen(clubId: clubId)),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: (pending
                      ? AppTheme.accent
                      : undone
                          ? AppTheme.textSecondary
                          : AppTheme.supportGreen)
                  .withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            _Logo(url: (club['pendingLogoUrl'] ?? club['logoUrl']) as String?, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${club['name'] ?? clubId}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${upload['newCount'] ?? 0} νέοι · ${upload['updateCount'] ?? 0} αλλαγές'
                    '${(upload['removeCount'] ?? 0) > 0 ? ' · ${upload['removeCount']} αποχωρήσεις' : ''}'
                    '${club['pendingLogoUrl'] != null ? ' · λογότυπο' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    'Από ${upload['byName'] ?? '—'}${at == null ? '' : ' · ${DateFormat('d/M HH:mm').format(at)}'}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  if (pending)
                    const Text('Σε αναμονή (παλιά ροή) — πατήστε για έλεγχο',
                        style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                  if (undone)
                    const Text('Αναιρέθηκε', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (pending) const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            if (!pending && !undone)
              TextButton(
                onPressed: () => _confirmUndo(context),
                child: const Text('Αναίρεση', style: TextStyle(color: AppTheme.red)),
              ),
          ],
        ),
      ),
    );
  }
}

extension on _PendingClubCard {
  Future<void> _confirmUndo(BuildContext context) async {
    final upload = (club['rosterUpload'] as Map?) ?? const {};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Αναίρεση ανεβάσματος — ${club['name'] ?? ''}'),
        content: Text(
          'Θα διαγραφούν οι ${upload['newCount'] ?? 0} νέοι παίκτες και οι '
          '${upload['updateCount'] ?? 0} αλλαγές θα επιστρέψουν στις προηγούμενες τιμές. '
          '${(upload['removeCount'] ?? 0) > 0 ? 'Οι ${upload['removeCount']} παίκτες που αποχώρησαν επιστρέφουν στο ρόστερ. ' : ''}'
          'Αν άλλαξε το λογότυπο, επανέρχεται το προηγούμενο. Ο σύλλογος θα το δει.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Αναίρεση', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final byName = context.read<AppProvider>().user?.name ?? 'Super Admin';
    try {
      await RosterService().undo(clubId, byName: byName);
      messenger.showSnackBar(const SnackBar(content: Text('Το ανέβασμα αναιρέθηκε.')));
    } catch (e) {
      final msg = e is StateError ? e.message : '$e';
      messenger.showSnackBar(SnackBar(content: Text('Η αναίρεση απέτυχε: $msg'), backgroundColor: AppTheme.red));
    }
  }
}

class RosterReviewScreen extends StatefulWidget {
  final String clubId;
  const RosterReviewScreen({super.key, required this.clubId});

  @override
  State<RosterReviewScreen> createState() => _RosterReviewScreenState();
}

class _RosterReviewScreenState extends State<RosterReviewScreen> {
  final _service = RosterService();
  bool _busy = false;
  late Future<_Review> _review = _load();

  Future<_Review> _load() async {
    final clubRef = FirebaseFirestore.instance.collection('clubs').doc(widget.clubId);
    final club = (await clubRef.get()).data() ?? {};
    final uploadId = ((club['rosterUpload'] as Map?) ?? {})['uploadId'] as String?;
    final created = <Map<String, dynamic>>[];
    final updated = <Map<String, dynamic>>[];
    if (uploadId != null) {
      for (final col in const ['players', 'women_players']) {
        final c = await clubRef.collection(col).where('uploadId', isEqualTo: uploadId).get();
        created.addAll(c.docs.map((d) => d.data()).where((m) => m['approvalStatus'] == 'pending'));
        final u = await clubRef.collection(col).where('pendingUploadId', isEqualTo: uploadId).get();
        updated.addAll(u.docs.map((d) => d.data()));
      }
    }
    return _Review(club, created, updated);
  }

  Future<void> _approve() async {
    final name = context.read<AppProvider>().user?.name ?? 'admin';
    setState(() => _busy = true);
    try {
      await _service.approve(widget.clubId, byName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Εγκρίθηκε. Οι παίκτες φαίνονται πλέον στο Clubera.'),
        backgroundColor: AppTheme.supportGreen,
      ));
      Navigator.pop(context);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Απόρριψη ρόστερ'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Λόγος (τον βλέπει ο σύλλογος)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Άκυρο')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Απόρριψη', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    final name = context.read<AppProvider>().user?.name ?? 'admin';
    setState(() => _busy = true);
    try {
      await _service.reject(widget.clubId, reason: reason, byName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Απορρίφθηκε.')));
      Navigator.pop(context);
    } catch (e) {
      _error(e);
    }
  }

  void _error(Object e) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Σφάλμα: $e'),
      backgroundColor: AppTheme.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Έλεγχος ρόστερ')),
      body: FutureBuilder<_Review>(
        future: _review,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Σφάλμα: ${snap.error}', style: const TextStyle(color: AppTheme.textSecondary)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final r = snap.data!;
          final upload = (r.club['rosterUpload'] as Map?) ?? const {};
          final pendingLogo = r.club['pendingLogoUrl'] as String?;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _review = _load();
              });
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Text('${r.club['name'] ?? ''}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                Text('Ανέβηκε από ${upload['byName'] ?? '—'} · με δήλωση συγκατάθεσης',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (r.club['rosterStatus'] != 'pending')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Αυτό το ρόστερ δεν είναι πια σε αναμονή.', style: TextStyle(color: AppTheme.accent)),
                  ),
                if (pendingLogo != null) ...[
                  _section('Λογότυπο'),
                  Row(
                    children: [
                      Column(children: [
                        _Logo(url: r.club['logoUrl'] as String?, size: 64),
                        const SizedBox(height: 4),
                        const Text('Τώρα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ]),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.arrow_forward, color: AppTheme.textSecondary),
                      ),
                      Column(children: [
                        _Logo(url: pendingLogo, size: 64),
                        const SizedBox(height: 4),
                        const Text('Νέο', style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                      ]),
                    ],
                  ),
                ],
                if (r.created.isNotEmpty) ...[
                  _section('Νέοι παίκτες (${r.created.length})'),
                  for (final p in r.created) _playerRow(p, null),
                ],
                if (r.updated.isNotEmpty) ...[
                  _section('Αλλαγές σε υπάρχοντες (${r.updated.length})'),
                  for (final p in r.updated) _playerRow(p, (p['pendingUpdate'] as Map?) ?? const {}),
                ],
                if (r.created.isEmpty && r.updated.isEmpty && pendingLogo == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('Δεν υπάρχει κάτι για έγκριση.', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.red,
                    side: const BorderSide(color: AppTheme.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : _reject,
                  child: const Text('Απόρριψη'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.supportGreen,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : _approve,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Έγκριση όλων'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      );

  Widget _playerRow(Map<String, dynamic> p, Map? change) {
    String squad(Object? s) => switch (s) { 'B' => 'Β΄', 'W' => 'Γυν.', _ => 'Α΄' };
    final current = '${p['position'] ?? ''}${p['number'] != null ? ' #${p['number']}' : ''} · ${squad(p['squad'])}';
    final next = change == null
        ? null
        : '${change['position'] ?? ''}${change['number'] != null ? ' #${change['number']}' : ''} · ${squad(change['squad'])}';
    final minor = (change?['isMinor'] ?? p['isMinor']) == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name'] ?? ''}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(next == null || next == current ? current : '$current  →  $next',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (minor)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Ανήλικος', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
            ),
        ],
      ),
    );
  }
}

class _Review {
  final Map<String, dynamic> club;
  final List<Map<String, dynamic>> created;
  final List<Map<String, dynamic>> updated;
  _Review(this.club, this.created, this.updated);
}

class _Logo extends StatelessWidget {
  final String? url;
  final double size;
  const _Logo({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppTheme.cardBg2,
        child: (url == null || url!.isEmpty)
            ? Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: size * 0.5)
            : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
      ),
    );
  }
}
