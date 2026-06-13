import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/player_model.dart';

class PlayerCompareScreen extends StatefulWidget {
  final String clubId;
  final PlayerModel playerA;
  const PlayerCompareScreen({
    super.key,
    required this.clubId,
    required this.playerA,
  });

  @override
  State<PlayerCompareScreen> createState() => _PlayerCompareScreenState();
}

class _PlayerCompareScreenState extends State<PlayerCompareScreen> {
  PlayerModel? _playerB;
  List<PlayerModel> _others = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final snap = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('players')
        .where('isActive', isEqualTo: true)
        .get();
    final players = snap.docs
        .map((d) => PlayerModel.fromMap(d.data(), d.id))
        .where((p) => p.id != widget.playerA.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (mounted) setState(() { _others = players; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Σύγκριση Παικτών'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_playerB != null)
            TextButton(
              onPressed: () => setState(() => _playerB = null),
              child: const Text('Αλλαγή', style: TextStyle(color: AppTheme.primaryLight)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _playerB == null
              ? _buildPicker()
              : _buildComparison(),
    );
  }

  Widget _buildPicker() {
    if (_others.isEmpty) {
      return const Center(
        child: Text(
          'Δεν υπάρχουν άλλοι παίκτες για σύγκριση',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Επίλεξε παίκτη για σύγκριση με ${widget.playerA.name}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _others.length,
            itemBuilder: (ctx, i) {
              final p = _others[i];
              final posColor = _posColor(p.position);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppTheme.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: posColor.withValues(alpha: 0.15),
                    backgroundImage: safeNetworkImage(p.photoUrl),
                    child: safeNetworkImage(p.photoUrl) == null
                        ? Text(
                            p.position,
                            style: TextStyle(
                              color: posColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    p.positionLabel,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.compare_arrows, color: AppTheme.textSecondary, size: 18),
                  onTap: () => setState(() => _playerB = p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    final a = widget.playerA;
    final b = _playerB!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header row
        Row(
          children: [
            Expanded(child: _PlayerHeader(player: a, align: TextAlign.left)),
            const SizedBox(width: 8),
            const Text('VS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: _PlayerHeader(player: b, align: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 20),
        _CompareRow(
          label: 'Γκολ',
          icon: Icons.sports_soccer,
          valA: a.goals,
          valB: b.goals,
          color: AppTheme.supportGreen,
        ),
        _CompareRow(
          label: 'Συμμετοχές',
          icon: Icons.sports,
          valA: a.appearances,
          valB: b.appearances,
          color: AppTheme.primaryLight,
        ),
        _CompareRow(
          label: 'Κίτρινες Κάρτες',
          icon: Icons.square,
          valA: a.yellowCards,
          valB: b.yellowCards,
          color: AppTheme.accent,
          lowerIsBetter: true,
        ),
        _CompareRow(
          label: 'Κόκκινες Κάρτες',
          icon: Icons.square,
          valA: a.redCards,
          valB: b.redCards,
          color: AppTheme.red,
          lowerIsBetter: true,
        ),
      ],
    );
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }
}

class _PlayerHeader extends StatelessWidget {
  final PlayerModel player;
  final TextAlign align;
  const _PlayerHeader({required this.player, required this.align});

  @override
  Widget build(BuildContext context) {
    final posColor = _posColor(player.position);
    final isLeft = align == TextAlign.left;
    return Column(
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: posColor.withValues(alpha: 0.15),
          backgroundImage: safeNetworkImage(player.photoUrl),
          child: safeNetworkImage(player.photoUrl) == null
              ? Text(
                  player.position,
                  style: TextStyle(color: posColor, fontWeight: FontWeight.bold, fontSize: 12),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          player.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          player.positionLabel,
          style: TextStyle(color: posColor, fontSize: 11),
          textAlign: align,
        ),
      ],
    );
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int valA;
  final int valB;
  final Color color;
  final bool lowerIsBetter;
  const _CompareRow({
    required this.label,
    required this.icon,
    required this.valA,
    required this.valB,
    required this.color,
    this.lowerIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = valA + valB;
    final aWins = total == 0 ? false : (lowerIsBetter ? valA < valB : valA > valB);
    final bWins = total == 0 ? false : (lowerIsBetter ? valB < valA : valB > valA);
    final flexA = total == 0 ? 1 : (valA == 0 ? 0 : ((valA / total) * 100).round());
    final flexB = total == 0 ? 1 : (valB == 0 ? 0 : ((valB / total) * 100).round());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$valA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: aWins ? color : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: flexA > 0 ? flexA : 1,
                          child: Container(
                            height: 8,
                            color: aWins ? color : color.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: flexB > 0 ? flexB : 1,
                          child: Container(
                            height: 8,
                            color: bWins ? color : color.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$valB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: bWins ? color : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
