import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/match_model.dart';
import '../../../models/player_model.dart';

class MatchOperatorScreen extends StatefulWidget {
  final String matchId;
  const MatchOperatorScreen({super.key, required this.matchId});

  @override
  State<MatchOperatorScreen> createState() => _MatchOperatorScreenState();
}

class _MatchOperatorScreenState extends State<MatchOperatorScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _updateStatus(String status, {String? minute}) async {
    try {
      await _db.collection('matches').doc(widget.matchId).update({
        'status': status,
        if (minute != null) 'minute': minute,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  Future<void> _addGoal(MatchModel match, String clubId) async {
    final minuteCtrl = TextEditingController();
    final playerCtrl = TextEditingController();
    try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Add Goal', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: playerCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Player name',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minuteCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Minute (e.g. 45)",
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final batch = _db.batch();
      final matchRef = _db.collection('matches').doc(widget.matchId);
      final eventRef = matchRef.collection('events').doc();

      final isHome = clubId == match.homeClubId;
      batch.update(matchRef, {
        if (isHome)
          'homeScore': FieldValue.increment(1)
        else
          'awayScore': FieldValue.increment(1),
        'minute': minuteCtrl.text,
      });
      batch.set(eventRef, {
        'type': 'goal',
        'clubId': clubId,
        'playerName': playerCtrl.text.trim().isEmpty
            ? 'Unknown'
            : playerCtrl.text.trim(),
        'minute': minuteCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
    } finally {
      minuteCtrl.dispose();
      playerCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Match Operator'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('matches').doc(widget.matchId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Σφάλμα: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            );
          }
          if (!snap.hasData || snap.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final match = MatchModel.fromMap(
            snap.data!.data() as Map<String, dynamic>,
            widget.matchId,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScoreBoard(match),
                const SizedBox(height: 24),
                _buildStatusControls(match),
                const SizedBox(height: 24),
                _buildLineupButtons(match),
                const SizedBox(height: 24),
                _buildGoalButtons(match),
                const SizedBox(height: 24),
                _buildCardButtons(match),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreBoard(MatchModel match) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        _statusChip(match.status),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Text(
                match.homeClubName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${match.homeScore}  –  ${match.awayScore}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                match.awayClubName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'live':
        color = AppTheme.liveRed;
        label = 'LIVE';
        break;
      case 'halftime':
        color = Colors.orange;
        label = 'HALF TIME';
        break;
      case 'finished':
        color = AppTheme.textSecondary;
        label = 'FINISHED';
        break;
      default:
        color = AppTheme.cardBg2;
        label = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusControls(MatchModel match) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Match Control',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      if (match.isFinished)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Match finished. View only — no further changes.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        )
      else
      Row(
        children: [
          if (match.status == 'upcoming')
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Kick Off'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                ),
                onPressed: () => _updateStatus('live', minute: '1'),
              ),
            ),
          if (match.status == 'live') ...[
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.pause),
                label: const Text('Half Time'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => _updateStatus('halftime'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flag),
                label: const Text('Full Time'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textSecondary,
                ),
                onPressed: () => _confirmFullTime(match),
              ),
            ),
          ],
          if (match.status == 'halftime')
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('2nd Half'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                ),
                onPressed: () => _updateStatus('live', minute: '46'),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _buildLineupButtons(MatchModel match) {
    if (match.isFinished) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lineup',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: Text(
                  match.homeLineup.isEmpty
                      ? '${match.homeClubName} lineup'
                      : '${match.homeClubName} (${match.homeLineup.length})',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LineupPickerScreen(
                      matchId: widget.matchId,
                      clubId: match.homeClubId,
                      clubName: match.homeClubName,
                      isHome: true,
                      initialFormation: match.homeFormation ?? '4-3-3',
                      initialLineup: match.homeLineup,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: Text(
                  match.awayLineup.isEmpty
                      ? '${match.awayClubName} lineup'
                      : '${match.awayClubName} (${match.awayLineup.length})',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LineupPickerScreen(
                      matchId: widget.matchId,
                      clubId: match.awayClubId,
                      clubName: match.awayClubName,
                      isHome: false,
                      initialFormation: match.awayFormation ?? '4-4-2',
                      initialLineup: match.awayLineup,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalButtons(MatchModel match) {
    if (match.isFinished || match.status == 'upcoming') {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Goals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sports_soccer),
                label: Text(
                  match.homeClubName,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _addGoal(match, match.homeClubId),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sports_soccer),
                label: Text(
                  match.awayClubName,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _addGoal(match, match.awayClubId),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardButtons(MatchModel match) {
    if (match.isFinished || match.status == 'upcoming') {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Events',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _eventButton(match, 'yellow_card', Colors.amber, Icons.square, 'Yellow'),
            _eventButton(match, 'red_card', AppTheme.red, Icons.square, 'Red'),
            _eventButton(match, 'penalty', AppTheme.accent, Icons.sports_soccer, 'Penalty'),
            _eventButton(match, 'foul', AppTheme.liveRed, Icons.warning_amber, 'Foul'),
            _eventButton(match, 'offside', Colors.deepPurple, Icons.flag_outlined, 'Offside'),
            _eventButton(match, 'corner', AppTheme.primaryLight, Icons.crop_din, 'Corner'),
            _eventButton(match, 'throw_in', AppTheme.textSecondary, Icons.swap_horiz, 'Throw-in'),
            _eventButton(match, 'goal_cancelled', AppTheme.red, Icons.cancel_outlined, 'Goal cancelled'),
            _eventButton(match, 'substitution', AppTheme.supportGreen, Icons.swap_vert, 'Substitution'),
          ],
        ),
      ],
    );
  }

  Widget _eventButton(MatchModel match, String type, Color color, IconData icon, String label) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: color, size: 16),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: color)),
      onPressed: () => _addEvent(match, type),
    );
  }

  Future<void> _addEvent(MatchModel match, String type) async {
    final playerCtrl = TextEditingController();
    final playerInCtrl = TextEditingController();
    final minuteCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String selectedClub = match.homeClubId;

    final needsPlayer = type != 'corner' && type != 'throw_in';
    final isSubstitution = type == 'substitution';
    final isCancelled = type == 'goal_cancelled';

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: Text(
              _eventLabel(type),
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedClub,
                    dropdownColor: AppTheme.cardBg,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: match.homeClubId,
                        child: Text(match.homeClubName, style: const TextStyle(color: Colors.white)),
                      ),
                      DropdownMenuItem(
                        value: match.awayClubId,
                        child: Text(match.awayClubName, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                    onChanged: (v) => setS(() => selectedClub = v!),
                  ),
                  if (needsPlayer && !isSubstitution)
                    TextField(
                      controller: playerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Player name',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  if (isSubstitution) ...[
                    TextField(
                      controller: playerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Player OUT',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    TextField(
                      controller: playerInCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Player IN',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                  if (isCancelled)
                    TextField(
                      controller: reasonCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Reason (VAR/offside/etc)',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  TextField(
                    controller: minuteCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Minute',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      try {
        await _db
            .collection('matches')
            .doc(widget.matchId)
            .collection('events')
            .add({
              'type': type,
              'clubId': selectedClub,
              'playerName': playerCtrl.text.trim().isEmpty ? null : playerCtrl.text.trim(),
              if (isSubstitution) 'playerIn': playerInCtrl.text.trim().isEmpty ? null : playerInCtrl.text.trim(),
              if (isCancelled) 'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
              'minute': minuteCtrl.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add event: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    } finally {
      playerCtrl.dispose();
      playerInCtrl.dispose();
      minuteCtrl.dispose();
      reasonCtrl.dispose();
    }
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'yellow_card': return 'Yellow Card';
      case 'red_card': return 'Red Card';
      case 'penalty': return 'Penalty';
      case 'foul': return 'Foul';
      case 'offside': return 'Offside';
      case 'corner': return 'Corner';
      case 'throw_in': return 'Throw-in';
      case 'goal_cancelled': return 'Goal Cancelled (VAR)';
      case 'substitution': return 'Substitution';
      default: return 'Event';
    }
  }

  Future<void> _confirmFullTime(MatchModel match) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('End Match?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Final score: ${match.homeScore} – ${match.awayScore}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Match'),
          ),
        ],
      ),
    );
    if (ok == true) await _updateStatus('finished');
  }
}

// ─── LINEUP PICKER ────────────────────────────────────────────────────────────

const Map<String, int> _kFormationSlots = {
  '4-3-3': 11,
  '4-4-2': 11,
  '3-5-2': 11,
  '4-2-3-1': 11,
};

class _LineupPickerScreen extends StatefulWidget {
  final String matchId;
  final String clubId;
  final String clubName;
  final bool isHome;
  final String initialFormation;
  final List<Map<String, dynamic>> initialLineup;
  const _LineupPickerScreen({
    required this.matchId,
    required this.clubId,
    required this.clubName,
    required this.isHome,
    required this.initialFormation,
    required this.initialLineup,
  });

  @override
  State<_LineupPickerScreen> createState() => _LineupPickerScreenState();
}

class _LineupPickerScreenState extends State<_LineupPickerScreen> {
  late String _formation;
  // Map slot index → player {name, number, position, playerId}
  final List<Map<String, dynamic>?> _slots = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _formation = widget.initialFormation;
    final size = _kFormationSlots[_formation] ?? 11;
    _slots.addAll(List<Map<String, dynamic>?>.generate(size, (i) {
      if (i < widget.initialLineup.length) return widget.initialLineup[i];
      return null;
    }));
  }

  void _setFormation(String formation) {
    setState(() {
      _formation = formation;
      final size = _kFormationSlots[formation] ?? 11;
      final existing = List<Map<String, dynamic>?>.from(_slots);
      _slots
        ..clear()
        ..addAll(List<Map<String, dynamic>?>.generate(
          size,
          (i) => i < existing.length ? existing[i] : null,
        ));
    });
  }

  Future<void> _pickPlayer(int slot, List<PlayerModel> roster) async {
    final picked = await showModalBottomSheet<PlayerModel?>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.clear, color: AppTheme.red),
              title: const Text('Clear slot', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, null),
            ),
            const Divider(color: AppTheme.divider, height: 1),
            ...roster.map((p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.cardBg2,
                    child: Text(
                      p.number?.toString() ?? p.position,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(p.positionLabel,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, p),
                )),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (picked == null) {
        _slots[slot] = null;
      } else {
        _slots[slot] = {
          'name': picked.name,
          'number': picked.number,
          'position': picked.position,
          'playerId': picked.id,
        };
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final lineup = _slots.whereType<Map<String, dynamic>>().toList();
    try {
      await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).update({
        widget.isHome ? 'homeLineup' : 'awayLineup': lineup,
        widget.isHome ? 'homeFormation' : 'awayFormation': _formation,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${widget.clubName} lineup'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, color: AppTheme.supportGreen),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('players')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final roster = (snap.data?.docs ?? [])
              .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .where((p) => p.isActive)
              .toList()
            ..sort((a, b) {
              final n1 = a.number ?? 999;
              final n2 = b.number ?? 999;
              return n1.compareTo(n2);
            });
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formation',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _kFormationSlots.keys.map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _formation == f,
                        selectedColor: AppTheme.primaryLight,
                        labelStyle: TextStyle(
                          color: _formation == f ? Colors.white : AppTheme.textSecondary,
                          fontWeight: _formation == f ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => _setFormation(f),
                      )).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tap a slot to pick a player',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...List.generate(_slots.length, (i) {
                  final p = _slots[i];
                  return Card(
                    color: AppTheme.cardBg,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p == null ? AppTheme.cardBg2 : AppTheme.primaryLight,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p == null ? 'Empty slot' : p['name'] ?? '—',
                        style: TextStyle(
                          color: p == null ? AppTheme.textSecondary : Colors.white,
                        ),
                      ),
                      subtitle: p == null
                          ? null
                          : Text(
                              '#${p['number'] ?? '—'} • ${p['position'] ?? '—'}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => _pickPlayer(i, roster),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
