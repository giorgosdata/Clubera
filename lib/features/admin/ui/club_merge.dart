// Super Admin: merge a duplicate club into the mapped one.
//
// Approving club requests used to create a new club even when the club was
// already mapped (per ΕΠΣ and category), so some clubs exist twice: the
// duplicate holds the players and activity, the mapped one is empty. This
// moves everything from the duplicate (source) to the mapped club (target)
// and deletes the duplicate.
//
// Moved: players, women's players, academies (with their players, transfers
// and matches), transfers, feed, gallery, stadium photos, announcements,
// roster keys. Re-pointed to the target: matches (home/away and their
// events), games, rewards, sponsors, donations, prizes, users
// whose club or followed clubs is the source. A player already in the target
// under the same name is not copied twice. Fan votes stay behind (the rules
// let only the voter write them); the vote count is added to the target.
// Document ids are kept, so running it again after an interruption is safe.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/club_model.dart';
import '../../club_admin/roster/roster_parser.dart' show normalizeName;
import 'club_admin_link.dart' show pickExistingClub;

const _flatSubs = [
  'players',
  'women_players',
  'transfers',
  'feed',
  'gallery',
  'stadium_photos',
  'announcements',
  'roster_keys',
];
const _academySubs = ['players', 'transfers', 'matches'];
const _clubIdCollections = ['games', 'rewards', 'sponsors', 'donations', 'user_prizes'];

class MergePlan {
  final Map<String, int> moveCounts = {};
  final Set<String> skippedPlayers = {};
  int academies = 0;
  int matches = 0;
  int users = 0;
  int otherRefs = 0;

  int get players => (moveCounts['players'] ?? 0) + (moveCounts['women_players'] ?? 0);
}

class ClubMerger {
  ClubMerger(this.source, this.target);
  final ClubModel source;
  final ClubModel target;

  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _src => _db.collection('clubs').doc(source.id);
  DocumentReference<Map<String, dynamic>> get _dst => _db.collection('clubs').doc(target.id);

  /// Player names already in the target, per collection, so the same player
  /// is not copied twice.
  Future<Set<String>> _targetNames(String col) async {
    final s = await _dst.collection(col).get();
    return s.docs.map((d) => normalizeName('${d.data()['name'] ?? ''}')).toSet();
  }

  /// Counts what would move, without changing anything.
  Future<MergePlan> plan() async {
    final p = MergePlan();
    for (final col in _flatSubs) {
      final s = await _src.collection(col).get();
      if (col == 'players' || col == 'women_players') {
        final existing = await _targetNames(col);
        for (final d in s.docs) {
          final n = normalizeName('${d.data()['name'] ?? ''}');
          if (n.isNotEmpty && existing.contains(n)) {
            p.skippedPlayers.add('${d.data()['name']}');
          } else {
            p.moveCounts[col] = (p.moveCounts[col] ?? 0) + 1;
          }
        }
      } else {
        p.moveCounts[col] = s.size;
      }
    }
    p.academies = (await _src.collection('academies').get()).size;
    final home = await _db.collection('matches').where('homeClubId', isEqualTo: source.id).get();
    final away = await _db.collection('matches').where('awayClubId', isEqualTo: source.id).get();
    p.matches = {...home.docs.map((d) => d.id), ...away.docs.map((d) => d.id)}.length;
    final u1 = await _db.collection('users').where('clubId', isEqualTo: source.id).get();
    final u2 = await _db.collection('users').where('followedClubs', arrayContains: source.id).get();
    p.users = {...u1.docs.map((d) => d.id), ...u2.docs.map((d) => d.id)}.length;
    for (final col in _clubIdCollections) {
      p.otherRefs += (await _db.collection(col).where('clubId', isEqualTo: source.id).get()).size;
    }
    return p;
  }

  /// Moves everything to the target and deletes the source club.
  Future<void> run({required String byName}) async {
    final ops = <void Function(WriteBatch)>[];

    // Sub-collections of the club.
    for (final col in _flatSubs) {
      final existing = (col == 'players' || col == 'women_players') ? await _targetNames(col) : <String>{};
      final s = await _src.collection(col).get();
      for (final d in s.docs) {
        final data = d.data();
        final n = normalizeName('${data['name'] ?? ''}');
        final duplicate = existing.isNotEmpty && n.isNotEmpty && existing.contains(n);
        if (!duplicate) {
          final copy = {...data, if (data.containsKey('clubId')) 'clubId': target.id};
          ops.add((b) => b.set(_dst.collection(col).doc(d.id), copy));
        }
        ops.add((b) => b.delete(d.reference));
      }
    }

    // Academies and their own sub-collections.
    final academies = await _src.collection('academies').get();
    for (final a in academies.docs) {
      final data = a.data();
      ops.add((b) => b.set(_dst.collection('academies').doc(a.id), {
            ...data,
            if (data.containsKey('clubId')) 'clubId': target.id,
          }));
      for (final sub in _academySubs) {
        final s = await a.reference.collection(sub).get();
        for (final d in s.docs) {
          ops.add((b) => b.set(_dst.collection('academies').doc(a.id).collection(sub).doc(d.id), d.data()));
          ops.add((b) => b.delete(d.reference));
        }
      }
      ops.add((b) => b.delete(a.reference));
    }

    // Matches: home/away club and the club on their events.
    final home = await _db.collection('matches').where('homeClubId', isEqualTo: source.id).get();
    final away = await _db.collection('matches').where('awayClubId', isEqualTo: source.id).get();
    final matchIds = <String>{};
    for (final d in home.docs) {
      matchIds.add(d.id);
      ops.add((b) => b.update(d.reference, {'homeClubId': target.id}));
    }
    for (final d in away.docs) {
      matchIds.add(d.id);
      ops.add((b) => b.update(d.reference, {'awayClubId': target.id}));
    }
    for (final id in matchIds) {
      final ev = await _db.collection('matches').doc(id).collection('events').where('clubId', isEqualTo: source.id).get();
      for (final e in ev.docs) {
        ops.add((b) => b.update(e.reference, {'clubId': target.id}));
      }
    }

    // Other collections that point at the club.
    for (final col in _clubIdCollections) {
      final s = await _db.collection(col).where('clubId', isEqualTo: source.id).get();
      for (final d in s.docs) {
        ops.add((b) => b.update(d.reference, {'clubId': target.id}));
      }
    }

    // Users: their club, and the clubs they follow.
    final u1 = await _db.collection('users').where('clubId', isEqualTo: source.id).get();
    for (final d in u1.docs) {
      ops.add((b) => b.update(d.reference, {'clubId': target.id}));
    }
    final u2 = await _db.collection('users').where('followedClubs', arrayContains: source.id).get();
    for (final d in u2.docs) {
      final list = List<String>.from(d.data()['followedClubs'] ?? const [])..remove(source.id);
      if (!list.contains(target.id)) list.add(target.id);
      ops.add((b) => b.update(d.reference, {'followedClubs': list}));
    }

    // Club Admin and staff: the source admin becomes the target admin if the
    // target has none, otherwise staff.
    final dstData = (await _dst.get()).data() ?? const <String, dynamic>{};
    final staff = <String>{
      ...List<String>.from(dstData['staffUids'] ?? const []),
      ...source.staffUids,
    };
    String admin = '${dstData['adminUid'] ?? ''}';
    if (admin.isEmpty && source.adminUid.isNotEmpty) {
      admin = source.adminUid;
    } else if (source.adminUid.isNotEmpty) {
      staff.add(source.adminUid);
    }
    staff.remove(admin);
    ops.add((b) => b.update(_dst, {
          'adminUid': admin,
          'staffUids': staff.toList(),
          'followers': FieldValue.increment(source.followers),
          'votes': FieldValue.increment(source.votes),
          if (((dstData['logoUrl'] as String?) ?? '').isEmpty && (source.logoUrl ?? '').isNotEmpty)
            'logoUrl': source.logoUrl,
          'mergedFrom': FieldValue.arrayUnion([
            {'clubId': source.id, 'name': source.name, 'at': Timestamp.now(), 'by': byName}
          ]),
        }));

    // Upload history of the source no longer matches its players.
    for (final d in (await _src.collection('roster_uploads').get()).docs) {
      ops.add((b) => b.delete(d.reference));
    }

    await _commit(ops);
    await _src.delete();
  }

  Future<void> _commit(List<void Function(WriteBatch)> ops) async {
    for (var i = 0; i < ops.length; i += 400) {
      final b = _db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(b);
      }
      await b.commit();
    }
  }
}

/// Admin → Clubs → ⋮ → «Συγχώνευση σε άλλον σύλλογο».
Future<void> showMergeClubDialog(BuildContext context, ClubModel source, {required String byName}) async {
  final target = await pickExistingClub(context, initialQuery: source.name);
  if (target == null || !context.mounted) return;
  if (target.id == source.id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Διαλέξατε τον ίδιο σύλλογο.'), backgroundColor: AppTheme.red),
    );
    return;
  }
  final merger = ClubMerger(source, target);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MergeDialog(merger: merger, byName: byName),
  );
}

class _MergeDialog extends StatefulWidget {
  final ClubMerger merger;
  final String byName;
  const _MergeDialog({required this.merger, required this.byName});

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late final Future<MergePlan> _plan = widget.merger.plan();
  bool _running = false;
  bool _done = false;
  String? _error;

  String _where(ClubModel c) => [c.city, c.assocName ?? '', c.league].where((s) => s.isNotEmpty).join(' • ');

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.merger.run(byName: widget.byName);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.merger.source, t = widget.merger.target;
    const label = TextStyle(color: AppTheme.textSecondary, fontSize: 12);
    const body = TextStyle(color: AppTheme.textPrimary, fontSize: 13);
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Συγχώνευση συλλόγων', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<MergePlan>(
          future: _plan,
          builder: (ctx, snap) {
            if (snap.hasError) return Text('Σφάλμα: ${snap.error}', style: body);
            if (!snap.hasData) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            final p = snap.data!;
            if (_done) {
              return Text(
                '✅ Ολοκληρώθηκε. Οι παίκτες και η δραστηριότητα του «${s.name}» είναι πλέον στον «${t.name}», '
                'και ο διπλότυπος σύλλογος διαγράφηκε.',
                style: body,
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ΑΠΟ (θα διαγραφεί)', style: label),
                  Text(s.name, style: body.copyWith(fontWeight: FontWeight.bold)),
                  Text(_where(s), style: label),
                  const SizedBox(height: 10),
                  const Text('ΣΕ (χαρτογραφημένος)', style: label),
                  Text(t.name, style: body.copyWith(fontWeight: FontWeight.bold)),
                  Text(_where(t), style: label),
                  const Divider(color: AppTheme.cardBg2, height: 24),
                  Text('Θα μεταφερθούν:', style: body.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('• ${p.players} παίκτες', style: body),
                  if (p.academies > 0) Text('• ${p.academies} ακαδημίες', style: body),
                  if ((p.moveCounts['transfers'] ?? 0) > 0) Text('• ${p.moveCounts['transfers']} μεταγραφές', style: body),
                  if ((p.moveCounts['gallery'] ?? 0) + (p.moveCounts['stadium_photos'] ?? 0) > 0)
                    Text('• ${(p.moveCounts['gallery'] ?? 0) + (p.moveCounts['stadium_photos'] ?? 0)} φωτογραφίες/βίντεο', style: body),
                  if ((p.moveCounts['feed'] ?? 0) + (p.moveCounts['announcements'] ?? 0) > 0)
                    Text('• ${(p.moveCounts['feed'] ?? 0) + (p.moveCounts['announcements'] ?? 0)} αναρτήσεις/ανακοινώσεις', style: body),
                  if (p.matches > 0) Text('• ${p.matches} αγώνες', style: body),
                  if (p.users > 0) Text('• ${p.users} χρήστες (admin, προσωπικό, fans)', style: body),
                  if (p.otherRefs > 0) Text('• ${p.otherRefs} λοιπά (παιχνίδια, χορηγοί, δωρεές…)', style: body),
                  if (p.skippedPlayers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Υπάρχουν ήδη στον «${t.name}» και δεν θα αντιγραφούν δεύτερη φορά: ${p.skippedPlayers.join(', ')}',
                      style: label,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Η συγχώνευση δεν αναιρείται. Ελέγξτε ότι πρόκειται για τον ίδιο σύλλογο.',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text('Σφάλμα: $_error', style: const TextStyle(color: AppTheme.red, fontSize: 12)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: _running ? null : () => Navigator.pop(context),
            child: const Text('Άκυρο'),
          ),
        if (!_done)
          TextButton(
            onPressed: _running ? null : _run,
            child: _running
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Συγχώνευση', style: TextStyle(color: AppTheme.red)),
          ),
        if (_done) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Κλείσιμο')),
      ],
    );
  }
}
