// Super Admin: make a user the Club Admin of a club.
//
// Clubs are mostly mapped in advance (per ΕΠΣ and category). When a club
// applies, the Super Admin either links the applicant to the existing mapped
// club, or creates a new club when it is not mapped yet. Linking instead of
// creating keeps players, matches and standings on one club document, so
// they are not split across duplicates.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/club_model.dart';
import '../../../models/user_model.dart';
import '../../club_admin/roster/roster_parser.dart' show normalizeName;
import '../../clubs/ui/create_club_screen.dart' show generateInviteCode;

/// Search key: upper case, no Greek accents, no spaces — so "Διάνα
/// Ηλιούπολης" finds "ΔΙΑΝΑ ΗΛΙ ΟΥΠΟΛΗΣ".
String clubSearchKey(String s) => normalizeName(s).replaceAll(' ', '');

/// Makes [userId] the Club Admin of the existing club [clubId]. A previous
/// Club Admin stays on as staff, so nobody is locked out. When [requestId] is
/// given, that club request is marked approved and linked to the club.
Future<void> linkClubAdmin({
  required String clubId,
  required String userId,
  String? requestId,
}) async {
  final db = FirebaseFirestore.instance;
  final clubRef = db.collection('clubs').doc(clubId);
  final club = (await clubRef.get()).data() ?? const <String, dynamic>{};
  final previous = club['adminUid'] as String?;
  final staff = List<String>.from(club['staffUids'] ?? const [])..remove(userId);
  if (previous != null && previous.isNotEmpty && previous != userId && !staff.contains(previous)) {
    staff.add(previous);
  }

  final batch = db.batch();
  batch.update(clubRef, {
    'adminUid': userId,
    'staffUids': staff,
    if ((club['inviteCode'] as String?)?.isNotEmpty != true) 'inviteCode': generateInviteCode(),
  });
  batch.update(db.collection('users').doc(userId), {
    'role': 'club',
    'clubId': clubId,
  });
  if (requestId != null) {
    batch.update(db.collection('club_requests').doc(requestId), {
      'status': 'approved',
      'clubId': clubId,
      'linkedExisting': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

/// Finds a user by the email they signed up with.
Future<UserModel?> findUserByEmail(String email) async {
  final users = FirebaseFirestore.instance.collection('users');
  final e = email.trim();
  for (final candidate in {e, e.toLowerCase()}) {
    final q = await users.where('email', isEqualTo: candidate).limit(1).get();
    if (q.docs.isNotEmpty) {
      return UserModel.fromMap(q.docs.first.data(), q.docs.first.id);
    }
  }
  return null;
}

/// Lets the Super Admin pick an existing club. [initialQuery] pre-fills the
/// search, e.g. with the name from a club request.
Future<ClubModel?> pickExistingClub(BuildContext context, {String initialQuery = ''}) {
  return showDialog<ClubModel>(
    context: context,
    builder: (_) => _ClubPickerDialog(initialQuery: initialQuery),
  );
}

class _ClubPickerDialog extends StatefulWidget {
  final String initialQuery;
  const _ClubPickerDialog({required this.initialQuery});

  @override
  State<_ClubPickerDialog> createState() => _ClubPickerDialogState();
}

class _ClubPickerDialogState extends State<_ClubPickerDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialQuery);
  late final Future<List<ClubModel>> _clubs = FirebaseFirestore.instance
      .collection('clubs')
      .get()
      .then((s) => s.docs.map((d) => ClubModel.fromMap(d.data(), d.id)).toList());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = clubSearchKey(_ctrl.text);
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Επιλογή υπάρχοντος συλλόγου', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Όνομα, πόλη ή ΕΠΣ',
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<ClubModel>>(
                future: _clubs,
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Σφάλμα: ${snap.error}', style: const TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  if (key.length < 2) {
                    return const Center(
                      child: Text('Γράψτε τουλάχιστον 2 γράμματα', style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  final hits = snap.data!
                      .where((c) =>
                          clubSearchKey(c.name).contains(key) ||
                          clubSearchKey(c.city).contains(key) ||
                          clubSearchKey(c.assocName ?? '').contains(key))
                      .take(50)
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
                  if (hits.isEmpty) {
                    return const Center(
                      child: Text(
                        'Δεν βρέθηκε σύλλογος.\nΑν δεν είναι χαρτογραφημένος, επιλέξτε «Δημιουργία νέου».',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: hits.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.cardBg2),
                    itemBuilder: (_, i) {
                      final c = hits[i];
                      final hasAdmin = c.adminUid.isNotEmpty;
                      return ListTile(
                        dense: true,
                        title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          [c.city, c.assocName ?? '', c.league].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: hasAdmin
                            ? const Text('έχει admin', style: TextStyle(color: AppTheme.accent, fontSize: 11))
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Άκυρο')),
      ],
    );
  }
}

/// Confirms linking [user] (or the applicant [userLabel]) to [club]. Warns
/// when the club already has a Club Admin.
Future<bool> confirmLink(BuildContext context, {required ClubModel club, required String userLabel}) async {
  final hasAdmin = club.adminUid.isNotEmpty;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Ορισμός Club Admin', style: TextStyle(color: Colors.white)),
      content: Text(
        '$userLabel θα γίνει Club Admin του συλλόγου «${club.name}» '
        '(${[club.city, club.assocName ?? ''].where((s) => s.isNotEmpty).join(', ')}).'
        '${hasAdmin ? '\n\nΟ σύλλογος έχει ήδη Club Admin· θα παραμείνει ως μέλος του προσωπικού.' : ''}',
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ορισμός', style: TextStyle(color: AppTheme.supportGreen)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Admin → Clubs → ⋮ → «Ορισμός Club Admin»: asks for the user's email and
/// links that user to [club].
Future<void> showSetClubAdminDialog(BuildContext context, ClubModel club) async {
  final ctrl = TextEditingController();
  final email = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text('Club Admin — ${club.name}', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Το email με το οποίο ο υπεύθυνος του συλλόγου έχει κάνει εγγραφή στο Clubera.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'email@example.com'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Άκυρο')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Συνέχεια', style: TextStyle(color: AppTheme.supportGreen)),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (email == null || email.trim().isEmpty || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final user = await findUserByEmail(email);
    if (user == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Δεν βρέθηκε χρήστης με email ${email.trim()}. Πρέπει πρώτα να κάνει εγγραφή στο Clubera.'),
        backgroundColor: AppTheme.red,
      ));
      return;
    }
    if (user.role == 'admin') {
      messenger.showSnackBar(const SnackBar(
        content: Text('Αυτός ο χρήστης είναι Super Admin· χρησιμοποιήστε άλλο λογαριασμό για τον σύλλογο.'),
        backgroundColor: AppTheme.red,
      ));
      return;
    }
    if (!context.mounted) return;
    if (!await confirmLink(context, club: club, userLabel: '${user.name} (${user.email})')) return;
    await linkClubAdmin(clubId: club.id, userId: user.uid);
    messenger.showSnackBar(SnackBar(
      content: Text('✅ ${user.name} είναι πλέον Club Admin του «${club.name}».'),
      backgroundColor: AppTheme.supportGreen,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: AppTheme.red));
  }
}

/// Super Admin: removes the Club Admin of [club] (e.g. a test account). The
/// account stays a normal user; if it is still the admin of another club it
/// goes back to that club, otherwise it becomes a fan.
Future<void> showRemoveClubAdminDialog(BuildContext context, ClubModel club) async {
  final db = FirebaseFirestore.instance;
  final uid = club.adminUid;
  if (uid.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ο σύλλογος «${club.name}» δεν έχει Club Admin.')),
    );
    return;
  }
  final userSnap = await db.collection('users').doc(uid).get();
  final u = userSnap.data() ?? const <String, dynamic>{};
  final who = [u['name'], u['email']].where((s) => s != null && '$s'.isNotEmpty).join(' · ');
  final others = (await db.collection('clubs').where('adminUid', isEqualTo: uid).get())
      .docs
      .where((d) => d.id != club.id)
      .toList();
  final backTo = others.isEmpty ? null : others.first;
  if (!context.mounted) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text('Αφαίρεση Club Admin — ${club.name}', style: const TextStyle(color: Colors.white)),
      content: Text(
        'Ο λογαριασμός ${who.isEmpty ? uid : who} δεν θα είναι πια διαχειριστής ούτε συνεργάτης του «${club.name}».\n\n'
        '${backTo != null ? 'Επιστρέφει ως Club Admin στον σύλλογο «${backTo.data()['name'] ?? backTo.id}».' : 'Γίνεται απλός χρήστης (fan).'}\n\n'
        'Μετά μπορείτε να στείλετε σύνδεσμο πρόσκλησης στον πραγματικό υπεύθυνο.',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Αφαίρεση', style: TextStyle(color: AppTheme.red)),
        ),
      ],
    ),
  );
  if (ok != true) return;

  try {
    final batch = db.batch();
    batch.update(db.collection('clubs').doc(club.id), {
      'adminUid': '',
      'staffUids': FieldValue.arrayRemove([uid]),
    });
    if (userSnap.exists && (u['clubId'] == club.id || u['clubId'] == null)) {
      batch.update(db.collection('users').doc(uid), {
        if (backTo != null) ...{'clubId': backTo.id, 'role': 'club'} else ...{'clubId': null, 'role': u['role'] == 'admin' ? 'admin' : 'fan'},
      });
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.supportGreen,
        content: Text('Αφαιρέθηκε ο Club Admin του «${club.name}».'
            '${backTo != null ? ' Ο λογαριασμός επέστρεψε στον «${backTo.data()['name'] ?? backTo.id}».' : ''}'),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.red, content: Text('Η αφαίρεση απέτυχε: $e')),
      );
    }
  }
}
