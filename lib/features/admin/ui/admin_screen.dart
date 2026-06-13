import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/user_model.dart';
import '../../../models/club_model.dart';
import '../../../models/match_model.dart';
import '../../../models/donation_model.dart';
import '../../../models/player_model.dart';
import '../../../models/reward_model.dart';
import '../../../models/game_model.dart';
import '../../../models/news_model.dart';
import 'trivia_admin_screen.dart';
import 'sponsors_management.dart';
import '../../matches/ui/create_match_screen.dart';
import '../../clubs/ui/create_club_screen.dart' show CreateClubScreen, kCountryList, generateInviteCode;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 12, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    if (user?.role != 'admin') {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: AppTheme.surface),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.cardBg2),
              SizedBox(height: 16),
              Text('Access Denied', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('You do not have permission to view this page.', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppTheme.accent, size: 22),
            SizedBox(width: 8),
            Text('Admin Panel'),
          ],
        ),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Dashboard'),
            Tab(text: 'Users'),
            Tab(text: 'Clubs'),
            Tab(text: 'Matches'),
            Tab(text: 'Payments'),
            Tab(text: 'Actions'),
            Tab(text: 'Players'),
            Tab(text: 'Games'),
            Tab(text: 'Rewards'),
            Tab(text: 'News'),
            Tab(text: 'Sponsors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ClubRequestsTab(),
          _DashboardTab(tabController: _tab),
          _UsersTab(),
          _ClubsTab(),
          _MatchesTab(),
          _PaymentsTab(),
          _ActionsTab(),
          _AllPlayersTab(),
          _AdminGamesTab(),
          _AdminRewardsTab(),
          _AdminNewsTab(),
          _AdminSponsorsTab(),
        ],
      ),
    );
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final TabController? tabController;
  const _DashboardTab({this.tabController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  collection: 'users',
                  label: 'Users',
                  icon: Icons.people,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  collection: 'clubs',
                  label: 'Clubs',
                  icon: Icons.shield,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  collection: 'matches',
                  label: 'Matches',
                  icon: Icons.sports_soccer,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _LiveMatchCard()),
            ],
          ),
          const SizedBox(height: 12),
          _SponsorsDashCard(onManage: () => tabController?.animateTo(11)),
          const SizedBox(height: 24),
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _RecentUsers(),
        ],
      ),
    );
  }
}

class _SponsorsDashCard extends StatelessWidget {
  final VoidCallback? onManage;
  const _SponsorsDashCard({this.onManage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sponsors').snapshots(),
      builder: (ctx, snap) {
        final total = snap.data?.docs.length ?? 0;
        final global = snap.data?.docs
                .where((d) => (d.data() as Map)['clubId'] == null)
                .length ??
            0;
        final club = total - global;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.handshake_outlined, color: Colors.amber, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sponsors',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total total · $global app · $club club',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Manage →'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  final String collection;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.collection,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  late final Future<AggregateQuerySnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseFirestore.instance.collection(widget.collection).count().get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: _future,
      builder: (context, snap) {
        final count = snap.data?.count ?? 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: widget.color, size: 28),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  color: widget.color,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', whereIn: ['live', 'halftime'])
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.liveRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, color: AppTheme.liveRed, size: 28),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: const TextStyle(
                  color: AppTheme.liveRed,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Live Now',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentUsers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final users = (snap.data?.docs ?? [])
            .map(
              (d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        return Column(
          children: users
              .map((u) => _UserRow(user: u, showActions: false))
              .toList(),
        );
      },
    );
  }
}

// ─── USERS ────────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: ['all', 'fan', 'club', 'admin']
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filter == 'all'
                ? FirebaseFirestore.instance
                      .collection('users')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                : FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: _filter)
                      .snapshots(),
            builder: (context, snap) {
              final users = (snap.data?.docs ?? [])
                  .map(
                    (d) => UserModel.fromMap(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList();
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'No users',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) =>
                    _UserRow(user: users[i], showActions: true),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserModel user;
  final bool showActions;
  const _UserRow({required this.user, required this.showActions});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role == 'admin'
        ? AppTheme.accent
        : user.role == 'club'
        ? AppTheme.primaryLight
        : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.cardBg2,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                color: roleColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              color: AppTheme.cardBg2,
              icon: const Icon(
                Icons.more_vert,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onSelected: (v) => _handleAction(context, v, user),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'fan',
                  child: Text(
                    'Set as Fan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: 'club',
                  child: Text(
                    'Set as Club',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: 'admin',
                  child: Text(
                    'Set as Admin',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete User',
                    style: TextStyle(color: AppTheme.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action, UserModel user) async {
    if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text(
            'Delete User?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Delete ${user.name}?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    } else {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'role': action,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} is now $action')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update role: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    }
  }
}

// ─── CLUBS ────────────────────────────────────────────────────────────────────

const _kClubFilters = ['All', 'Α΄ Ομάδα', 'Β΄ Ομάδα', 'Γυναικεία'];

class _ClubsTab extends StatefulWidget {
  const _ClubsTab();

  @override
  State<_ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<_ClubsTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        tooltip: 'Add Club',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateClubScreen())),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _kClubFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _kClubFilters[i];
                final selected = _filter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  selectedColor: AppTheme.accent,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                final allClubs = (snap.data?.docs ?? [])
                    .map(
                      (d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id),
                    )
                    .toList();
                final clubs = _filter == 'All'
                    ? allClubs
                    : allClubs.where((c) => c.category == _filter).toList();
                if (clubs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No clubs in this category',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: clubs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _ClubRow(club: clubs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  final ClubModel club;
  const _ClubRow({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardBg2,
              shape: BoxShape.circle,
              image: safeNetworkImage(club.logoUrl) != null
                  ? DecorationImage(
                      image: safeNetworkImage(club.logoUrl)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: safeNetworkImage(club.logoUrl) == null
                ? const Icon(
                    Icons.sports_soccer,
                    color: AppTheme.primaryLight,
                    size: 22,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${club.city} • ${club.country}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${club.category} • ${club.league} • ${club.followers} followers',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppTheme.cardBg2,
            icon: const Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onSelected: (v) {
              if (v == 'delete') _deleteClub(context, club);
              if (v == 'edit') _editClub(context, club);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Club', style: TextStyle(color: Colors.white))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete Club', style: TextStyle(color: AppTheme.red))),
            ],
          ),
        ],
      ),
    );
  }

  void _editClub(BuildContext context, ClubModel club) {
    final nameCtrl = TextEditingController(text: club.name);
    final cityCtrl = TextEditingController(text: club.city);
    final leagueCtrl = TextEditingController(text: club.league);
    final logoCtrl = TextEditingController(text: club.logoUrl ?? '');
    String selCategory = kCategories.contains(club.category) ? club.category : kCategories.first;
    String selCountry = kCountryList.contains(club.country) ? club.country : kCountryList.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Edit Club', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Club Name')),
                const SizedBox(height: 10),
                TextField(controller: cityCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'City')),
                const SizedBox(height: 10),
                TextField(controller: leagueCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'League')),
                const SizedBox(height: 10),
                TextField(controller: logoCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Logo URL')),
                const SizedBox(height: 14),
                const Text('Category', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: kCategories.map((cat) => ChoiceChip(
                    label: Text(cat),
                    selected: selCategory == cat,
                    selectedColor: AppTheme.primaryLight,
                    labelStyle: TextStyle(
                      color: selCategory == cat ? Colors.white : AppTheme.textSecondary,
                      fontWeight: selCategory == cat ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setDlg(() => selCategory = cat),
                  )).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Country', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selCountry,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    items: kCountryList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDlg(() => selCountry = v!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('clubs').doc(club.id).update({
                  'name': nameCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'league': leagueCtrl.text.trim(),
                  'logoUrl': logoCtrl.text.trim().isEmpty ? null : logoCtrl.text.trim(),
                  'category': selCategory,
                  'country': selCountry,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      cityCtrl.dispose();
      leagueCtrl.dispose();
      logoCtrl.dispose();
    });
  }

  void _deleteClub(BuildContext context, ClubModel club) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Delete Club?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete ${club.name}? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(club.id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── MATCHES ─────────────────────────────────────────────────────────────────

class _MatchesTab extends StatefulWidget {
  const _MatchesTab();

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryLight,
        tooltip: 'Create Match',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMatchScreen())),
        child: const Icon(Icons.add),
      ),
      body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: ['all', 'live', 'upcoming', 'finished']
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filter == 'all'
                ? FirebaseFirestore.instance
                      .collection('matches')
                      .orderBy('scheduledAt', descending: true)
                      .snapshots()
                : FirebaseFirestore.instance
                      .collection('matches')
                      .where('status', isEqualTo: _filter)
                      .snapshots(),
            builder: (context, snap) {
              final matches = (snap.data?.docs ?? [])
                  .map(
                    (d) => MatchModel.fromMap(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList();
              if (matches.isEmpty) {
                return const Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _MatchRow(match: matches[i]),
              );
            },
          ),
        ),
      ],
    ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final MatchModel match;
  const _MatchRow({required this.match});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (match.status) {
      case 'live':
        statusColor = AppTheme.liveRed;
        break;
      case 'finished':
        statusColor = AppTheme.textSecondary;
        break;
      default:
        statusColor = AppTheme.primaryLight;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.homeClubName} vs ${match.awayClubName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  match.league,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (!match.isUpcoming)
                  Text(
                    '${match.homeScore} – ${match.awayScore}',
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              match.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: AppTheme.cardBg2,
            icon: const Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onSelected: (v) {
              if (v == 'delete') _deleteMatch(context, match);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Match',
                  style: TextStyle(color: AppTheme.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _deleteMatch(BuildContext context, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Delete Match?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${match.homeClubName} vs ${match.awayClubName}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('matches')
                  .doc(match.id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── PAYMENTS TAB ─────────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final donations = (snap.data?.docs ?? [])
            .map((d) => DonationModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        final total = donations.fold<double>(0.0, (s, d) => s + d.amount);

        if (donations.isEmpty) {
          return const Center(child: Text('No payments yet', style: TextStyle(color: AppTheme.textSecondary)));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.euro, color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Payments', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('€${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      Text('${donations.length} transactions', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('ALL TRANSACTIONS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...donations.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
              child: Row(
                children: [
                  Text(d.typeEmoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${d.clubName} • ${d.typeLabel}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        Text(DateFormat('d MMM yyyy, HH:mm').format(d.createdAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('+€${d.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.supportGreen, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}

// ─── ACTIONS TAB ──────────────────────────────────────────────────────────────

class _ActionsTab extends StatelessWidget {
  const _ActionsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('RECENT REGISTRATIONS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).limit(8).snapshots(),
          builder: (ctx, snap) {
            final users = (snap.data?.docs ?? []).map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
            return Column(
              children: users.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: AppTheme.primaryLight, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(u.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(u.role, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('RECENT PAYMENTS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations').orderBy('createdAt', descending: true).limit(8).snapshots(),
          builder: (ctx, snap) {
            final donations = (snap.data?.docs ?? []).map((d) => DonationModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
            if (donations.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No payments yet', style: TextStyle(color: AppTheme.textSecondary))));
            return Column(
              children: donations.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Text(d.typeEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d.userName} → ${d.clubName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(DateFormat('d MMM yyyy').format(d.createdAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    )),
                    Text('+€${d.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.supportGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('RECENT MATCHES', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').orderBy('scheduledAt', descending: true).limit(8).snapshots(),
          builder: (ctx, snap) {
            final matches = (snap.data?.docs ?? []).map((d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
            if (matches.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No matches yet', style: TextStyle(color: AppTheme.textSecondary))));
            return Column(
              children: matches.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.sports_soccer, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${m.homeClubName} vs ${m.awayClubName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('${m.league} • ${m.status.toUpperCase()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    )),
                  ],
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── ALL PLAYERS TAB ──────────────────────────────────────────────────────────

class _AllPlayersTab extends StatelessWidget {
  const _AllPlayersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (context, clubSnap) {
        if (clubSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clubsById = {
          for (final d in clubSnap.data?.docs ?? [])
            d.id: ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id),
        };
        if (clubsById.isEmpty) {
          return const Center(child: Text('No clubs yet', style: TextStyle(color: AppTheme.textSecondary)));
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('players')
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final byClub = <String, List<PlayerModel>>{};
            for (final d in snap.data?.docs ?? []) {
              final clubId = d.reference.parent.parent?.id;
              if (clubId == null || !clubsById.containsKey(clubId)) continue;
              final player = PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id);
              if (!player.isActive) continue;
              byClub.putIfAbsent(clubId, () => []).add(player);
            }
            final sections = byClub.entries
                .where((e) => e.value.isNotEmpty)
                .toList()
              ..sort((a, b) => clubsById[a.key]!.name.compareTo(clubsById[b.key]!.name));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: sections
                  .map((e) => _ClubPlayersSection(
                        club: clubsById[e.key]!,
                        players: e.value,
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }
}

class _ClubPlayersSection extends StatelessWidget {
  final ClubModel club;
  final List<PlayerModel> players;
  const _ClubPlayersSection({required this.club, required this.players});

  @override
  Widget build(BuildContext context) {
    final logo = safeNetworkImage(club.logoUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (logo != null)
                CircleAvatar(radius: 14, backgroundImage: logo)
              else
                const CircleAvatar(radius: 14, backgroundColor: AppTheme.cardBg2, child: Icon(Icons.sports_soccer, size: 14, color: AppTheme.primaryLight)),
              const SizedBox(width: 8),
              Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              Text('(${players.length})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        ...players.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(color: AppTheme.cardBg2, shape: BoxShape.circle),
                child: Center(child: Text(p.number != null ? '${p.number}' : p.position, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(8)),
                child: Text(p.position, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
        const Divider(color: AppTheme.divider),
      ],
    );
  }
}

// ─── ADMIN GAMES TAB ──────────────────────────────────────────────────────────

class _AdminGamesTab extends StatelessWidget {
  const _AdminGamesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('New Game'),
        onPressed: () => _showAddGameDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('games').snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Σφάλμα: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = (snap.data?.docs ?? [])
              .map((d) => GameModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (games.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videogame_asset_outlined, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No games yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Tap + to create one', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _GameAdminRow(game: games[i]),
          );
        },
      ),
    );
  }

  static void _showAddGameDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '5');
    final maxCtrl = TextEditingController(text: '50');
    final limitCtrl = TextEditingController(text: '1');
    String type = 'spin_wheel';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Νέο Παιχνίδι', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Τύπος', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: const [
                    {'v': 'spin_wheel', 'l': '🎡 Τυχερός Τροχός'},
                    {'v': 'scratch_card', 'l': '🎫 Ξυστό'},
                    {'v': 'daily_bonus', 'l': '🎁 Ημερήσιο Bonus'},
                    {'v': 'trivia', 'l': '🧠 Trivia'},
                  ].map((e) {
                    final selected = type == e['v'];
                    return ChoiceChip(
                      label: Text(e['l']!),
                      selected: selected,
                      selectedColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setS(() => type = e['v']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Τίτλος'),
                ),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Περιγραφή'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Min points'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Max points'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Daily limit (πόσες φορές ανά ημέρα)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Title required')),
                  );
                  return;
                }
                final minP = int.tryParse(minCtrl.text) ?? 1;
                final maxP = int.tryParse(maxCtrl.text) ?? 100;
                final limit = int.tryParse(limitCtrl.text) ?? 1;
                if (minP > maxP) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Min cannot exceed Max')),
                  );
                  return;
                }
                try {
                  await FirebaseFirestore.instance.collection('games').add(
                        GameModel(
                          id: '',
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          type: type,
                          minPoints: minP,
                          maxPoints: maxP,
                          dailyLimit: limit,
                          createdAt: DateTime.now(),
                        ).toMap(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
      minCtrl.dispose();
      maxCtrl.dispose();
      limitCtrl.dispose();
    });
  }
}

class _GameAdminRow extends StatelessWidget {
  final GameModel game;
  const _GameAdminRow({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: game.type == 'trivia'
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TriviaAdminScreen(
                    gameId: game.id,
                    gameTitle: game.title,
                  ),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(game.typeEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    game.typeLabel,
                    style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    game.type == 'trivia'
                        ? 'Tap to manage questions'
                        : '${game.minPoints}–${game.maxPoints} pts • ${game.dailyLimit}/day',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardBg,
                  title: const Text('Delete Game', style: TextStyle(color: Colors.white)),
                  content: Text('Delete "${game.title}"? This cannot be undone.',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        FirebaseFirestore.instance.collection('games').doc(game.id).delete();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ADMIN REWARDS TAB ────────────────────────────────────────────────────────

class _AdminRewardsTab extends StatelessWidget {
  const _AdminRewardsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('Add Game'),
        onPressed: () => _showAddRewardDialog(context, null, null),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rewards')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Σφάλμα: ${snap.error}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rewards = (snap.data?.docs ?? [])
              .map((d) => RewardModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (rewards.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No games yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Tap + to create a game', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          final global = rewards.where((r) => r.isGlobal).toList();
          final club = rewards.where((r) => !r.isGlobal).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (global.isNotEmpty) ...[
                const _RewardSectionLabel('APP GAMES (global)'),
                const SizedBox(height: 8),
                ...global.map((r) => _RewardAdminCard(reward: r)),
                const SizedBox(height: 20),
              ],
              if (club.isNotEmpty) ...[
                const _RewardSectionLabel('CLUB GAMES'),
                const SizedBox(height: 8),
                ...club.map((r) => _RewardAdminCard(reward: r)),
              ],
            ],
          );
        },
      ),
    );
  }

  static void _showAddRewardDialog(BuildContext context, String? clubId, String? clubName) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pointsCtrl = TextEditingController();
    String emoji = '🎁';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            clubId == null ? 'Add Global Game' : 'Add Club Game',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['🎁', '🏆', '⭐', '🎟️', '👕', '🎮', '💰', '🔥']
                      .map((e) => GestureDetector(
                            onTap: () => setS(() => emoji = e),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: emoji == e ? AppTheme.primaryLight.withValues(alpha: 0.3) : AppTheme.cardBg2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 20)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(controller: pointsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Points Cost', suffixText: 'pts')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || pointsCtrl.text.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('rewards').add(
                    RewardModel(
                      id: '',
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      pointsCost: int.tryParse(pointsCtrl.text) ?? 0,
                      emoji: emoji,
                      clubId: clubId,
                      clubName: clubName,
                      createdAt: DateTime.now(),
                    ).toMap(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create game: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
      pointsCtrl.dispose();
    });
  }
}

class _RewardSectionLabel extends StatelessWidget {
  final String text;
  const _RewardSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

class _RewardAdminCard extends StatelessWidget {
  final RewardModel reward;
  const _RewardAdminCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: reward.isGlobal ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(reward.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                if (reward.description.isNotEmpty)
                  Text(reward.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (reward.clubName != null)
                  Text('Club: ${reward.clubName}', style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('${reward.pointsCost} pts', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('Delete Reward', style: TextStyle(color: Colors.white)),
                    content: Text('Delete "${reward.title}"? This cannot be undone.',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                        onPressed: () {
                          Navigator.pop(ctx);
                          FirebaseFirestore.instance.collection('rewards').doc(reward.id).delete();
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
                child: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CLUB REQUESTS TAB ────────────────────────────────────────────────────────

class _ClubRequestsTab extends StatelessWidget {
  const _ClubRequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('club_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        final requests = docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList()
          ..sort((a, b) {
            final aT = (a['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
            final bT = (b['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
            return bT.compareTo(aT);
          });

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Club applications will appear here',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final r = requests[i];
            final createdAt = (r['createdAt'] as dynamic)?.toDate() as DateTime?;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt != null)
                        Text(
                          DateFormat('d MMM yyyy').format(createdAt),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r['clubName'] ?? '-',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_city_outlined, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${r['city'] ?? '-'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                      const Icon(Icons.emoji_events_outlined, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${r['league'] ?? '-'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r['category'] ?? 'K14',
                          style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${r['userName'] ?? '-'}  •  ${r['userEmail'] ?? '-'}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  if ((r['description'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      r['description'],
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            side: const BorderSide(color: AppTheme.red),
                          ),
                          onPressed: () => _reject(ctx, r['id'] as String),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.supportGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _approve(ctx, r),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, Map<String, dynamic> r) async {
    if (r['status'] == 'approved') return;
    final reqId = r['id'] as String;
    final userId = r['userId'] as String;

    try {
      final db = FirebaseFirestore.instance;
      final clubRef = db.collection('clubs').doc();
      final batch = db.batch();
      batch.set(clubRef, {
        'name': r['clubName'] ?? '',
        'city': r['city'] ?? '',
        'country': r['country'] ?? 'Greece',
        'league': r['league'] ?? '',
        'category': r['category'] ?? 'K14',
        'description': r['description'] ?? '',
        'adminUid': userId,
        'followers': 0,
        'votes': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'logoUrl': null,
        'coverUrl': null,
        'inviteCode': generateInviteCode(),
        'staffUids': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('users').doc(userId), {
        'role': 'club',
        'clubId': clubRef.id,
      });
      batch.update(db.collection('club_requests').doc(reqId), {
        'status': 'approved',
        'clubId': clubRef.id,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${r['clubName']}" approved!'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  void _reject(BuildContext context, String reqId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Reject Application?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The applicant will see their request as rejected.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('club_requests')
                  .doc(reqId)
                  .update({
                'status': 'rejected',
                'rejectedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ─── ADMIN NEWS TAB ──────────────────────────────────────────────────────────

class _AdminNewsTab extends StatelessWidget {
  const _AdminNewsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('Νέο Άρθρο'),
        onPressed: () => _showEditor(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('publishedAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Σφάλμα: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final articles = (snap.data?.docs ?? [])
              .map((d) => NewsModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          if (articles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No articles yet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: articles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final n = articles[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    if (safeNetworkImage(n.imageUrl) != null)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: safeNetworkImage(n.imageUrl)!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article, color: AppTheme.textSecondary),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(n.excerpt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          Text(DateFormat('d MMM yyyy').format(n.publishedAt),
                              style: const TextStyle(color: AppTheme.accent, fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.accent, size: 18),
                      onPressed: () => _showEditor(context, existing: n),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('news')
                          .doc(n.id)
                          .delete(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void _showEditor(BuildContext context, {NewsModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final excerptCtrl = TextEditingController(text: existing?.excerpt ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final authorCtrl = TextEditingController(text: existing?.author ?? 'Clubera');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(existing == null ? 'Νέο Άρθρο' : 'Επεξεργασία Άρθρου',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Τίτλος'),
              ),
              TextField(
                controller: excerptCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Σύντομη περίληψη'),
              ),
              TextField(
                controller: bodyCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 8,
                maxLength: 3000,
                decoration: const InputDecoration(labelText: 'Κείμενο'),
              ),
              TextField(
                controller: imageCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Image URL (optional)'),
              ),
              TextField(
                controller: authorCtrl,
                style: const TextStyle(color: Colors.white),
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Συγγραφέας'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || excerptCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Title and excerpt required')),
                );
                return;
              }
              final data = {
                'title': titleCtrl.text.trim(),
                'excerpt': excerptCtrl.text.trim(),
                'body': bodyCtrl.text.trim(),
                'imageUrl': imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                'author': authorCtrl.text.trim().isEmpty ? 'Clubera' : authorCtrl.text.trim(),
                'publishedAt': existing?.publishedAt ?? DateTime.now(),
                'clubId': null,
                'tags': const <String>[],
              };
              try {
                if (existing == null) {
                  await FirebaseFirestore.instance.collection('news').add(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('news')
                      .doc(existing.id)
                      .update(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
                  );
                }
              }
            },
            child: Text(existing == null ? 'Publish' : 'Save'),
          ),
        ],
      ),
    ).then((_) {
      titleCtrl.dispose();
      excerptCtrl.dispose();
      bodyCtrl.dispose();
      imageCtrl.dispose();
      authorCtrl.dispose();
    });
  }
}

// ─── ADMIN SPONSORS TAB ──────────────────────────────────────────────────────

class _AdminSponsorsTab extends StatelessWidget {
  const _AdminSponsorsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'App Sponsors',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => showAddSponsorSheet(context),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Sponsors that appear app-wide (no specific club).',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SponsorsList(showOnlyGlobal: true),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Club Sponsors',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                  ),
                  onPressed: () => showAddSponsorSheet(
                    context,
                    allowClubPicker: true,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Sponsors attached to a specific club.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SponsorsList(showOnlyClubScoped: true),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
