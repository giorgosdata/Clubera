// Club Admin screen: upload the club's roster from Excel/CSV plus the logo.
// The Club Admin was verified when the club was claimed, so the upload is
// published at once; the Super Admin sees it in Admin → Ρόστερ.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/save_file.dart';
import 'roster_file.dart';
import 'roster_parser.dart';
import 'roster_service.dart';

class RosterUploadScreen extends StatefulWidget {
  final String clubId;
  const RosterUploadScreen({super.key, required this.clubId});

  @override
  State<RosterUploadScreen> createState() => _RosterUploadScreenState();
}

class _RosterUploadScreenState extends State<RosterUploadScreen> {
  final _service = RosterService();

  String? _fileName;
  RosterParseResult? _parsed;
  RosterPlan? _plan;
  String? _fileError;
  bool _reading = false;

  Uint8List? _logoBytes;
  String? _logoName;
  String? _logoWarning;

  bool _declared = false;
  bool _submitting = false;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    try {
      final bytes = Uint8List.fromList(buildRosterTemplate());
      // Browser: downloads the file. Phones: share sheet (save, email, …).
      await saveBytesAsFile(
        bytes,
        'Clubera_roster_protypo.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        subject: 'Πρότυπο ρόστερ Clubera — συμπληρώστε το φύλλο «Ρόστερ».',
      );
    } catch (e) {
      _snack('Δεν φτιάχτηκε το πρότυπο: $e', error: true);
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    setState(() {
      _reading = true;
      _fileName = f.name;
      _parsed = null;
      _plan = null;
      _fileError = null;
    });
    try {
      var bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) throw const FormatException('Το αρχείο δεν διαβάστηκε.');
      final table = readRosterFile(bytes, f.name);
      final parsed = parseRoster(table);
      RosterPlan? plan;
      if (parsed.fileErrors.isEmpty && parsed.validRows.isNotEmpty) {
        plan = await _service.plan(widget.clubId, parsed.validRows);
      }
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _plan = plan;
        _fileError = parsed.fileErrors.isEmpty ? null : parsed.fileErrors.join('\n');
      });
    } on FormatException catch (e) {
      setState(() => _fileError = e.message);
    } catch (e) {
      setState(() => _fileError = 'Σφάλμα ανάγνωσης: $e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      _snack('Το λογότυπο είναι μεγαλύτερο από 2 MB.', error: true);
      return;
    }
    final lower = x.name.toLowerCase();
    if (!(lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
      _snack('Το λογότυπο πρέπει να είναι PNG ή JPG.', error: true);
      return;
    }
    String? warning;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      final w = img.width, h = img.height;
      if (w < 512 || h < 512) {
        warning = 'Μικρή ανάλυση ($w×$h). Προτείνεται τουλάχιστον 512×512.';
      } else if ((w - h).abs() > (w > h ? w : h) * 0.1) {
        warning = 'Δεν είναι τετράγωνο ($w×$h). Μπορεί να κοπεί στις άκρες.';
      }
    } catch (_) {
      _snack('Η εικόνα δεν ανοίγει.', error: true);
      return;
    }
    setState(() {
      _logoBytes = bytes;
      _logoName = x.name;
      _logoWarning = warning;
    });
  }

  Future<void> _submit() async {
    final user = context.read<AppProvider>().user;
    final plan = _plan;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      String? logoUrl;
      if (_logoBytes != null) {
        logoUrl = await _service.uploadPendingLogo(widget.clubId, _logoBytes!, _logoName ?? 'logo.png');
      }
      await _service.submit(
        clubId: widget.clubId,
        plan: plan ?? const RosterPlan([]),
        byUid: user.uid,
        byName: user.name,
        pendingLogoUrl: logoUrl,
      );
      await _service.approve(widget.clubId, byName: user.name, result: 'published');
      if (!mounted) return;
      setState(() {
        _parsed = null;
        _plan = null;
        _fileName = null;
        _logoBytes = null;
        _logoName = null;
        _logoWarning = null;
        _declared = false;
      });
      _snack('Δημοσιεύτηκε. Το ρόστερ φαίνεται πλέον στο Clubera.');
    } catch (e) {
      _snack('Η αποστολή απέτυχε: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelPending() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Ακύρωση ανεβάσματος;'),
        content: const Text(
            'Οι παίκτες και το λογότυπο αυτού του ανεβάσματος θα διαγραφούν. Οι ήδη δημοσιευμένοι παίκτες δεν αλλάζουν.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ακύρωση ανεβάσματος', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final user = context.read<AppProvider>().user;
    try {
      await _service.reject(widget.clubId, byName: user?.name ?? '', cancelledByClub: true);
      _snack('Το ανέβασμα ακυρώθηκε.');
    } catch (e) {
      _snack('Η ακύρωση απέτυχε: $e', error: true);
    }
  }

  /// Finishes an upload left pending (e.g. the connection dropped between
  /// saving and publishing).
  Future<void> _publishPending() async {
    final user = context.read<AppProvider>().user;
    try {
      await _service.approve(widget.clubId, byName: user?.name ?? '', result: 'published');
      _snack('Δημοσιεύτηκε. Το ρόστερ φαίνεται πλέον στο Clubera.');
    } catch (e) {
      _snack('Η δημοσίευση απέτυχε: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.red : AppTheme.supportGreen,
    ));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Ανέβασμα ρόστερ'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).snapshots(),
        builder: (ctx, snap) {
          final club = snap.data?.data() ?? const <String, dynamic>{};
          final pending = club['rosterStatus'] == 'pending';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text('${club['name'] ?? ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              _StatusCard(club: club, onCancel: _cancelPending, onPublish: _publishPending),
              if (!pending) ...[
                _step(
                  1,
                  'Κατεβάστε το πρότυπο Excel',
                  'Μία γραμμή ανά παίκτη στο φύλλο «Ρόστερ». Οι οδηγίες είναι στο φύλλο «Οδηγίες».',
                  OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Πρότυπο Excel'),
                  ),
                ),
                _step(
                  2,
                  'Ανεβάστε το συμπληρωμένο αρχείο',
                  'Excel (.xlsx) ή CSV. Ελέγχουμε κάθε γραμμή πριν αποθηκευτεί οτιδήποτε.',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.icon(
                        onPressed: _reading ? null : _pickFile,
                        icon: _reading
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file),
                        label: Text(_fileName == null ? 'Επιλογή αρχείου' : 'Άλλο αρχείο'),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(height: 6),
                        Text(_fileName!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (_fileError != null) _errorBox(_fileError!),
                if (_parsed != null && _fileError == null) _preview(),
                _step(
                  3,
                  'Λογότυπο συλλόγου (προαιρετικό)',
                  'PNG ή JPG, έως 2 MB, τετράγωνο, τουλάχιστον 512×512.',
                  Row(
                    children: [
                      if (_logoBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.memory(_logoBytes!, width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_logoBytes == null ? 'Επιλογή λογότυπου' : 'Αλλαγή'),
                      ),
                      if (_logoBytes != null)
                        IconButton(
                          tooltip: 'Αφαίρεση',
                          onPressed: () => setState(() {
                            _logoBytes = null;
                            _logoName = null;
                            _logoWarning = null;
                          }),
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (_logoWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Text(_logoWarning!, style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                _declaration(),
                const SizedBox(height: 12),
                _submitButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _step(int n, String title, String subtitle, Widget action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.primaryLight,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.red.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          ],
        ),
      );

  Widget _preview() {
    final parsed = _parsed!;
    final plan = _plan;
    final invalid = parsed.invalidRows;
    final byLine = {for (final i in plan?.items ?? const <RosterPlanItem>[]) i.row.line: i};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Προεπισκόπηση', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Νέοι', plan?.newCount ?? 0, AppTheme.supportGreen),
              _chip('Αλλαγές', plan?.updateCount ?? 0, AppTheme.primaryLight),
              _chip('Χωρίς αλλαγή', plan?.unchangedCount ?? 0, AppTheme.textSecondary),
              _chip('Με λάθη', invalid.length, AppTheme.red),
            ],
          ),
          if (invalid.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Οι γραμμές με λάθη δεν θα ανέβουν. Διορθώστε τες στο Excel και ανεβάστε ξανά το αρχείο, ή στείλτε μόνο τις σωστές.',
              style: TextStyle(color: AppTheme.red.withValues(alpha: 0.9), fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppTheme.divider),
          for (final r in parsed.rows) _rowTile(r, byLine[r.line]),
        ],
      ),
    );
  }

  Widget _chip(String label, int n, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label: $n', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _rowTile(RosterRow r, RosterPlanItem? item) {
    final (icon, color, tag) = !r.isValid
        ? (Icons.error_outline, AppTheme.red, 'Λάθος')
        : switch (item?.action) {
            RosterAction.update => (Icons.edit_outlined, AppTheme.primaryLight, 'Αλλαγή'),
            RosterAction.unchanged => (Icons.check, AppTheme.textSecondary, 'Ίδιο'),
            _ => (Icons.add_circle_outline, AppTheme.supportGreen, 'Νέος'),
          };
    final details = [
      if (r.position != null) r.position!,
      if (r.number != null) '#${r.number}',
      r.squad.label,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name.isEmpty ? 'Γραμμή ${r.line}' : r.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text('Γρ. ${r.line} · $details',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                if (r.isMinorOn(DateTime.now()))
                  const Text('Ανήλικος · δημόσια μόνο όνομα και θέση',
                      style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                for (final e in r.errors)
                  Text('• $e', style: const TextStyle(color: AppTheme.red, fontSize: 11)),
              ],
            ),
          ),
          Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _declaration() => InkWell(
        onTap: () => setState(() => _declared = !_declared),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: _declared, onChanged: (v) => setState(() => _declared = v ?? false)),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Δηλώνω ότι ο σύλλογος έχει τη συγκατάθεση των παικτών και, για ανήλικους, των γονέων τους, για να εμφανίζονται στο Clubera. Για τους ανήλικους εμφανίζονται δημόσια μόνο όνομα και θέση.',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _submitButton() {
    final plan = _plan;
    final changes = (plan?.newCount ?? 0) + (plan?.updateCount ?? 0);
    final hasSomething = changes > 0 || _logoBytes != null;
    final enabled = hasSomething && _declared && !_submitting && !_reading;
    String label;
    if (!hasSomething) {
      label = 'Επιλέξτε αρχείο ή λογότυπο';
    } else if (!_declared) {
      label = 'Επιβεβαιώστε τη δήλωση συγκατάθεσης';
    } else {
      final parts = [
        if (changes > 0) '$changes παίκτες',
        if (_logoBytes != null) 'λογότυπο',
      ];
      label = 'Δημοσίευση (${parts.join(' + ')})';
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppTheme.supportGreen),
        onPressed: enabled ? _submit : null,
        child: _submitting
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onCancel;
  final VoidCallback onPublish;
  const _StatusCard({required this.club, required this.onCancel, required this.onPublish});

  @override
  Widget build(BuildContext context) {
    final status = club['rosterStatus'] as String?;
    if (status == null) return const SizedBox.shrink();
    final upload = (club['rosterUpload'] as Map?) ?? const {};
    final at = upload['at'] is Timestamp ? (upload['at'] as Timestamp).toDate() : null;
    final when = at == null ? '' : DateFormat('d/M/yyyy HH:mm').format(at);
    late final Color color;
    late final IconData icon;
    late final String title;
    String body = '';
    switch (status) {
      case 'pending':
        color = AppTheme.accent;
        icon = Icons.hourglass_top;
        title = 'Δεν έχει δημοσιευτεί ακόμα';
        body = '${upload['newCount'] ?? 0} νέοι παίκτες, ${upload['updateCount'] ?? 0} αλλαγές'
            '${club['pendingLogoUrl'] != null ? ', νέο λογότυπο' : ''}'
            '${when.isEmpty ? '' : ' · $when'}';
        break;
      case 'rejected':
        color = AppTheme.red;
        icon = Icons.cancel_outlined;
        title = 'Το τελευταίο ανέβασμα απορρίφθηκε';
        body = (club['rosterRejectReason'] as String?) ?? 'Διορθώστε το αρχείο και ανεβάστε το ξανά.';
        break;
      case 'undone':
        color = AppTheme.red;
        icon = Icons.undo;
        title = 'Το τελευταίο ανέβασμα αναιρέθηκε από το Clubera';
        body = 'Οι παίκτες και το λογότυπο επανήλθαν όπως ήταν πριν. Ελέγξτε το αρχείο και ανεβάστε το ξανά.';
        break;
      default:
        color = AppTheme.supportGreen;
        icon = Icons.verified_outlined;
        title = 'Το τελευταίο ρόστερ δημοσιεύτηκε';
        body = when;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 6),
            const Text(
              'Μέχρι να δημοσιευτεί, οι νέοι παίκτες και το λογότυπο φαίνονται μόνο εδώ, όχι στους fans. Δημοσιεύστε το ή ακυρώστε το για νέο ανέβασμα.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Ακύρωση ανεβάσματος', style: TextStyle(color: AppTheme.red)),
                ),
                TextButton(
                  onPressed: onPublish,
                  child: const Text('Δημοσίευση', style: TextStyle(color: AppTheme.supportGreen)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
