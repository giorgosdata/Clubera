// Saves an uploaded roster as "pending" and lets the Super Admin approve or
// reject it.
//
// Data model (no new collections, so the existing Firestore rules apply:
// club staff write only their own club, admins write everything):
//
//   clubs/{clubId}
//     rosterStatus:  'pending' | 'approved' | 'rejected'
//     rosterUpload:  {uploadId, byUid, byName, at, newCount, updateCount}
//     pendingLogoUrl: string (logo waiting for approval)
//     rosterRejectReason: string
//     rosterHistory: [{uploadId, result, at, by, newCount, updateCount}]
//   clubs/{clubId}/players/{id} and clubs/{clubId}/women_players/{id}
//     new player:      approvalStatus 'pending', uploadId, squad
//     existing player: pendingUpdate {...}, pendingUploadId
//   clubs/{clubId}/roster_keys/{playerId}   (club staff + admins only)
//     dupKey, pendingDupKey, pendingUploadId, collection
//
// The duplicate key is a hash of name + birth date. Player documents are
// public, and with a known name the birth date could be recovered from the
// hash by trying every date, so the key lives in roster_keys, never on the
// player document.
//
// Players with approvalStatus 'pending' are hidden from fans
// (see isPublicPlayer).

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'roster_parser.dart';

/// True when a player document may be shown to fans.
bool isPublicPlayer(Map<String, dynamic> data) {
  final s = data['approvalStatus'];
  return s != 'pending' && s != 'rejected';
}

/// create: new player · update: changed · unchanged: same as in Clubera ·
/// remove: marked «Αποχώρησε» · notFound: marked «Αποχώρησε» but not in the
/// roster (nothing to do).
enum RosterAction { create, update, unchanged, remove, notFound }

class RosterPlanItem {
  final RosterRow row;
  final RosterAction action;
  final String? existingId;
  final String? existingCollection;
  const RosterPlanItem(this.row, this.action, {this.existingId, this.existingCollection});
}

class RosterPlan {
  final List<RosterPlanItem> items;
  const RosterPlan(this.items);
  int get newCount => items.where((i) => i.action == RosterAction.create).length;
  int get updateCount => items.where((i) => i.action == RosterAction.update).length;
  int get unchangedCount => items.where((i) => i.action == RosterAction.unchanged).length;
  int get removeCount => items.where((i) => i.action == RosterAction.remove).length;
}

class RosterService {
  RosterService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _club(String clubId) =>
      _db.collection('clubs').doc(clubId);

  CollectionReference<Map<String, dynamic>> _keys(String clubId) =>
      _club(clubId).collection('roster_keys');

  CollectionReference<Map<String, dynamic>> _uploads(String clubId) =>
      _club(clubId).collection('roster_uploads');

  /// Super Admin: reverses the club's latest published upload — new players
  /// are removed, changed players and the logo go back to their earlier
  /// values. Only the latest upload can be undone, so a later upload is never
  /// overwritten by an older one.
  Future<void> undo(String clubId, {required String byName}) async {
    final club = (await _club(clubId).get()).data() ?? {};
    final upload = (club['rosterUpload'] as Map?) ?? {};
    final uploadId = upload['uploadId'] as String?;
    if (uploadId == null) throw StateError('Δεν υπάρχει ανέβασμα για αναίρεση.');
    final recSnap = await _uploads(clubId).doc(uploadId).get();
    final rec = recSnap.data();
    if (rec == null) {
      throw StateError('Αυτό το ανέβασμα δεν έχει στοιχεία αναίρεσης (έγινε πριν προστεθεί η αναίρεση).');
    }
    if (rec['undone'] == true) throw StateError('Έχει ήδη αναιρεθεί.');

    final ops = <void Function(WriteBatch)>[];
    for (final c in (rec['created'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(c as Map);
      final ref = _club(clubId).collection(m['collection'] as String).doc(m['id'] as String);
      ops.add((b) => b.delete(ref));
      ops.add((b) => b.delete(_keys(clubId).doc(m['id'] as String)));
    }
    for (final p in (rec['previous'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(p as Map);
      final ref = _club(clubId).collection(m['collection'] as String).doc(m['id'] as String);
      final restore = <String, dynamic>{
        ...Map<String, dynamic>.from((m['values'] as Map?) ?? {}),
        for (final k in (m['absent'] as List? ?? const [])) k as String: FieldValue.delete(),
      };
      if (restore.isNotEmpty) ops.add((b) => b.update(ref, restore));
    }
    final prevKeys = Map<String, dynamic>.from((rec['previousKeys'] as Map?) ?? {});
    prevKeys.forEach((id, key) {
      final ref = _keys(clubId).doc(id);
      ops.add((b) => key == null ? b.delete(ref) : b.update(ref, {'dupKey': key}));
    });
    ops.add((b) => b.update(recSnap.reference, {
          'undone': true,
          'undoneAt': FieldValue.serverTimestamp(),
          'undoneBy': byName,
        }));
    await _commit(ops);

    final newLogo = rec['newLogoUrl'] as String?;
    final prevLogo = rec['previousLogoUrl'] as String?;
    await _club(clubId).update({
      if (newLogo != null && club['logoUrl'] == newLogo) 'logoUrl': prevLogo ?? FieldValue.delete(),
      'rosterStatus': 'undone',
      'rosterHistory': FieldValue.arrayUnion([
        {
          'uploadId': uploadId,
          'result': 'undone',
          'at': Timestamp.now(),
          'by': byName,
          'uploadedBy': upload['byName'],
        }
      ]),
    });
  }

  /// The club's current public players, for the pre-filled template.
  Future<List<TemplatePlayer>> templatePlayers(String clubId) async {
    final out = <TemplatePlayer>[];
    for (final col in const ['players', 'women_players']) {
      final snap = await _club(clubId).collection(col).get();
      for (final d in snap.docs) {
        final m = d.data();
        if (m['isActive'] == false || !isPublicPlayer(m)) continue;
        final pos = m['position'];
        final num = m['number'];
        out.add(TemplatePlayer(
          id: d.id,
          name: '${m['name'] ?? ''}'.trim(),
          position: (pos is String && const {'GK', 'DEF', 'MID', 'FWD'}.contains(pos)) ? pos : null,
          number: num is num ? num.toInt() : null,
          squadLabel: col == 'women_players'
              ? RosterSquad.women.label
              : (m['squad'] == 'B' ? RosterSquad.second.label : RosterSquad.first.label),
          // Players uploaded from Excel came with the club's consent.
          consentOnFile: m['source'] == 'roster_upload',
        ));
      }
    }
    const order = {'GK': 0, 'DEF': 1, 'MID': 2, 'FWD': 3};
    out.sort((a, b) {
      final s = a.squadLabel.compareTo(b.squadLabel);
      if (s != 0) return s;
      final p = (order[a.position] ?? 9).compareTo(order[b.position] ?? 9);
      return p != 0 ? p : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Compares the valid rows with the players already in the club.
  Future<RosterPlan> plan(String clubId, List<RosterRow> rows, {DateTime? today}) async {
    final keys = <String, String>{};
    for (final d in (await _keys(clubId).get()).docs) {
      final k = d.data()['dupKey'];
      if (k is String) keys[d.id] = k;
    }
    final existing = <_Existing>[];
    for (final col in const ['players', 'women_players']) {
      final snap = await _club(clubId).collection(col).get();
      for (final d in snap.docs) {
        final m = Map<String, dynamic>.from(d.data());
        if (m['isActive'] == false) continue;
        // Older test uploads kept the key on the player document.
        m['dupKey'] = keys[d.id] ?? m['dupKey'];
        existing.add(_Existing(d.id, col, m));
      }
    }
    final items = <RosterPlanItem>[];
    final used = <String>{};
    for (final row in rows) {
      final col = row.squad.collection;
      final key = row.dupKey;
      final norm = normalizeName(row.name);
      _Existing? match;
      // 0) the row came from the pre-filled template: its Clubera id
      if (row.existingId != null) {
        for (final e in existing) {
          if (e.id == row.existingId && !used.contains(e.id)) {
            match = e;
            break;
          }
        }
      }
      if (row.leaving) {
        // Without an id, a player who left is found by name.
        match ??= existing.cast<_Existing?>().firstWhere(
              (e) => !used.contains(e!.id) && normalizeName('${e.data['name'] ?? ''}') == norm,
              orElse: () => null,
            );
        if (match == null) {
          items.add(RosterPlanItem(row, RosterAction.notFound));
        } else {
          used.add(match.id);
          items.add(RosterPlanItem(row, RosterAction.remove,
              existingId: match.id, existingCollection: match.collection));
        }
        continue;
      }
      // 1) same name + birth date (hash) — the reliable match
      for (final e in existing) {
        if (match != null) break;
        if (e.collection == col && !used.contains(e.id) && e.data['dupKey'] == key) {
          match = e;
          break;
        }
      }
      // 2) players entered by hand before (no hash): same name
      match ??= existing.cast<_Existing?>().firstWhere(
            (e) =>
                e!.collection == col &&
                !used.contains(e.id) &&
                e.data['dupKey'] == null &&
                normalizeName('${e.data['name'] ?? ''}') == norm,
            orElse: () => null,
          );
      if (match == null) {
        items.add(RosterPlanItem(row, RosterAction.create));
        continue;
      }
      used.add(match.id);
      final m = match.data;
      final same = m['position'] == row.position &&
          m['number'] == row.number &&
          (m['squad'] ?? 'A') == row.squad.code &&
          // No birth date in the row = the key on file stays as it is.
          (row.birthDate == null || m['dupKey'] == key);
      items.add(RosterPlanItem(
        row,
        same ? RosterAction.unchanged : RosterAction.update,
        existingId: match.id,
        existingCollection: match.collection,
      ));
    }
    return RosterPlan(items);
  }

  /// Uploads the logo (bytes) to Storage and returns its download URL.
  Future<String> uploadPendingLogo(String clubId, Uint8List bytes, String fileName) async {
    final isPng = fileName.toLowerCase().endsWith('.png');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('clubs/$clubId/logo_pending_$ts.${isPng ? 'png' : 'jpg'}');
    await ref.putData(bytes, SettableMetadata(contentType: isPng ? 'image/png' : 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Saves the plan as a pending upload. Returns the upload id.
  Future<String> submit({
    required String clubId,
    required RosterPlan plan,
    required String byUid,
    required String byName,
    String? pendingLogoUrl,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final uploadId = _db.collection('clubs').doc().id;
    final ops = <void Function(WriteBatch)>[];

    for (final item in plan.items) {
      final r = item.row;
      final adultAge = r.isMinorOn(now) ? null : r.ageOn(now);
      switch (item.action) {
        case RosterAction.unchanged:
        case RosterAction.notFound:
          break;
        case RosterAction.remove:
          // Applied on publish like any change, so «Αναίρεση» brings the
          // player back.
          final ref = _club(clubId).collection(item.existingCollection!).doc(item.existingId);
          ops.add((b) => b.update(ref, {
                'pendingUpdate': {'isActive': false},
                'pendingUploadId': uploadId,
              }));
          break;
        case RosterAction.create:
          final ref = _club(clubId).collection(r.squad.collection).doc();
          ops.add((b) => b.set(ref, {
                'name': r.name,
                'position': r.position,
                'number': r.number,
                'photoUrl': null,
                // Minors: only name and position are public (GDPR).
                'age': adultAge,
                'nationality': null,
                'isActive': true,
                'goals': 0,
                'yellowCards': 0,
                'redCards': 0,
                'appearances': 0,
                'isInjured': false,
                'squad': r.squad.code,
                'isMinor': r.isMinorOn(now),
                'approvalStatus': 'pending',
                'uploadId': uploadId,
                'source': 'roster_upload',
                'createdAt': FieldValue.serverTimestamp(),
              }));
          ops.add((b) => b.set(_keys(clubId).doc(ref.id), {
                'dupKey': r.dupKey,
                'collection': r.squad.collection,
                'uploadId': uploadId,
              }));
          break;
        case RosterAction.update:
          final ref = _club(clubId).collection(item.existingCollection!).doc(item.existingId);
          final known = r.birthDate != null;
          ops.add((b) => b.update(ref, {
                'pendingUpdate': {
                  'position': r.position,
                  'number': r.number,
                  'squad': r.squad.code,
                  // Without a birth date the age on file is kept.
                  if (known) 'age': adultAge,
                  if (known) 'isMinor': r.isMinorOn(now),
                },
                'pendingUploadId': uploadId,
                'dupKey': FieldValue.delete(),
              }));
          if (known) ops.add((b) => b.set(
                _keys(clubId).doc(item.existingId),
                {
                  'pendingDupKey': r.dupKey,
                  'pendingUploadId': uploadId,
                  'collection': item.existingCollection,
                },
                SetOptions(merge: true),
              ));
          break;
      }
    }
    await _commit(ops);

    await _club(clubId).update({
      'rosterStatus': 'pending',
      'rosterUpload': {
        'uploadId': uploadId,
        'byUid': byUid,
        'byName': byName,
        'at': FieldValue.serverTimestamp(),
        'newCount': plan.newCount,
        'updateCount': plan.updateCount,
        'removeCount': plan.removeCount,
        'consentDeclared': true,
      },
      'pendingLogoUrl': pendingLogoUrl ?? FieldValue.delete(),
      'rosterRejectReason': FieldValue.delete(),
    });
    return uploadId;
  }

  /// Publishes the pending players, changes and logo. Club Admins call it
  /// right after [submit] ([result] 'published'); the Super Admin can still
  /// approve uploads left pending by the earlier approval flow.
  Future<void> approve(String clubId, {required String byName, String result = 'approved'}) async {
    final club = (await _club(clubId).get()).data() ?? {};
    final upload = (club['rosterUpload'] as Map?) ?? {};
    final uploadId = upload['uploadId'] as String?;
    final ops = <void Function(WriteBatch)>[];
    final pendingLogo = club['pendingLogoUrl'] as String?;
    if (uploadId != null) {
      // What [undo] needs to put everything back as it was.
      final createdRefs = <Map<String, String>>[];
      final previous = <Map<String, dynamic>>[];
      for (final col in const ['players', 'women_players']) {
        final created = await _club(clubId).collection(col).where('uploadId', isEqualTo: uploadId).get();
        for (final d in created.docs) {
          if (d.data()['approvalStatus'] == 'pending') {
            createdRefs.add({'collection': col, 'id': d.id});
            ops.add((b) => b.update(d.reference, {'approvalStatus': 'approved'}));
          }
        }
        final updated = await _club(clubId).collection(col).where('pendingUploadId', isEqualTo: uploadId).get();
        for (final d in updated.docs) {
          final data = d.data();
          final pu = Map<String, dynamic>.from((data['pendingUpdate'] as Map?) ?? {});
          pu.remove('dupKey');
          previous.add({
            'collection': col,
            'id': d.id,
            'values': {for (final k in pu.keys) if (data.containsKey(k)) k: data[k]},
            'absent': [for (final k in pu.keys) if (!data.containsKey(k)) k],
          });
          ops.add((b) => b.update(d.reference, {
                ...pu,
                'pendingUpdate': FieldValue.delete(),
                'pendingUploadId': FieldValue.delete(),
              }));
        }
      }
      final prevKeys = <String, dynamic>{};
      final keys = await _keys(clubId).where('pendingUploadId', isEqualTo: uploadId).get();
      for (final k in keys.docs) {
        prevKeys[k.id] = k.data()['dupKey'];
        ops.add((b) => b.update(k.reference, {
              'dupKey': k.data()['pendingDupKey'],
              'pendingDupKey': FieldValue.delete(),
              'pendingUploadId': FieldValue.delete(),
            }));
      }
      ops.add((b) => b.set(_uploads(clubId).doc(uploadId), {
            'uploadId': uploadId,
            'publishedAt': FieldValue.serverTimestamp(),
            'publishedBy': byName,
            'uploadedBy': upload['byName'],
            'created': createdRefs,
            'previous': previous,
            'previousKeys': prevKeys,
            'previousLogoUrl': pendingLogo != null ? club['logoUrl'] : null,
            'newLogoUrl': pendingLogo,
            'undone': false,
          }));
    }
    await _commit(ops);

    await _club(clubId).update({
      if (pendingLogo != null) 'logoUrl': pendingLogo,
      'pendingLogoUrl': FieldValue.delete(),
      'rosterStatus': 'approved',
      'rosterRejectReason': FieldValue.delete(),
      'rosterHistory': FieldValue.arrayUnion([
        {
          'uploadId': uploadId,
          'result': result,
          'at': Timestamp.now(),
          'by': byName,
          'uploadedBy': upload['byName'],
          'newCount': upload['newCount'],
          'updateCount': upload['updateCount'],
          'removeCount': upload['removeCount'],
          'logo': pendingLogo != null,
        }
      ]),
    });
  }

  /// Super Admin rejects the upload, or a Club Admin cancels their own
  /// pending upload ([reason] null). Nothing of it stays visible.
  Future<void> reject(String clubId, {String? reason, required String byName, bool cancelledByClub = false}) async {
    final club = (await _club(clubId).get()).data() ?? {};
    final upload = (club['rosterUpload'] as Map?) ?? {};
    final uploadId = upload['uploadId'] as String?;
    final ops = <void Function(WriteBatch)>[];
    if (uploadId != null) {
      for (final col in const ['players', 'women_players']) {
        final created = await _club(clubId).collection(col).where('uploadId', isEqualTo: uploadId).get();
        for (final d in created.docs) {
          if (d.data()['approvalStatus'] == 'pending') {
            ops.add((b) => b.delete(d.reference));
            ops.add((b) => b.delete(_keys(clubId).doc(d.id)));
          }
        }
        final updated = await _club(clubId).collection(col).where('pendingUploadId', isEqualTo: uploadId).get();
        for (final d in updated.docs) {
          ops.add((b) => b.update(d.reference, {
                'pendingUpdate': FieldValue.delete(),
                'pendingUploadId': FieldValue.delete(),
              }));
        }
      }
      final keys = await _keys(clubId).where('pendingUploadId', isEqualTo: uploadId).get();
      for (final k in keys.docs) {
        ops.add((b) => b.update(k.reference, {
              'pendingDupKey': FieldValue.delete(),
              'pendingUploadId': FieldValue.delete(),
            }));
      }
    }
    await _commit(ops);

    final pendingLogo = club['pendingLogoUrl'] as String?;
    if (pendingLogo != null) {
      try {
        await _storage.refFromURL(pendingLogo).delete();
      } catch (_) {
        // The file may already be gone; the URL is removed below anyway.
      }
    }
    await _club(clubId).update({
      'pendingLogoUrl': FieldValue.delete(),
      'rosterStatus': cancelledByClub ? FieldValue.delete() : 'rejected',
      'rosterRejectReason': (reason == null || reason.trim().isEmpty) ? FieldValue.delete() : reason.trim(),
      'rosterHistory': FieldValue.arrayUnion([
        {
          'uploadId': uploadId,
          'result': cancelledByClub ? 'cancelled' : 'rejected',
          'reason': reason,
          'at': Timestamp.now(),
          'by': byName,
          'uploadedBy': upload['byName'],
          'newCount': upload['newCount'],
          'updateCount': upload['updateCount'],
        }
      ]),
    });
  }

  /// Firestore batches hold at most 500 writes.
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

class _Existing {
  final String id;
  final String collection;
  final Map<String, dynamic> data;
  _Existing(this.id, this.collection, this.data);
}
