import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/tournament_model.dart';
import 'create_tournament_screen.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatelessWidget {
  final bool showAppBar;
  const TournamentsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final canCreate = user?.role == 'club' || user?.role == 'admin';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: showAppBar
          ? AppBar(title: const Text('Τουρνουά'), backgroundColor: Colors.transparent)
          : null,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryLight,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 72, color: AppTheme.cardBg2),
                  const SizedBox(height: 16),
                  const Text('Δεν υπάρχουν τουρνουά ακόμα',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  if (canCreate) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Δημιούργησε το πρώτο', style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final t = TournamentModel.fromMap(
                docs[i].data() as Map<String, dynamic>, docs[i].id);
              return _TournamentCard(tournament: t);
            },
          );
        },
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  const _TournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final statusColor = {
      'setup': AppTheme.textSecondary,
      'groups': AppTheme.primaryLight,
      'knockout': AppTheme.accent,
      'finished': AppTheme.supportGreen,
    }[t.status] ?? AppTheme.textSecondary;
    final statusLabel = {
      'setup': 'Προετοιμασία',
      'groups': 'Φάση Ομίλων',
      'knockout': 'Νοκ-Άουτ',
      'finished': 'Ολοκληρώθηκε',
    }[t.status] ?? t.status;
    final formatLabel = {
      'knockout': 'Νοκ-Άουτ',
      'groups': 'Φάση Ομίλων',
      'groups_knockout': 'Όμιλοι + Νοκ-Άουτ',
    }[t.format] ?? t.format;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: t.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${t.season} • $formatLabel',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(Icons.groups, '${t.teams.length} ομάδες'),
                const SizedBox(width: 8),
                if (t.hasGroups) _chip(Icons.table_chart_outlined, '${t.groupCount} όμιλοι'),
                if (t.hasKnockout) ...[
                  const SizedBox(width: 8),
                  _chip(Icons.account_tree_outlined, _roundsLabel(t.totalRounds)),
                ],
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy').format(t.createdAt),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      );

  String _roundsLabel(int rounds) {
    if (rounds <= 1) return 'Τελικός';
    if (rounds == 2) return 'Ημιτελικά';
    if (rounds == 3) return 'Προημιτελικά';
    return '$rounds γύροι';
  }
}
