import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/tournament_model.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  int _step = 0;
  bool _loading = false;

  // Step 1: Basic info
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController(text: '2025');
  String _format = 'groups_knockout';
  int _groupCount = 2;

  // Step 2: Teams
  final List<TournamentTeam> _teams = [];
  final _teamNameCtrl = TextEditingController();
  List<ClubModel> _foundClubs = [];
  bool _searching = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _seasonCtrl.dispose();
    _teamNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchClubs(String q) async {
    if (q.trim().length < 2) {
      setState(() => _foundClubs = []);
      return;
    }
    setState(() => _searching = true);
    final end = q.substring(0, q.length - 1) +
        String.fromCharCode(q.codeUnitAt(q.length - 1) + 1);
    final snap = await FirebaseFirestore.instance
        .collection('clubs')
        .orderBy('name')
        .startAt([q])
        .endAt([end])
        .limit(8)
        .get();
    if (mounted) {
      setState(() {
        _foundClubs = snap.docs
            .map((d) => ClubModel.fromMap(d.data(), d.id))
            .where((c) => _teams.every((t) => t.id != c.id))
            .toList();
        _searching = false;
      });
    }
  }

  void _addClub(ClubModel c) {
    setState(() {
      _teams.add(TournamentTeam(id: c.id, name: c.name, logoUrl: c.logoUrl));
      _foundClubs.remove(c);
      _teamNameCtrl.clear();
    });
  }

  void _addCustomTeam() {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _teams.add(TournamentTeam(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
      ));
      _teamNameCtrl.clear();
      _foundClubs = [];
    });
  }

  int get _knockoutTeams {
    if (_format == 'groups_knockout') {
      // teams that advance: 2 per group (winner + runner-up)
      return _groupCount * 2;
    }
    return _teams.length;
  }

  int get _totalRounds {
    final n = _knockoutTeams;
    if (n <= 0) return 0;
    return (log(n) / log(2)).ceil();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (_teams.length < 2) return;
    setState(() => _loading = true);
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('tournaments').doc();
      final tournament = TournamentModel(
        id: ref.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        season: _seasonCtrl.text.trim(),
        format: _format,
        status: 'setup',
        createdBy: user.uid,
        createdByClubId: user.clubId,
        teams: _teams,
        groupCount: _format == 'knockout' ? 1 : _groupCount,
        totalRounds: _totalRounds,
        createdAt: DateTime.now(),
      );
      await ref.set(tournament.toMap());

      // Generate fixtures
      final matchesRef = ref.collection('matches');
      final batch = FirebaseFirestore.instance.batch();

      if (_format == 'groups' || _format == 'groups_knockout') {
        // Split teams into groups and generate round-robin
        final grouped = _splitIntoGroups(_teams, _groupCount);
        for (var g = 0; g < grouped.length; g++) {
          final groupName = 'Group ${String.fromCharCode(65 + g)}';
          final groupTeams = grouped[g];
          // Round-robin
          for (var i = 0; i < groupTeams.length; i++) {
            for (var j = i + 1; j < groupTeams.length; j++) {
              final doc = matchesRef.doc();
              batch.set(doc, {
                'phase': 'group',
                'groupName': groupName,
                'bracketRound': -1,
                'bracketPosition': -1,
                'homeTeamId': groupTeams[i].id,
                'homeTeamName': groupTeams[i].name,
                'awayTeamId': groupTeams[j].id,
                'awayTeamName': groupTeams[j].name,
                'homeScore': 0,
                'awayScore': 0,
                'status': 'scheduled',
                'winnerId': null,
                'winnerName': null,
              });
            }
          }
        }
        if (_format == 'groups') {
          // No knockout — done
        }
      }

      if (_format == 'knockout') {
        // Generate bracket from teams
        _generateKnockoutMatches(batch, matchesRef, _teams, _totalRounds);
      } else if (_format == 'groups_knockout') {
        // Pre-generate knockout slots with TBD teams
        final n = _knockoutTeams;
        final r = _totalRounds;
        _generateKnockoutMatchesTBD(batch, matchesRef, n, r);
      }

      await batch.commit();

      // Start the tournament immediately if all is set up
      await ref.update({'status': _format == 'groups' || _format == 'groups_knockout' ? 'groups' : 'knockout'});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Το τουρνουά δημιουργήθηκε!'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  List<List<TournamentTeam>> _splitIntoGroups(
      List<TournamentTeam> teams, int groupCount) {
    final groups = List.generate(groupCount, (_) => <TournamentTeam>[]);
    for (var i = 0; i < teams.length; i++) {
      groups[i % groupCount].add(teams[i]);
    }
    return groups;
  }

  void _generateKnockoutMatches(WriteBatch batch,
      CollectionReference ref, List<TournamentTeam> seeds, int totalRounds) {
    final numFirst = pow(2, totalRounds - 1).toInt();
    for (var pos = 0; pos < numFirst; pos++) {
      final hi = pos * 2;
      final ai = pos * 2 + 1;
      final doc = ref.doc();
      batch.set(doc, {
        'phase': 'knockout',
        'groupName': null,
        'bracketRound': 0,
        'bracketPosition': pos,
        'homeTeamId': hi < seeds.length ? seeds[hi].id : 'tbd',
        'homeTeamName': hi < seeds.length ? seeds[hi].name : 'TBD',
        'awayTeamId': ai < seeds.length ? seeds[ai].id : 'tbd',
        'awayTeamName': ai < seeds.length ? seeds[ai].name : 'TBD',
        'homeScore': 0,
        'awayScore': 0,
        'status': 'scheduled',
        'winnerId': null,
        'winnerName': null,
      });
    }
    // Subsequent rounds with TBD
    for (var round = 1; round < totalRounds; round++) {
      final count = pow(2, totalRounds - round - 1).toInt();
      for (var pos = 0; pos < count; pos++) {
        final doc = ref.doc();
        batch.set(doc, {
          'phase': 'knockout',
          'groupName': null,
          'bracketRound': round,
          'bracketPosition': pos,
          'homeTeamId': 'tbd',
          'homeTeamName': 'TBD',
          'awayTeamId': 'tbd',
          'awayTeamName': 'TBD',
          'homeScore': 0,
          'awayScore': 0,
          'status': 'tbd',
          'winnerId': null,
          'winnerName': null,
        });
      }
    }
  }

  void _generateKnockoutMatchesTBD(WriteBatch batch,
      CollectionReference ref, int totalTeams, int totalRounds) {
    for (var round = 0; round < totalRounds; round++) {
      final count = pow(2, totalRounds - round - 1).toInt();
      for (var pos = 0; pos < count; pos++) {
        final doc = ref.doc();
        batch.set(doc, {
          'phase': 'knockout',
          'groupName': null,
          'bracketRound': round,
          'bracketPosition': pos,
          'homeTeamId': 'tbd',
          'homeTeamName': 'TBD',
          'awayTeamId': 'tbd',
          'awayTeamName': 'TBD',
          'homeScore': 0,
          'awayScore': 0,
          'status': 'tbd',
          'winnerId': null,
          'winnerName': null,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Νέο Τουρνουά'),
        backgroundColor: Colors.transparent,
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (s) => setState(() => _step = s),
        onStepContinue: () {
          if (_step == 0) {
            if (_nameCtrl.text.trim().isEmpty) return;
            setState(() => _step = 1);
          } else if (_step == 1) {
            if (_teams.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Πρόσθεσε τουλάχιστον 2 ομάδες'),
                backgroundColor: AppTheme.red,
              ));
              return;
            }
            setState(() => _step = 2);
          } else {
            _create();
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step--);
        },
        connectorColor: WidgetStateProperty.all(AppTheme.primaryLight),
        steps: [
          Step(
            title: const Text('Πληροφορίες'),
            isActive: _step >= 0,
            content: _buildStep1(),
          ),
          Step(
            title: const Text('Ομάδες'),
            isActive: _step >= 1,
            content: _buildStep2(),
          ),
          Step(
            title: const Text('Επισκόπηση'),
            isActive: _step >= 2,
            content: _buildStep3(),
          ),
        ],
        controlsBuilder: (ctx, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : details.onStepContinue,
                child: _loading && _step == 2
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_step == 2 ? 'Δημιουργία' : 'Επόμενο'),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Πίσω', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Όνομα τουρνουά *',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardBg2,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Περιγραφή (προαιρετικό)',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardBg2,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _seasonCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Σεζόν',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardBg2,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Φορμά', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        ...[
          ('knockout', 'Νοκ-Άουτ', 'Απευθείας αποκλεισμός από την αρχή'),
          ('groups', 'Όμιλοι', 'Μόνο φάση ομίλων (βαθμολογία)'),
          ('groups_knockout', 'Όμιλοι + Νοκ-Άουτ', 'Φάση ομίλων → προκριματικά'),
        ].map((f) => RadioListTile<String>(
              value: f.$1,
              groupValue: _format,
              title: Text(f.$2, style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(f.$3, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              onChanged: (v) => setState(() => _format = v!),
              activeColor: AppTheme.primaryLight,
              contentPadding: EdgeInsets.zero,
            )),
        if (_format != 'knockout') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Αριθμός ομίλων:', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(width: 16),
              ...List.generate(4, (i) {
                final n = i + 2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _groupCount == n,
                    onSelected: (_) => setState(() => _groupCount = n),
                    selectedColor: AppTheme.primaryLight,
                    backgroundColor: AppTheme.cardBg2,
                    labelStyle: TextStyle(
                      color: _groupCount == n ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _teamNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Αναζήτηση ή πληκτρολόγησε όνομα...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardBg2,
                ),
                onChanged: (v) {
                  _searchClubs(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _addCustomTeam,
              tooltip: 'Προσθήκη ως νέα ομάδα',
            ),
          ],
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: AppTheme.primaryLight),
          ),
        if (_foundClubs.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...(_foundClubs.take(5).map((c) => ListTile(
                tileColor: AppTheme.cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.cardBg2,
                  backgroundImage: safeNetworkImage(c.logoUrl),
                  child: safeNetworkImage(c.logoUrl) == null
                      ? Text(c.name[0], style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: const Icon(Icons.add_circle, color: AppTheme.supportGreen),
                onTap: () => _addClub(c),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              ))),
        ],
        const SizedBox(height: 12),
        if (_teams.isNotEmpty) ...[
          Text('Ομάδες (${_teams.length})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          ..._teams.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                      backgroundImage: safeNetworkImage(e.value.logoUrl),
                      child: safeNetworkImage(e.value.logoUrl) == null
                          ? Text('${e.key + 1}',
                              style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value.name, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    GestureDetector(
                      onTap: () => setState(() => _teams.removeAt(e.key)),
                      child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    final formatLabel = {
      'knockout': 'Νοκ-Άουτ',
      'groups': 'Φάση Ομίλων',
      'groups_knockout': 'Όμιλοι + Νοκ-Άουτ',
    }[_format] ?? _format;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewRow('Όνομα', _nameCtrl.text),
        _reviewRow('Φορμά', formatLabel),
        _reviewRow('Σεζόν', _seasonCtrl.text),
        if (_format != 'knockout') _reviewRow('Όμιλοι', '$_groupCount'),
        _reviewRow('Ομάδες', '${_teams.length}'),
        if (_format != 'groups') _reviewRow('Φάσεις Νοκ-Άουτ', '$_totalRounds (${_roundLabel(_totalRounds)})'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.supportGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.supportGreen.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.supportGreen, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Τα fixtures θα δημιουργηθούν αυτόματα. Μπορείς να εισάγεις αποτελέσματα από το detail screen.',
                  style: TextStyle(color: AppTheme.supportGreen, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _roundLabel(int rounds) {
    if (rounds <= 1) return 'Τελικός';
    if (rounds == 2) return 'Ημιτελικός + Τελικός';
    if (rounds == 3) return 'Προημιτελικός + Ημιτελικός + Τελικός';
    return '$rounds γύροι';
  }
}
