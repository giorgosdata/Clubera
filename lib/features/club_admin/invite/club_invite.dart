// Club Admin invite links.
//
// The Super Admin creates a single-use link for a club
// (https://clubera.vercel.app/?invite=<token>) and sends it to the club's
// person by Viber / WhatsApp / email. Whoever opens it, signs in (or signs
// up) and accepts becomes the Club Admin of that club. No email lookup, no
// waiting for the Super Admin.
//
// Data: club_invites/{token} — clubId, clubName, createdBy, createdAt,
// expiresAt, usedBy, usedAt. The token is the document id; it is long and
// random, so only whoever has the link can read the invite.
//
// Accepting is one batch: the invite is marked used, the user becomes
// role 'club' of the club, the club's adminUid becomes the user (a previous
// admin stays on as staff). The Firestore rules check each step against the
// invite (see the CLUB ADMIN INVITES block in firestore.rules).

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';

const _prefKey = 'pending_club_invite';
const inviteValidity = Duration(days: 14);
const _appUrl = 'https://clubera.vercel.app';

String inviteLink(String token) => '$_appUrl/?invite=$token';

/// Reads an invite token from a link: the bare token, `?invite=…` or a
/// `/invite/<token>` path.
String? inviteTokenFromUri(Uri uri) {
  final q = uri.queryParameters['invite'];
  if (q != null && q.trim().isNotEmpty) return q.trim();
  final segs = uri.pathSegments;
  final i = segs.indexOf('invite');
  if (i >= 0 && i + 1 < segs.length && segs[i + 1].isNotEmpty) return segs[i + 1];
  return null;
}

/// Web: remembers the invite in the address bar, so it survives sign-in or
/// sign-up. Phones get it through [rememberInvite] from the deep link.
Future<void> captureInviteFromUrl() async {
  if (!kIsWeb) return;
  final token = inviteTokenFromUri(Uri.base);
  if (token != null) await rememberInvite(token);
}

Future<void> rememberInvite(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey, token);
}

Future<bool> hasPendingInvite() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefKey) != null;
}

Future<void> _forgetInvite() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefKey);
}

String _newToken() {
  const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(28, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Super Admin: creates a new invite for [clubId] and returns its link.
Future<String> createClubInvite({
  required String clubId,
  required String clubName,
  required String byUid,
  required String byName,
}) async {
  final token = _newToken();
  await FirebaseFirestore.instance.collection('club_invites').doc(token).set({
    'clubId': clubId,
    'clubName': clubName,
    'createdBy': byUid,
    'createdByName': byName,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(DateTime.now().add(inviteValidity)),
    'usedBy': null,
    'usedAt': null,
  });
  return inviteLink(token);
}

/// Super Admin: creates the link and shows it with a copy button.
Future<void> showCreateInviteDialog(
  BuildContext context, {
  required String clubId,
  required String clubName,
  required String byUid,
  required String byName,
}) async {
  String link;
  try {
    link = await createClubInvite(clubId: clubId, clubName: clubName, byUid: byUid, byName: byName);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.red,
        content: Text('Δεν δημιουργήθηκε ο σύνδεσμος: $e'),
      ));
    }
    return;
  }
  if (!context.mounted) return;
  final message = 'Γεια σας! Αυτός είναι ο σύνδεσμος για να γίνετε διαχειριστής του '
      'συλλόγου «$clubName» στο Clubera. Ανοίξτε τον, συνδεθείτε ή κάντε εγγραφή '
      'και πατήστε «Αποδοχή». Ισχύει ${inviteValidity.inDays} ημέρες, για ένα άτομο.\n$link';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text('Πρόσκληση Admin — $clubName', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Στείλτε αυτό το μήνυμα στον υπεύθυνο του συλλόγου (Viber, WhatsApp, email). '
            'Ο σύνδεσμος ισχύει 14 ημέρες και για ένα μόνο άτομο.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SelectableText(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ο σύνδεσμος αντιγράφηκε')));
            }
          },
          child: const Text('Αντιγραφή συνδέσμου'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Το μήνυμα αντιγράφηκε')));
            }
          },
          child: const Text('Αντιγραφή μηνύματος', style: TextStyle(color: AppTheme.supportGreen)),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Κλείσιμο')),
      ],
    ),
  );
}

// On the web the invite reaches the app twice at start-up (the address bar
// and the initial deep link). Only one check may run at a time, otherwise the
// second dialog tries to accept an invite the first one has just used.
bool _checking = false;

/// Signed-in user: if an invite is waiting, asks them to accept it.
Future<void> checkPendingInvite(BuildContext context, UserModel user) async {
  if (_checking) return;
  _checking = true;
  try {
    await _checkPendingInvite(context, user);
  } finally {
    _checking = false;
  }
}

Future<void> _checkPendingInvite(BuildContext context, UserModel user) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_prefKey);
  if (token == null) return;
  final db = FirebaseFirestore.instance;

  DocumentSnapshot<Map<String, dynamic>> snap;
  try {
    snap = await db.collection('club_invites').doc(token).get();
  } catch (_) {
    await _forgetInvite();
    if (context.mounted) _info(context, 'Η πρόσκληση δεν βρέθηκε. Ζητήστε νέο σύνδεσμο από το Clubera.');
    return;
  }
  final inv = snap.data();
  if (inv == null) {
    await _forgetInvite();
    if (context.mounted) _info(context, 'Η πρόσκληση δεν βρέθηκε. Ζητήστε νέο σύνδεσμο από το Clubera.');
    return;
  }
  final clubId = inv['clubId'] as String;
  final clubName = '${inv['clubName'] ?? ''}';
  if (inv['usedBy'] == user.uid) {
    await _forgetInvite(); // accepted already (e.g. the page was reloaded)
    return;
  }
  if (inv['usedBy'] != null) {
    await _forgetInvite();
    if (context.mounted) _info(context, 'Η πρόσκληση για «$clubName» έχει ήδη χρησιμοποιηθεί. Ζητήστε νέο σύνδεσμο από το Clubera.');
    return;
  }
  final expires = (inv['expiresAt'] as Timestamp?)?.toDate();
  if (expires != null && expires.isBefore(DateTime.now())) {
    await _forgetInvite();
    if (context.mounted) _info(context, 'Η πρόσκληση για «$clubName» έληξε. Ζητήστε νέο σύνδεσμο από το Clubera.');
    return;
  }
  if (user.role == 'admin') {
    await _forgetInvite();
    if (context.mounted) {
      _info(context, 'Είστε συνδεδεμένοι ως Super Admin. Ανοίξτε τον σύνδεσμο με τον λογαριασμό του υπεύθυνου του συλλόγου.');
    }
    return;
  }
  if (!context.mounted) return;

  final accept = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Πρόσκληση από το Clubera', style: TextStyle(color: Colors.white)),
      content: Text(
        'Γίνεστε διαχειριστής (Club Admin) του συλλόγου «$clubName».\n\n'
        'Θα μπορείτε να ανεβάζετε το ρόστερ και το λογότυπο και να ενημερώνετε τη σελίδα του συλλόγου.'
        '${user.clubId != null && user.clubId != clubId ? '\n\nΟ λογαριασμός σας θα συνδεθεί με αυτόν τον σύλλογο αντί για τον τωρινό.' : ''}',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι τώρα')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Αποδοχή', style: TextStyle(color: AppTheme.supportGreen, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (accept != true) {
    // Kept: the invite is offered again next time the app opens.
    return;
  }

  try {
    await acceptClubInvite(token: token, clubId: clubId, userId: user.uid);
    await _forgetInvite();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.supportGreen,
        duration: const Duration(seconds: 6),
        content: Text('Είστε πλέον Admin του «$clubName». Profile → Πίνακας συλλόγου → Παίκτες → Excel για το ρόστερ.'),
      ));
    }
  } catch (e) {
    if (context.mounted) _info(context, 'Η αποδοχή απέτυχε: $e');
  }
}

/// One batch, so either everything happens or nothing.
Future<void> acceptClubInvite({
  required String token,
  required String clubId,
  required String userId,
}) async {
  final db = FirebaseFirestore.instance;
  final clubRef = db.collection('clubs').doc(clubId);
  final club = (await clubRef.get()).data() ?? const <String, dynamic>{};
  final previous = club['adminUid'] as String?;
  final staff = List<String>.from(club['staffUids'] ?? const []);
  if (previous != null && previous.isNotEmpty && previous != userId && !staff.contains(previous)) {
    staff.add(previous);
  }
  final batch = db.batch();
  batch.update(db.collection('club_invites').doc(token), {
    'usedBy': userId,
    'usedAt': FieldValue.serverTimestamp(),
  });
  batch.update(db.collection('users').doc(userId), {
    'role': 'club',
    'clubId': clubId,
    'inviteToken': token,
  });
  batch.update(clubRef, {
    'adminUid': userId,
    'staffUids': staff,
  });
  await batch.commit();
}

void _info(BuildContext context, String text) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      content: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
