import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/logo_picker.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/academy_model.dart';
import '../../../models/donation_model.dart';
import '../../../models/player_model.dart';
import '../../matches/ui/create_match_screen.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../clubs/ui/create_club_screen.dart' show kCountryList, CreateClubScreen;
import '../../admin/ui/sponsors_management.dart';
import '../../admin/ui/trivia_admin_screen.dart';
import '../../clubs/ui/announcements_tab.dart';
import '../../../models/game_model.dart';
import '../../../models/prize_model.dart';

class ClubAdminScreen extends StatefulWidget {
  const ClubAdminScreen({super.key});

  @override
  State<ClubAdminScreen> createState() => _ClubAdminScreenState();
}

class _ClubAdminScreenState extends State<ClubAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 13, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;

    if (user?.role != 'club' && user?.role != 'admin') {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: AppTheme.surface),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.cardBg2),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to view this page.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final clubId = user?.clubId;

    if (clubId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Club Admin'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 64, color: AppTheme.cardBg2),
                const SizedBox(height: 16),
                const Text(
                  'Δεν έχεις ομάδα ακόμα',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Για να μπορέσεις να προσθέσεις παίκτες, ακαδημίες, μεταγραφές ή ανταμοιβές, πρέπει πρώτα να φτιάξεις την ομάδα σου.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.supportGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Φτιάξε Ομάδα'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.dashboard, color: AppTheme.supportGreen, size: 20),
            SizedBox(width: 8),
            Text('Club Panel'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: AppTheme.accent),
            tooltip: 'View as Fan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubProfileScreen(clubId: clubId),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.supportGreen,
          labelColor: AppTheme.supportGreen,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Players'),
            Tab(text: 'Academies'),
            Tab(text: 'Revenue'),
            Tab(text: 'Fans'),
            Tab(text: 'Transfers'),
            Tab(text: 'Staff'),
            Tab(text: 'Sponsors'),
            Tab(text: 'Παιχνίδια'),
            Tab(text: 'Ανακοινώσεις'),
            Tab(text: 'Γκαλερί'),
            Tab(text: 'Γυναίκες'),
            Tab(text: 'Γήπεδο'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(clubId: clubId, tabController: _tab),
          _PlayersTab(clubId: clubId),
          _AcademiesTab(clubId: clubId),
          _RevenueTab(clubId: clubId),
          _FansTab(clubId: clubId),
          _TransfersTab(clubId: clubId),
          _StaffTab(clubId: clubId),
          _ClubSponsorsTab(clubId: clubId),
          _ClubGamesTab(clubId: clubId),
          AnnouncementsTab(
            clubId: clubId,
            canAdmin: true,
            authorName: user?.name ?? 'Club Admin',
          ),
          _GalleryAdminTab(clubId: clubId),
          _WomenAdminTab(clubId: clubId),
          _StadiumPhotosAdminTab(clubId: clubId),
        ],
      ),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final String clubId;
  final TabController? tabController;
  const _OverviewTab({required this.clubId, this.tabController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.data!.exists) {
          return const Center(
            child: Text(
              'Club not found',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        final club = ClubModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          clubId,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Club header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
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
                            size: 32,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${club.city} • ${club.league}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${club.category} • ${club.country}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    tooltip: 'Edit Club',
                    onPressed: () => _showEditClubDialog(ctx, club),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: 'Followers',
                  value: '${club.followers}',
                  icon: Icons.people,
                  color: AppTheme.primaryLight,
                ),
                _StatCard(
                  label: 'Fan Votes',
                  value: '${club.votes}',
                  icon: Icons.how_to_vote,
                  color: AppTheme.accent,
                ),
                _StatCard(
                  label: 'Wins',
                  value: '${club.wins}',
                  icon: Icons.emoji_events,
                  color: AppTheme.supportGreen,
                ),
                _StatCard(
                  label: 'Played',
                  value: '${club.played}',
                  icon: Icons.sports_soccer,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // W/D/L row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Season Record',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RecordChip(
                        label: 'W',
                        count: club.wins,
                        color: AppTheme.supportGreen,
                      ),
                      _RecordChip(
                        label: 'D',
                        count: club.draws,
                        color: AppTheme.accent,
                      ),
                      _RecordChip(
                        label: 'L',
                        count: club.losses,
                        color: AppTheme.red,
                      ),
                      _RecordChip(
                        label: 'Pts',
                        count: club.points,
                        color: AppTheme.primaryLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Revenue snapshot — uses aggregate sum to avoid downloading
            // all donation documents.
            FutureBuilder<AggregateQuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('donations')
                  .where('clubId', isEqualTo: clubId)
                  .aggregate(sum('amount'))
                  .get(),
              builder: (ctx, snap) {
                final total = snap.data?.getSum('amount') ?? 0.0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.euro, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Revenue',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '€${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Create Match button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.supportGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Sponsors shortcut
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.handshake_outlined),
                label: const Text(
                  'Manage Sponsors',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => tabController?.animateTo(7),
              ),
            ),
            const SizedBox(height: 10),
            // Post to Feed
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryLight,
                  side: const BorderSide(color: AppTheme.primaryLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text(
                  'Post to Feed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => _showPostFeedSheet(ctx, clubId),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPostFeedSheet(BuildContext context, String clubId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostFeedSheet(clubId: clubId),
    );
  }

  void _showEditClubDialog(BuildContext context, ClubModel club) {
    final nameCtrl = TextEditingController(text: club.name);
    final cityCtrl = TextEditingController(text: club.city);
    final leagueCtrl = TextEditingController(text: club.league);
    final descCtrl = TextEditingController(text: club.description);
    File? newLogoFile;
    String selCategory = kCategories.contains(club.category)
        ? club.category
        : kCategories.first;
    String selCountry = kCountryList.contains(club.country)
        ? club.country
        : kCountryList.first;

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
                Center(
                  child: LogoPicker(
                    initialUrl: club.logoUrl,
                    onPicked: (f) => newLogoFile = f,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Club Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: leagueCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'League'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Category',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: kCategories
                      .map(
                        (cat) => ChoiceChip(
                          label: Text(cat),
                          selected: selCategory == cat,
                          selectedColor: AppTheme.primaryLight,
                          labelStyle: TextStyle(
                            color: selCategory == cat
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: selCategory == cat
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) => setDlg(() => selCategory = cat),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Country',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
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
                    items: kCountryList
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setDlg(() => selCountry = v!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.red),
              onPressed: () => _confirmDeleteClub(ctx, club),
              child: const Text('Delete Club'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || cityCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Name and city are required'),
                      backgroundColor: AppTheme.red,
                    ),
                  );
                  return;
                }
                try {
                  String? newLogoUrl;
                  if (newLogoFile != null) {
                    newLogoUrl = await StorageUtils.uploadClubLogo(newLogoFile!, club.id);
                  }
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(club.id)
                      .update({
                        'name': nameCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'league': leagueCtrl.text.trim(),
                        if (newLogoUrl != null) 'logoUrl': newLogoUrl,
                        'description': descCtrl.text.trim(),
                        'category': selCategory,
                        'country': selCountry,
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
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
      descCtrl.dispose();
    });
  }

  void _confirmDeleteClub(BuildContext context, ClubModel club) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Delete Club?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Διαγραφή "${club.name}"; Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.',
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
              Navigator.pop(ctx);
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('clubs').doc(club.id).delete();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RecordChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _RecordChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    ],
  );
}

// ─── ACADEMIES TAB ────────────────────────────────────────────────────────────

class _AcademiesTab extends StatelessWidget {
  final String clubId;
  const _AcademiesTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.supportGreen,
        tooltip: 'Add Academy',
        onPressed: () => _showAddAcademyDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('academies')
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
          final academies = (snap.data?.docs ?? [])
              .map(
                (d) => AcademyModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          if (academies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: AppTheme.cardBg2,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Δεν υπάρχουν ακαδημίες',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Πάτα + για να προσθέσεις',
                    style: TextStyle(color: AppTheme.cardBg2, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: academies.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = academies[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AcademyDetailScreen(clubId: clubId, academy: a),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryLight.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          a.category,
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Players • Transfers • Matches',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.red,
                          size: 20,
                        ),
                        tooltip: 'Διαγραφή ακαδημίας',
                        onPressed: () => _confirmDeleteAcademy(context, a),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddAcademyDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selCat = kAcademyCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text(
            'Νέα Ακαδημία',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Όνομα Ακαδημίας'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              const Text(
                'Κατηγορία',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: kAcademyCategories
                    .map(
                      (cat) => ChoiceChip(
                        label: Text(cat),
                        selected: selCat == cat,
                        selectedColor: AppTheme.primaryLight,
                        labelStyle: TextStyle(
                          color: selCat == cat
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: selCat == cat
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) => setDlg(() => selCat = cat),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                // Έλεγχος για duplicate
                final existing = await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('academies')
                    .where('name', isEqualTo: name)
                    .get();

                if (existing.docs.isNotEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Αυτή η ακαδημία υπάρχει ήδη!'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('academies')
                      .add({
                        'name': name,
                        'category': selCat,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Σφάλμα: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Προσθήκη'),
            ),
          ],
        ),
      ),
    ).then((_) => nameCtrl.dispose());
  }

  void _confirmDeleteAcademy(BuildContext context, AcademyModel a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Διαγραφή Ακαδημίας;',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Θες να διαγράψεις την ακαδημία "${a.name} (${a.category})";',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('academies')
                    .doc(a.id)
                    .delete();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Αποτυχία διαγραφής: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );
  }
}

// ─── PLAYERS TAB ──────────────────────────────────────────────────────────────

class _PlayersTab extends StatefulWidget {
  final String clubId;
  const _PlayersTab({required this.clubId});

  @override
  State<_PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<_PlayersTab> {
  bool _exporting = false;

  Future<void> _exportCsv(List<PlayerModel> players) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final buf = StringBuffer();
      buf.writeln('Name,Position,Number,Age,Nationality,Goals,Yellow Cards,Red Cards,Appearances');
      for (final p in players) {
        final row = [
          _csvEscape(p.name),
          p.position,
          p.number?.toString() ?? '',
          p.age?.toString() ?? '',
          _csvEscape(p.nationality ?? ''),
          p.goals.toString(),
          p.yellowCards.toString(),
          p.redCards.toString(),
          p.appearances.toString(),
        ];
        buf.writeln(row.join(','));
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/players_export.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'Player stats export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('players')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading players: ${snap.error}',
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = (snap.data?.docs ?? [])
            .map(
              (d) =>
                  PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .where((p) => p.isActive)
            .toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (players.isNotEmpty)
                FloatingActionButton.small(
                  heroTag: 'exportCsv',
                  backgroundColor: AppTheme.primaryLight,
                  onPressed: _exporting ? null : () => _exportCsv(players),
                  tooltip: 'Export CSV',
                  child: _exporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_outlined, size: 18),
                ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'addPlayer',
                backgroundColor: AppTheme.supportGreen,
                onPressed: () => _showAddPlayerDialog(context, widget.clubId),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          body: players.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: AppTheme.cardBg2,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No players added yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tap + to add players',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    ...['GK', 'DEF', 'MID', 'FWD'].map((pos) {
                      final group = players
                          .where((p) => p.position == pos)
                          .toList();
                      if (group.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _posLabel(pos),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          ...group.map(
                            (p) => _PlayerRow(player: p, clubId: widget.clubId),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }

  String _posLabel(String pos) {
    const labels = {
      'GK': 'GOALKEEPERS',
      'DEF': 'DEFENDERS',
      'MID': 'MIDFIELDERS',
      'FWD': 'FORWARDS',
    };
    return labels[pos] ?? pos;
  }

  void _showAddPlayerDialog(BuildContext context, String clubId) {
    final nameCtrl = TextEditingController();
    String position = 'MID';
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Add Player', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: position,
                dropdownColor: AppTheme.cardBg2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Position'),
                items: ['GK', 'DEF', 'MID', 'FWD']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setS(() => position = v ?? 'MID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Jersey Number (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final player = PlayerModel(
                  id: '',
                  name: nameCtrl.text.trim(),
                  position: position,
                  number: int.tryParse(numberCtrl.text),
                );
                try {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('players')
                      .add(player.toMap());
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add player: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      numberCtrl.dispose();
    });
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerModel player;
  final String clubId;
  const _PlayerRow({required this.player, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _posColor(player.position).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.number != null ? '${player.number}' : player.position,
                style: TextStyle(
                  color: _posColor(player.position),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  player.positionLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.medical_services,
              color: player.isInjured ? AppTheme.red : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () => _showInjuryDialog(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.red,
              size: 20,
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK':
        return AppTheme.accent;
      case 'DEF':
        return AppTheme.primaryLight;
      case 'MID':
        return AppTheme.supportGreen;
      case 'FWD':
        return AppTheme.liveRed;
      default:
        return Colors.white;
    }
  }

  void _showInjuryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _InjuryDialog(player: player, clubId: clubId),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Remove Player',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove ${player.name} from the squad?',
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
                  .doc(clubId)
                  .collection('players')
                  .doc(player.id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── INJURY DIALOG ────────────────────────────────────────────────────────────

class _InjuryDialog extends StatefulWidget {
  final PlayerModel player;
  final String clubId;
  const _InjuryDialog({required this.player, required this.clubId});

  @override
  State<_InjuryDialog> createState() => _InjuryDialogState();
}

class _InjuryDialogState extends State<_InjuryDialog> {
  late bool _isInjured;
  late TextEditingController _noteCtrl;
  DateTime? _returnDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isInjured = widget.player.isInjured;
    _noteCtrl = TextEditingController(text: widget.player.injuryNote ?? '');
    _returnDate = widget.player.expectedReturn;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('players')
          .doc(widget.player.id)
          .update({
        'isInjured': _isInjured,
        'injuryNote': _isInjured ? _noteCtrl.text.trim() : null,
        'expectedReturn': _isInjured && _returnDate != null
            ? Timestamp.fromDate(_returnDate!)
            : null,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('InjuryDialog save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Σφάλμα αποθήκευσης. Δοκίμασε ξανά.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        '${widget.player.name} — Τραυματισμός',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Τραυματίας', style: TextStyle(color: Colors.white)),
            value: _isInjured,
            activeColor: AppTheme.red,
            onChanged: (v) => setState(() => _isInjured = v),
          ),
          if (_isInjured) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Σημείωση',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardBg2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _returnDate != null
                    ? 'Επιστροφή: ${DateFormat('d MMM yyyy').format(_returnDate!)}'
                    : 'Αναμενόμενη επιστροφή',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              trailing: const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _returnDate = picked);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Άκυρο'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Αποθήκευση'),
        ),
      ],
    );
  }
}

// ─── REVENUE TAB ──────────────────────────────────────────────────────────────

class _RevenueTab extends StatelessWidget {
  final String clubId;
  const _RevenueTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('clubId', isEqualTo: clubId)
          .orderBy('createdAt', descending: true)
          .limit(100)
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
        final donations = (snap.data?.docs ?? [])
            .map(
              (d) =>
                  DonationModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final total = donations.fold<double>(0.0, (sum, d) => sum + d.amount);
        final byType = <String, double>{};
        for (final d in donations) {
          byType[d.type] = (byType[d.type] ?? 0) + d.amount;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total revenue card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Revenue',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    '€${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: byType.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key[0].toUpperCase() + e.key.substring(1),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '€${e.value.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'TRANSACTIONS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            if (donations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No donations yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ...donations.map(
                (d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Text(d.typeEmoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${d.typeLabel} • ${DateFormat('d MMM yyyy').format(d.createdAt)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+€${d.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.supportGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── FANS TAB ────────────────────────────────────────────────────────────────

class _FansTab extends StatelessWidget {
  final String clubId;
  const _FansTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
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
        if (!snap.hasData || snap.data?.data() == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final club = ClubModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          clubId,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _BigStat(
                    label: 'Followers',
                    value: '${club.followers}',
                    icon: Icons.people,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigStat(
                    label: 'Votes',
                    value: '${club.votes}',
                    icon: Icons.how_to_vote,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'RECENT VOTERS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .collection('votes')
                  .orderBy('votedAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (ctx, voteSnap) {
                final votes = voteSnap.data?.docs ?? [];
                if (votes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No votes yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return Column(
                  children: votes.map((v) {
                    final votedAt =
                        (v.data() as Map<String, dynamic>)['votedAt'];
                    final date = votedAt != null
                        ? (votedAt as dynamic).toDate() as DateTime?
                        : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.how_to_vote,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fan: ${v.id.length > 16 ? '${v.id.substring(0, 16)}...' : v.id}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (date != null)
                            Text(
                              DateFormat('d MMM').format(date),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'SUPPORTERS / DONATIONS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('clubId', isEqualTo: clubId)
                  .snapshots(),
              builder: (ctx, donSnap) {
                if (donSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Σφάλμα: ${donSnap.error}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final donations = (donSnap.data?.docs ?? [])
                    .map(
                      (d) => DonationModel.fromMap(
                        d.data() as Map<String, dynamic>,
                        d.id,
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final limited = donations.take(20).toList();
                if (limited.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No supporters yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return Column(
                  children: limited
                      .map(
                        (d) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              Text(
                                d.typeEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${d.typeLabel} • ${DateFormat('d MMM yyyy').format(d.createdAt)}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+€${d.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.supportGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── TRANSFERS TAB ────────────────────────────────────────────────────────────

class _TransfersTab extends StatelessWidget {
  final String clubId;
  const _TransfersTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryLight,
        onPressed: () => _showAddTransferDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('transfers')
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
          final transfers = (snap.data?.docs ?? [])
              .map(
                (d) => TransferModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (transfers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text(
                    'No transfers yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap + to add a transfer',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: transfers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final t = transfers[i];
              final isIn = t.type == 'in';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isIn ? AppTheme.supportGreen : AppTheme.red)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIn ? AppTheme.supportGreen : AppTheme.red,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isIn
                                ? 'From: ${t.fromClub ?? '-'}'
                                : 'To: ${t.toClub ?? '-'}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isIn ? 'IN' : 'OUT',
                          style: TextStyle(
                            color: isIn ? AppTheme.supportGreen : AppTheme.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          DateFormat('d MMM yyyy').format(t.date),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
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
      ),
    );
  }

  void _showAddTransferDialog(BuildContext context) {
    final playerCtrl = TextEditingController();
    final clubCtrl = TextEditingController();
    String type = 'in';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text(
            'Add Transfer',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: playerCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: AppTheme.cardBg2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('Transfer IN')),
                  DropdownMenuItem(value: 'out', child: Text('Transfer OUT')),
                ],
                onChanged: (v) => setS(() => type = v ?? 'in'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clubCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: type == 'in' ? 'From Club' : 'To Club',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (playerCtrl.text.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('transfers')
                      .add({
                        'playerName': playerCtrl.text.trim(),
                        'type': type,
                        'fromClub': type == 'in' ? clubCtrl.text.trim() : null,
                        'toClub': type == 'out' ? clubCtrl.text.trim() : null,
                        'date': DateTime.now(),
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add transfer: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((_) {
      playerCtrl.dispose();
      clubCtrl.dispose();
    });
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _BigStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─── STAFF TAB ────────────────────────────────────────────────────────────────

String _makeInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

class _StaffTab extends StatelessWidget {
  final String clubId;
  const _StaffTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppProvider>().user;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (!snap.data!.exists) return const SizedBox.shrink();
        final club = ClubModel.fromMap(snap.data!.data() as Map<String, dynamic>, clubId);
        final isOwner = currentUser?.uid == club.adminUid;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (isOwner) ...[
              _InviteCodeCard(club: club, clubId: clubId),
              const SizedBox(height: 20),
            ],
            const Text(
              'STAFF MEMBERS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            if (club.staffUids.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.group_outlined, size: 48, color: AppTheme.cardBg2),
                      const SizedBox(height: 12),
                      const Text(
                        'No staff members yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isOwner
                            ? 'Share the invite code to add staff'
                            : 'The admin hasn\'t added staff yet',
                        style: const TextStyle(color: AppTheme.cardBg2, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...club.staffUids.map(
                (uid) => _StaffMemberTile(uid: uid, clubId: clubId, isOwner: isOwner),
              ),
          ],
        );
      },
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final ClubModel club;
  final String clubId;
  const _InviteCodeCard({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final code = club.inviteCode ?? '——————';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.key, color: AppTheme.primaryLight, size: 16),
              SizedBox(width: 8),
              Text(
                'Invite Code',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const Spacer(),
              if (club.inviteCode != null)
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.primaryLight),
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: club.inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied!'),
                        backgroundColor: AppTheme.supportGreen,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code with staff. They enter it in Profile → Join Club with Code.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(club.inviteCode == null ? 'Generate Code' : 'Reset Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: club.inviteCode == null ? AppTheme.supportGreen : AppTheme.red,
                side: BorderSide(
                  color: club.inviteCode == null ? AppTheme.supportGreen : AppTheme.red,
                ),
              ),
              onPressed: () => _confirmReset(context, club.inviteCode != null),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, bool isReset) {
    if (!isReset) {
      _doGenerate(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Reset Invite Code?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The old code will stop working immediately. Anyone who hasn\'t joined yet will need the new code.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              Navigator.pop(ctx);
              _doGenerate(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _doGenerate(BuildContext context) async {
    final newCode = _makeInviteCode();
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .update({'inviteCode': newCode});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New code: $newCode'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }
}

class _StaffMemberTile extends StatefulWidget {
  final String uid;
  final String clubId;
  final bool isOwner;
  const _StaffMemberTile({
    required this.uid,
    required this.clubId,
    required this.isOwner,
  });

  @override
  State<_StaffMemberTile> createState() => _StaffMemberTileState();
}

class _StaffMemberTileState extends State<_StaffMemberTile> {
  late final Future<DocumentSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _future,
      builder: (ctx, snap) {
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};
        final name = data['name'] as String? ?? widget.uid.substring(0, 8);
        final email = data['email'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.red,
                    size: 20,
                  ),
                  tooltip: 'Remove from staff',
                  onPressed: () => _confirmRemove(ctx, widget.uid, name),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'Remove Staff Member?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove $name from the club staff?',
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
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .update({'staffUids': FieldValue.arrayRemove([widget.uid])});
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .update({'clubId': null, 'role': 'fan'});
              } catch (_) {}
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── ACADEMY DETAIL SCREEN ────────────────────────────────────────────────────

class AcademyDetailScreen extends StatefulWidget {
  final String clubId;
  final AcademyModel academy;
  const AcademyDetailScreen({
    super.key,
    required this.clubId,
    required this.academy,
  });

  @override
  State<AcademyDetailScreen> createState() => _AcademyDetailScreenState();
}

class _AcademyDetailScreenState extends State<AcademyDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryLight.withOpacity(0.4)),
              ),
              child: Text(
                widget.academy.category,
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.academy.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primaryLight,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Players'),
            Tab(text: 'Transfers'),
            Tab(text: 'Matches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AcademyPlayersTab(
            clubId: widget.clubId,
            academyId: widget.academy.id,
          ),
          _AcademyTransfersTab(
            clubId: widget.clubId,
            academyId: widget.academy.id,
          ),
          _AcademyMatchesTab(
            clubId: widget.clubId,
            academy: widget.academy,
          ),
        ],
      ),
    );
  }
}

// ─── ACADEMY PLAYERS TAB ─────────────────────────────────────────────────────

class _AcademyPlayersTab extends StatelessWidget {
  final String clubId;
  final String academyId;
  const _AcademyPlayersTab({required this.clubId, required this.academyId});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('academies')
          .doc(academyId)
          .collection('players');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading players: ${snap.error}',
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = (snap.data?.docs ?? [])
            .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((p) => p.isActive)
            .toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.supportGreen,
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
          body: players.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined, size: 56, color: AppTheme.cardBg2),
                      SizedBox(height: 12),
                      Text('No players yet', style: TextStyle(color: AppTheme.textSecondary)),
                      SizedBox(height: 6),
                      Text('Tap + to add players', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    ...['GK', 'DEF', 'MID', 'FWD'].map((pos) {
                      final group = players.where((p) => p.position == pos).toList();
                      if (group.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _posLabel(pos),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          ...group.map((p) => _AcademyPlayerRow(player: p, col: _col)),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }

  String _posLabel(String pos) => const {
    'GK': 'GOALKEEPERS',
    'DEF': 'DEFENDERS',
    'MID': 'MIDFIELDERS',
    'FWD': 'FORWARDS',
  }[pos] ?? pos;

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String position = 'MID';
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Add Player', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: position,
                dropdownColor: AppTheme.cardBg2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Position'),
                items: ['GK', 'DEF', 'MID', 'FWD']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setS(() => position = v ?? 'MID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Jersey Number (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  await _col.add(
                    PlayerModel(
                      id: '',
                      name: nameCtrl.text.trim(),
                      position: position,
                      number: int.tryParse(numberCtrl.text),
                    ).toMap(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add player: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademyPlayerRow extends StatelessWidget {
  final PlayerModel player;
  final CollectionReference<Map<String, dynamic>> col;
  const _AcademyPlayerRow({required this.player, required this.col});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _posColor(player.position).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.number != null ? '${player.number}' : player.position,
                style: TextStyle(
                  color: _posColor(player.position),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  player.positionLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                title: const Text('Remove Player', style: TextStyle(color: Colors.white)),
                content: Text('Remove ${player.name}?', style: const TextStyle(color: AppTheme.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                    onPressed: () async {
                      await col.doc(player.id).delete();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _posColor(String pos) => switch (pos) {
    'GK' => AppTheme.accent,
    'DEF' => AppTheme.primaryLight,
    'MID' => AppTheme.supportGreen,
    'FWD' => AppTheme.liveRed,
    _ => Colors.white,
  };
}

// ─── ACADEMY TRANSFERS TAB ───────────────────────────────────────────────────

class _AcademyTransfersTab extends StatelessWidget {
  final String clubId;
  final String academyId;
  const _AcademyTransfersTab({required this.clubId, required this.academyId});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('academies')
          .doc(academyId)
          .collection('transfers');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryLight,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.snapshots(),
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
          final transfers = (snap.data?.docs ?? [])
              .map((d) => TransferModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (transfers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz, size: 56, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No transfers yet', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 6),
                  Text('Tap + to add a transfer', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: transfers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final t = transfers[i];
              final isIn = t.type == 'in';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isIn ? AppTheme.supportGreen : AppTheme.red).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIn ? AppTheme.supportGreen : AppTheme.red,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.playerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            isIn ? 'From: ${t.fromClub ?? '-'}' : 'To: ${t.toClub ?? '-'}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isIn ? 'IN' : 'OUT',
                          style: TextStyle(color: isIn ? AppTheme.supportGreen : AppTheme.red, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          DateFormat('d MMM yyyy').format(t.date),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
                      onPressed: () async => await _col.doc(t.id).delete(),
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

  void _showAddDialog(BuildContext context) {
    final playerCtrl = TextEditingController();
    final clubCtrl = TextEditingController();
    String type = 'in';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Add Transfer', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: playerCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: AppTheme.cardBg2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('Transfer IN')),
                  DropdownMenuItem(value: 'out', child: Text('Transfer OUT')),
                ],
                onChanged: (v) => setS(() => type = v ?? 'in'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clubCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: type == 'in' ? 'From Club' : 'To Club'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (playerCtrl.text.trim().isEmpty) return;
                try {
                  await _col.add({
                    'playerName': playerCtrl.text.trim(),
                    'type': type,
                    'fromClub': type == 'in' ? clubCtrl.text.trim() : null,
                    'toClub': type == 'out' ? clubCtrl.text.trim() : null,
                    'date': DateTime.now(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add transfer: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((_) {
      playerCtrl.dispose();
      clubCtrl.dispose();
    });
  }
}

// ─── ACADEMY MATCHES TAB ─────────────────────────────────────────────────────

class _AcademyMatchesTab extends StatelessWidget {
  final String clubId;
  final AcademyModel academy;
  const _AcademyMatchesTab({required this.clubId, required this.academy});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('academies')
          .doc(academy.id)
          .collection('matches');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.supportGreen,
        icon: const Icon(Icons.add),
        label: const Text('New Match'),
        onPressed: () => _showAddDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.snapshots(),
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
          final docs = (snap.data?.docs ?? []).toList()
            ..sort((a, b) {
              final ad = ((a.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bd = ((b.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bd.compareTo(ad);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, size: 56, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No matches yet', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 6),
                  Text('Tap + to schedule a match', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final docId = docs[i].id;
              final isHome = d['isHome'] as bool? ?? true;
              final opponent = d['opponent'] as String? ?? '-';
              final date = (d['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              final status = d['status'] as String? ?? 'upcoming';
              final homeScore = d['homeScore'] as int?;
              final awayScore = d['awayScore'] as int?;
              final venue = d['venue'] as String?;
              final hasScore = homeScore != null && awayScore != null;

              final myTeam = academy.name;
              final homeTeam = isHome ? myTeam : opponent;
              final awayTeam = isHome ? opponent : myTeam;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'finished'
                                ? AppTheme.supportGreen.withValues(alpha: 0.15)
                                : AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status == 'finished' ? 'FT' : 'Upcoming',
                            style: TextStyle(
                              color: status == 'finished' ? AppTheme.supportGreen : AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMM yyyy').format(date),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        if (venue != null && venue.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.stadium_outlined, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(venue, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async => await _col.doc(docId).delete(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            homeTeam,
                            style: TextStyle(
                              color: isHome ? AppTheme.primaryLight : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            hasScore ? '$homeScore  :  $awayScore' : 'vs',
                            style: TextStyle(
                              color: hasScore ? Colors.white : AppTheme.textSecondary,
                              fontSize: hasScore ? 22 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            awayTeam,
                            style: TextStyle(
                              color: !isHome ? AppTheme.primaryLight : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(hasScore ? 'Update Score' : 'Add Score'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          side: const BorderSide(color: AppTheme.accent),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _showScoreDialog(context, docId, homeScore, awayScore),
                      ),
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

  void _showAddDialog(BuildContext context) {
    final opponentCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    bool isHome = true;
    DateTime date = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('New Academy Match', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: opponentCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Opponent'),
                ),
                const SizedBox(height: 14),
                const Text('Location', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => isHome = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isHome ? AppTheme.primaryLight.withOpacity(0.2) : AppTheme.cardBg2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isHome ? AppTheme.primaryLight : AppTheme.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Home',
                              style: TextStyle(
                                color: isHome ? AppTheme.primaryLight : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => isHome = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isHome ? AppTheme.accent.withOpacity(0.2) : AppTheme.cardBg2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !isHome ? AppTheme.accent : AppTheme.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Away',
                              style: TextStyle(
                                color: !isHome ? AppTheme.accent : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('${date.day}/${date.month}/${date.year}'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppTheme.divider)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (d != null) setS(() => date = d);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: venueCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Venue (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (opponentCtrl.text.trim().isEmpty) return;
                try {
                  await _col.add({
                    'opponent': opponentCtrl.text.trim(),
                    'isHome': isHome,
                    'date': Timestamp.fromDate(date),
                    'venue': venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                    'status': 'upcoming',
                    'homeScore': null,
                    'awayScore': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create match: $e'),
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
      opponentCtrl.dispose();
      venueCtrl.dispose();
    });
  }

  void _showScoreDialog(BuildContext context, String docId, int? home, int? away) {
    final homeCtrl = TextEditingController(text: home?.toString() ?? '');
    final awayCtrl = TextEditingController(text: away?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Update Score', style: TextStyle(color: Colors.white)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: homeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Home'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(':', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextField(
                controller: awayCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Away'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final h = int.tryParse(homeCtrl.text);
              final a = int.tryParse(awayCtrl.text);
              if (h == null || a == null) return;
              try {
                await _col.doc(docId).update({
                  'homeScore': h,
                  'awayScore': a,
                  'status': 'finished',
                });
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      homeCtrl.dispose();
      awayCtrl.dispose();
    });
  }
}

// ─── CLUB SPONSORS TAB ────────────────────────────────────────────────────────

class _ClubSponsorsTab extends StatelessWidget {
  final String clubId;
  const _ClubSponsorsTab({required this.clubId});

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
                    'My Sponsors',
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
                    backgroundColor: AppTheme.supportGreen,
                  ),
                  onPressed: () =>
                      showAddSponsorSheet(context, forcedClubId: clubId),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Attach sponsors with logos/PDFs to your club.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          SponsorsList(clubId: clubId),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── CLUB GAMES TAB ──────────────────────────────────────────────────────────

class _ClubGamesTab extends StatelessWidget {
  final String clubId;
  const _ClubGamesTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('Νέο Παιχνίδι'),
        onPressed: () => _showCreateGameDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('clubId', isEqualTo: clubId)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = (snap.data?.docs ?? [])
              .map((d) => GameModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          if (games.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎮', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 12),
                  Text('Δεν υπάρχουν παιχνίδια',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('Πάτα + για να δημιουργήσεις',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final g = games[i];
              return ListTile(
                tileColor: AppTheme.cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Text(g.typeEmoji, style: const TextStyle(fontSize: 28)),
                title: Text(g.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.typeLabel,
                        style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
                    if (g.description.isNotEmpty)
                      Text(g.description,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (g.prizes.isNotEmpty)
                      Text('${g.prizes.length} δώρα',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                isThreeLine: g.prizes.isNotEmpty || g.description.isNotEmpty,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: g.isActive,
                      activeColor: AppTheme.supportGreen,
                      onChanged: (v) => FirebaseFirestore.instance
                          .collection('games').doc(g.id)
                          .update({'isActive': v}),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                      onPressed: () => _showEditGameDialog(context, g),
                    ),
                    if (g.type == 'trivia')
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
                onTap: g.type == 'trivia'
                    ? () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                TriviaAdminScreen(gameId: g.id, gameTitle: g.title),
                          ),
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateGameDialog(BuildContext outerCtx) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '1');
    String type = 'spin_wheel';
    final List<Map<String, dynamic>> prizes = [];
    DateTime? expiresAt;
    File? puzzleImage;

    showDialog(
      context: outerCtx,
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
                  runSpacing: 6,
                  children: const [
                    {'v': 'spin_wheel', 'l': '🎡 Τυχερός Τροχός'},
                    {'v': 'scratch_card', 'l': '🎫 Ξυστό'},
                    {'v': 'trivia', 'l': '🧠 Trivia'},
                    {'v': 'puzzle', 'l': '🧩 Puzzle'},
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
                if (type == 'puzzle') ...[
                  const SizedBox(height: 8),
                  const Text('Εικόνα Puzzle', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final f = await StorageUtils.pickImage();
                      if (f != null) setS(() => puzzleImage = f);
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg2,
                        borderRadius: BorderRadius.circular(10),
                        image: puzzleImage != null
                            ? DecorationImage(image: FileImage(puzzleImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: puzzleImage == null
                          ? const Center(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate, color: AppTheme.textSecondary, size: 32),
                                SizedBox(height: 4),
                                Text('Επίλεξε εικόνα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ))
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('Δώρα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                if (prizes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: prizes.map((p) => Chip(
                      backgroundColor: AppTheme.cardBg2,
                      label: Text(
                        '${p['emoji']} ${p['title']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                      onDeleted: () => setS(() => prizes.remove(p)),
                    )).toList(),
                  ),
                TextButton.icon(
                  onPressed: () => _showAddPrizeDialog(ctx, (prize) {
                    setS(() => prizes.add(prize));
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Πρόσθεσε Δώρο'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      expiresAt != null
                          ? DateFormat('d MMM yyyy').format(expiresAt!)
                          : 'Χωρίς λήξη',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setS(() => expiresAt = d);
                      },
                      child: const Text('Επιλογή'),
                    ),
                    if (expiresAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setS(() => expiresAt = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Ο τίτλος απαιτείται')),
                  );
                  return;
                }
                final limit = int.tryParse(limitCtrl.text) ?? 1;
                try {
                  String? puzzleImageUrl;
                  if (type == 'puzzle' && puzzleImage != null) {
                    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                    puzzleImageUrl = await StorageUtils.uploadPuzzleImage(puzzleImage!, tempId);
                  }
                  final data = {
                    ...GameModel(
                      id: '',
                      title: title,
                      description: descCtrl.text.trim(),
                      type: type,
                      dailyLimit: limit,
                      createdAt: DateTime.now(),
                      clubId: clubId,
                      prizes: prizes.map((p) => PrizeModel.fromMap(p)).toList(),
                      expiresAt: expiresAt,
                      puzzleImageUrl: puzzleImageUrl,
                    ).toMap(),
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  final ref = await FirebaseFirestore.instance
                      .collection('games')
                      .add(data);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (type == 'trivia' && outerCtx.mounted) {
                    Navigator.push(
                      outerCtx,
                      MaterialPageRoute(
                        builder: (_) => TriviaAdminScreen(gameId: ref.id, gameTitle: title),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: AppTheme.red),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
      limitCtrl.dispose();
    });
  }

  void _showEditGameDialog(BuildContext outerCtx, GameModel game) {
    final titleCtrl = TextEditingController(text: game.title);
    final descCtrl = TextEditingController(text: game.description);
    final limitCtrl = TextEditingController(text: game.dailyLimit.toString());
    String type = game.type;
    final List<Map<String, dynamic>> prizes = game.prizes.map((p) => p.toMap()).toList();
    DateTime? expiresAt = game.expiresAt;
    File? puzzleImage;

    showDialog(
      context: outerCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Επεξεργασία Παιχνιδιού', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Τύπος', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    {'v': 'spin_wheel', 'l': '🎡 Τυχερός Τροχός'},
                    {'v': 'scratch_card', 'l': '🎫 Ξυστό'},
                    {'v': 'trivia', 'l': '🧠 Trivia'},
                    {'v': 'puzzle', 'l': '🧩 Puzzle'},
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
                if (type == 'puzzle') ...[
                  const SizedBox(height: 8),
                  const Text('Εικόνα Puzzle', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final f = await StorageUtils.pickImage();
                      if (f != null) setS(() => puzzleImage = f);
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg2,
                        borderRadius: BorderRadius.circular(10),
                        image: puzzleImage != null
                            ? DecorationImage(image: FileImage(puzzleImage!), fit: BoxFit.cover)
                            : (game.puzzleImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(game.puzzleImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: (puzzleImage == null && game.puzzleImageUrl == null)
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate, color: AppTheme.textSecondary, size: 32),
                                  SizedBox(height: 4),
                                  Text('Επίλεξε εικόνα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('Δώρα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                if (prizes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: prizes.map((p) => Chip(
                      backgroundColor: AppTheme.cardBg2,
                      label: Text(
                        '${p['emoji']} ${p['title']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                      onDeleted: () => setS(() => prizes.remove(p)),
                    )).toList(),
                  ),
                TextButton.icon(
                  onPressed: () => _showAddPrizeDialog(ctx, (prize) {
                    setS(() => prizes.add(prize));
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Πρόσθεσε Δώρο'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      expiresAt != null
                          ? DateFormat('d MMM yyyy').format(expiresAt!)
                          : 'Χωρίς λήξη',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setS(() => expiresAt = d);
                      },
                      child: const Text('Επιλογή'),
                    ),
                    if (expiresAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setS(() => expiresAt = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('Διαγραφή;', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Διαγραφή "${game.title}";',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Άκυρο'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Διαγραφή'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && ctx.mounted) {
                  await FirebaseFirestore.instance.collection('games').doc(game.id).delete();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Διαγραφή'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Ο τίτλος απαιτείται')),
                  );
                  return;
                }
                final limit = int.tryParse(limitCtrl.text) ?? 1;
                try {
                  String? puzzleImageUrl = game.puzzleImageUrl;
                  if (type == 'puzzle' && puzzleImage != null) {
                    puzzleImageUrl = await StorageUtils.uploadPuzzleImage(puzzleImage!, game.id);
                  }
                  if (type != 'puzzle') puzzleImageUrl = null;
                  await FirebaseFirestore.instance
                      .collection('games')
                      .doc(game.id)
                      .update(
                        GameModel(
                          id: game.id,
                          title: title,
                          description: descCtrl.text.trim(),
                          type: type,
                          dailyLimit: limit,
                          createdAt: game.createdAt,
                          clubId: clubId,
                          prizes: prizes.map((p) => PrizeModel.fromMap(p)).toList(),
                          expiresAt: expiresAt,
                          puzzleImageUrl: puzzleImageUrl,
                        ).toMap(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: AppTheme.red),
                    );
                  }
                }
              },
              child: const Text('Αποθήκευση', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
      limitCtrl.dispose();
    });
  }

  static void _showAddPrizeDialog(BuildContext context, void Function(Map<String, dynamic>) onAdd) {
    final emojiCtrl = TextEditingController(text: '🎁');
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pointsCtrl = TextEditingController();
    final digitalContentCtrl = TextEditingController();
    String prizeType = 'points';
    double weight = 1;
    File? prizePhoto;
    DateTime? redeemByDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Νέο Δώρο', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emojiCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Emoji'),
                ),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Τίτλος'),
                ),
                const SizedBox(height: 8),
                const Text('Τύπος Δώρου', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    {'v': 'points', 'l': '🪙 Πόντοι'},
                    {'v': 'physical', 'l': '📦 Φυσικό'},
                    {'v': 'digital', 'l': '💾 Ψηφιακό'},
                    {'v': 'nothing', 'l': '😔 Τίποτα'},
                  ].map((e) {
                    final selected = prizeType == e['v'];
                    return ChoiceChip(
                      label: Text(e['l']!),
                      selected: selected,
                      selectedColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setS(() => prizeType = e['v']!),
                    );
                  }).toList(),
                ),
                if (prizeType == 'points') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Αξία σε πόντους'),
                  ),
                ],
                if (prizeType == 'physical') ...[
                  const SizedBox(height: 8),
                  const Text('Φωτογραφία Δώρου', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final file = await StorageUtils.pickImage();
                      if (file != null) setS(() => prizePhoto = file);
                    },
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: prizePhoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(prizePhoto!, fit: BoxFit.cover, width: double.infinity),
                            )
                          : const Center(
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  color: AppTheme.textSecondary, size: 32),
                            ),
                    ),
                  ),
                ],
                if (prizeType == 'digital') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: digitalContentCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Περιεχόμενο (κωδικός, link, κείμενο...)',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Περιγραφή (optional)'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Πιθανότητα: ${weight.toInt()}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Slider(
                  value: weight,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppTheme.accent,
                  onChanged: (v) => setS(() => weight = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event_available, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      redeemByDate != null
                          ? DateFormat('d MMM yyyy').format(redeemByDate!)
                          : 'Χωρίς λήξη εξαργύρωσης',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: redeemByDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setS(() => redeemByDate = d);
                      },
                      child: const Text('Επιλογή'),
                    ),
                    if (redeemByDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setS(() => redeemByDate = null),
                      ),
                  ],
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
                    const SnackBar(content: Text('Τίτλος απαιτείται')),
                  );
                  return;
                }
                final data = <String, dynamic>{
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'emoji': emojiCtrl.text.trim().isEmpty ? '🎁' : emojiCtrl.text.trim(),
                  'title': titleCtrl.text.trim(),
                  'type': prizeType,
                  'description': descCtrl.text.trim(),
                  'weight': weight.toInt(),
                };
                if (prizeType == 'points' && pointsCtrl.text.isNotEmpty) {
                  data['pointsValue'] = int.tryParse(pointsCtrl.text) ?? 0;
                }
                if (prizeType == 'physical' && prizePhoto != null) {
                  final prizeId = data['id'] as String;
                  final photoUrl = await StorageUtils.uploadPrizePhoto(prizePhoto!, prizeId);
                  data['photoUrl'] = photoUrl;
                }
                if (prizeType == 'digital' && digitalContentCtrl.text.trim().isNotEmpty) {
                  data['digitalContent'] = digitalContentCtrl.text.trim();
                }
                if (redeemByDate != null) {
                  data['redeemByDate'] = redeemByDate;
                }
                onAdd(data);
                Navigator.pop(ctx);
              },
              child: const Text('Αποθήκευση'),
            ),
          ],
        ),
      ),
    ).then((_) {
      emojiCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      pointsCtrl.dispose();
      digitalContentCtrl.dispose();
    });
  }
}

// ─── POST TO FEED SHEET ───────────────────────────────────────────────────────

class _PostFeedSheet extends StatefulWidget {
  final String clubId;
  const _PostFeedSheet({required this.clubId});

  @override
  State<_PostFeedSheet> createState() => _PostFeedSheetState();
}

class _PostFeedSheetState extends State<_PostFeedSheet> {
  final _textCtrl = TextEditingController();
  File? _imageFile;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await StorageUtils.pickImage(maxSizeKB: 4096);
      if (file != null && mounted) setState(() => _imageFile = file);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _imageFile == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      String? imageUrl;
      if (_imageFile != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        imageUrl = await StorageUtils.uploadImage(
          file: _imageFile!,
          path: 'clubs/${widget.clubId}/feed/$ts.jpg',
        );
      }
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('feed')
          .add({
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post to Club Feed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Write something for your fans...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.cardBg2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_imageFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _imageFile!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageFile = null),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.divider),
              ),
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Photo'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.liveRed, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Publish',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GALLERY ADMIN TAB ────────────────────────────────────────────────────────

class _GalleryAdminTab extends StatefulWidget {
  final String clubId;
  const _GalleryAdminTab({required this.clubId});

  @override
  State<_GalleryAdminTab> createState() => _GalleryAdminTabState();
}

class _GalleryAdminTabState extends State<_GalleryAdminTab> {
  bool _uploading = false;

  Future<void> _upload({bool isVideo = false}) async {
    setState(() => _uploading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      String url;
      String type;
      if (isVideo) {
        final file = await StorageUtils.pickVideo();
        if (file == null) { setState(() => _uploading = false); return; }
        url = await StorageUtils.uploadGalleryVideo(file, widget.clubId, '$ts.mp4');
        type = 'video';
      } else {
        final file = await StorageUtils.pickImage(maxSizeKB: 4096);
        if (file == null) { setState(() => _uploading = false); return; }
        url = await StorageUtils.uploadGalleryPhoto(file, widget.clubId, '$ts.jpg');
        type = 'photo';
      }
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId).collection('gallery')
          .add({'url': url, 'type': type, 'caption': '', 'uploadedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVideo ? 'Το βίντεο ανέβηκε' : 'Η φωτογραφία ανέβηκε'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_a_photo, color: AppTheme.supportGreen),
              title: const Text('Φωτογραφία', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _upload(); },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Βίντεο', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _upload(isVideo: true); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Διαγραφή φωτογραφίας', style: TextStyle(color: Colors.white)),
        content: const Text('Είσαι σίγουρος;', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Άκυρο')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Διαγραφή', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId).collection('gallery').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _showUploadOptions,
        backgroundColor: AppTheme.supportGreen,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.add, color: Colors.black),
        label: Text(_uploading ? 'Ανέβασμα...' : 'Προσθήκη', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId).collection('gallery')
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('Δεν υπάρχουν φωτογραφίες', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 4),
                  Text('Πάτα + για να ανεβάσεις', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final url = d['url'] as String? ?? '';
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (ctx2, e, st) => Container(
                        color: AppTheme.cardBg2,
                        child: const Icon(Icons.broken_image, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(doc.id),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── WOMEN ADMIN TAB ──────────────────────────────────────────────────────────

class _WomenAdminTab extends StatefulWidget {
  final String clubId;
  const _WomenAdminTab({required this.clubId});

  @override
  State<_WomenAdminTab> createState() => _WomenAdminTabState();
}

class _WomenAdminTabState extends State<_WomenAdminTab> {
  Future<void> _showAddPlayerDialog() async {
    final nameCtrl = TextEditingController();
    String selectedPos = 'MID';
    final numberCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Προσθήκη Παίκτριας', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Όνομα',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPos,
                dropdownColor: AppTheme.cardBg2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Θέση',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                items: const [
                  DropdownMenuItem(value: 'GK', child: Text('Τερματοφύλακας')),
                  DropdownMenuItem(value: 'DEF', child: Text('Αμυντικός')),
                  DropdownMenuItem(value: 'MID', child: Text('Μέσος')),
                  DropdownMenuItem(value: 'FWD', child: Text('Επιθετικός')),
                ],
                onChanged: (v) => setS(() => selectedPos = v ?? 'MID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Αριθμός φανέλας (προαιρετικό)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Άκυρο')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('clubs').doc(widget.clubId).collection('women_players')
                    .add({
                  'name': nameCtrl.text.trim(),
                  'position': selectedPos,
                  'number': numberCtrl.text.isNotEmpty ? int.tryParse(numberCtrl.text) : null,
                  'isActive': true,
                  'goals': 0,
                  'yellowCards': 0,
                  'redCards': 0,
                  'appearances': 0,
                  'isInjured': false,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Αποθήκευση', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPlayerDialog,
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Προσθήκη', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId).collection('women_players')
            .orderBy('position')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = (snap.data?.docs ?? [])
              .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          if (players.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('♀', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Δεν υπάρχουν παίκτριες', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 4),
                  Text('Πάτα + για να προσθέσεις', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final p = players[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          p.number != null ? '${p.number}' : p.position,
                          style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(p.positionLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: p.isActive,
                      activeColor: Colors.pinkAccent,
                      onChanged: (val) => FirebaseFirestore.instance
                          .collection('clubs').doc(widget.clubId).collection('women_players')
                          .doc(p.id).update({'isActive': val}),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('clubs').doc(widget.clubId).collection('women_players')
                          .doc(p.id).delete(),
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
}


// ─── STADIUM PHOTOS ADMIN TAB ─────────────────────────────────────────────────

class _StadiumPhotosAdminTab extends StatefulWidget {
  final String clubId;
  const _StadiumPhotosAdminTab({required this.clubId});

  @override
  State<_StadiumPhotosAdminTab> createState() => _StadiumPhotosAdminTabState();
}

class _StadiumPhotosAdminTabState extends State<_StadiumPhotosAdminTab> {
  bool _uploading = false;

  Future<void> _uploadPhoto() async {
    setState(() => _uploading = true);
    try {
      final file = await StorageUtils.pickImage(maxSizeKB: 4096);
      if (file == null) { setState(() => _uploading = false); return; }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await StorageUtils.uploadStadiumPhoto(file, widget.clubId, fileName);
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId).collection('stadium_photos')
          .add({'url': url, 'caption': '', 'uploadedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Η φωτογραφία γηπέδου ανέβηκε'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadPhoto,
        backgroundColor: Colors.blueAccent,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_a_photo, color: Colors.white),
        label: Text(_uploading ? 'Ανέβασμα...' : 'Φωτό Γηπέδου', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs').doc(widget.clubId).collection('stadium_photos')
            .orderBy('uploadedAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stadium, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('Δεν υπάρχουν φωτογραφίες γηπέδου', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 4),
                  Text('Πάτα + για να ανεβάσεις', style: TextStyle(color: AppTheme.cardBg2, fontSize: 12)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.5,
            ),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final url = (doc.data() as Map<String, dynamic>)['url'] as String? ?? '';
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, s) => Container(color: AppTheme.cardBg2, child: const Icon(Icons.broken_image, color: AppTheme.textSecondary)),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => FirebaseFirestore.instance
                          .collection('clubs').doc(widget.clubId).collection('stadium_photos').doc(doc.id).delete(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
