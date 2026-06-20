import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/match_model.dart';
import '../../../models/player_model.dart';
import '../../../models/reward_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/fan_stats_model.dart';
import '../../../models/sponsor_model.dart';
import '../../matches/ui/match_card.dart';
import 'player_profile_screen.dart';
import 'announcements_tab.dart';
import '../../matches/ui/match_detail_screen.dart';
import '../../profile/widgets/fan_card.dart';

class ClubProfileScreen extends StatefulWidget {
  final String clubId;
  const ClubProfileScreen({super.key, required this.clubId});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 10, vsync: this);
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Club not found'));
          }
          final club = ClubModel.fromMap(
            snap.data!.data() as Map<String, dynamic>,
            widget.clubId,
          );
          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              _buildHeader(ctx, club),
              SliverToBoxAdapter(child: _StatsBar(club: club)),
              SliverToBoxAdapter(
                child: _VoteDonatBar(club: club, clubId: widget.clubId),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Info'),
                      Tab(text: 'Players'),
                      Tab(text: 'Stats'),
                      Tab(text: 'Matches'),
                      Tab(text: 'Transfers'),
                      Tab(text: 'Feed'),
                      Tab(text: 'Games'),
                      Tab(text: 'Sponsors'),
                      Tab(text: 'Top Fans'),
                      Tab(text: 'Ανακοινώσεις'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tab,
              children: [
                _InfoTab(club: club),
                _PlayersPublicTab(clubId: widget.clubId, clubName: club.name),
                _StatsTab(clubId: widget.clubId),
                _MatchesTab(clubId: widget.clubId),
                _TransfersTab(clubId: widget.clubId),
                _FeedTab(clubId: widget.clubId),
                _RewardsPublicTab(clubId: widget.clubId),
                _SponsorsTab(clubId: widget.clubId),
                _TopFansTab(clubId: widget.clubId),
                AnnouncementsTab(clubId: widget.clubId),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, ClubModel club) {
    final user = context.watch<AppProvider>().user;
    final isFollowing = user?.followedClubs.contains(widget.clubId) ?? false;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (club.coverUrl != null)
              Image.network(club.coverUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF080E2A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppTheme.surface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryLight,
                        width: 2,
                      ),
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
                            size: 38,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
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
                          club.league,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (user != null)
                    ElevatedButton(
                      onPressed: () =>
                          _toggleFollow(context, user.uid, isFollowing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? AppTheme.cardBg2
                            : AppTheme.primaryLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(isFollowing ? '✓ Following' : '+ Follow'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    String uid,
    bool isFollowing,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final clubRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId);
    try {
      final batch = FirebaseFirestore.instance.batch();
      if (isFollowing) {
        batch.update(userRef, {'followedClubs': FieldValue.arrayRemove([widget.clubId])});
        batch.update(clubRef, {'followers': FieldValue.increment(-1)});
        await batch.commit();
        await NotificationsService.unsubscribe('club_${widget.clubId}');
      } else {
        batch.update(userRef, {'followedClubs': FieldValue.arrayUnion([widget.clubId])});
        batch.update(clubRef, {'followers': FieldValue.increment(1)});
        await batch.commit();
        await NotificationsService.subscribe('club_${widget.clubId}');
      }
      if (context.mounted) {
        final prov = context.read<AppProvider>();
        final newList = List<String>.from(prov.user!.followedClubs);
        if (isFollowing) {
          newList.remove(widget.clubId);
        } else {
          newList.add(widget.clubId);
        }
        prov.updateUser(prov.user!.copyWith(followedClubs: newList));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }
}

// ─── VOTE + DONATE BAR ────────────────────────────────────────────────────────

class _VoteDonatBar extends StatelessWidget {
  final ClubModel club;
  final String clubId;
  const _VoteDonatBar({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VoteButton(club: club, clubId: clubId, userId: user?.uid),
          ),
          const SizedBox(width: 10),
          Expanded(child: _DonateButton(club: club)),
        ],
      ),
    );
  }
}

class _VoteButton extends StatefulWidget {
  final ClubModel club;
  final String clubId;
  final String? userId;
  const _VoteButton({
    required this.club,
    required this.clubId,
    required this.userId,
  });

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton> {
  bool _hasVoted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkVote();
  }

  Future<void> _checkVote() async {
    if (widget.userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('votes')
        .doc(widget.userId)
        .get();
    if (mounted) setState(() => _hasVoted = doc.exists);
  }

  Future<void> _vote() async {
    if (widget.userId == null || _loading) return;
    setState(() => _loading = true);
    final voteRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('votes')
        .doc(widget.userId);
    final clubRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId);
    try {
      final batch = FirebaseFirestore.instance.batch();
      if (_hasVoted) {
        batch.delete(voteRef);
        batch.update(clubRef, {'votes': FieldValue.increment(-1)});
        await batch.commit();
        if (mounted) setState(() => _hasVoted = false);
      } else {
        batch.set(voteRef, {'votedAt': FieldValue.serverTimestamp()});
        batch.update(clubRef, {'votes': FieldValue.increment(1)});
        await batch.commit();
        if (mounted) setState(() => _hasVoted = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _vote,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _hasVoted
              ? AppTheme.accent.withValues(alpha: 0.2)
              : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasVoted ? AppTheme.accent : AppTheme.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.how_to_vote,
              color: _hasVoted ? AppTheme.accent : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.club.votes}',
              style: TextStyle(
                color: _hasVoted ? AppTheme.accent : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              _hasVoted ? 'Voted ✓' : 'Vote',
              style: TextStyle(
                color: _hasVoted ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonateButton extends StatelessWidget {
  final ClubModel club;
  const _DonateButton({required this.club});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDonate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.blueGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Support',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              'Donate',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showDonate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          bool processing = false;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.favorite, color: AppTheme.primaryLight, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Support ${club.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Help your club grow! Donations go directly to the club.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                _donateAmount(ctx, '5', '☕', processing, (v) => setSheet(() => processing = v)),
                const SizedBox(height: 10),
                _donateAmount(ctx, '10', '⚽', processing, (v) => setSheet(() => processing = v)),
                const SizedBox(height: 10),
                _donateAmount(ctx, '25', '🏆', processing, (v) => setSheet(() => processing = v)),
                const SizedBox(height: 10),
                _donateAmount(ctx, '50', '🌟', processing, (v) => setSheet(() => processing = v)),
                const SizedBox(height: 16),
                const Text(
                  'Payment integration coming soon',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _donateAmount(BuildContext context, String amount, String emoji,
      bool processing, void Function(bool) setProcessing) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: processing
            ? null
            : () async {
                setProcessing(true);
                await _processDonation(context, double.parse(amount));
                // _processDonation always calls navigator.pop() — the sheet
                // is already dismissed here, so setProcessing(false) would
                // call setState on a disposed widget and throw.
              },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.divider),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          '$emoji  €$amount',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _processDonation(BuildContext context, double amount) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final prov = context.read<AppProvider>();
    final user = prov.user;
    if (user == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Login required'), backgroundColor: AppTheme.red),
      );
      return;
    }
    if (user.balance < amount) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Insufficient balance (€${user.balance.toStringAsFixed(2)}). Top up your wallet.'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final donationRef = FirebaseFirestore.instance.collection('donations').doc();
      batch.update(userRef, {'balance': FieldValue.increment(-amount)});
      batch.set(donationRef, {
        'userId': user.uid,
        'userName': user.name,
        'clubId': club.id,
        'clubName': club.name,
        'amount': amount,
        'type': 'donate',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      prov.updateUser(user.copyWith(balance: user.balance - amount));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Thank you! €${amount.toStringAsFixed(0)} donated to ${club.name} 💙'),
          backgroundColor: AppTheme.supportGreen,
        ),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Donation failed: $e'), backgroundColor: AppTheme.red),
      );
    }
  }
}

// ─── STATS BAR ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final ClubModel club;
  const _StatsBar({required this.club});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      gradient: AppTheme.navyGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat('${club.played}', 'Played'),
        _divider(),
        _stat('${club.wins}', 'Won'),
        _divider(),
        _stat('${club.draws}', 'Draw'),
        _divider(),
        _stat('${club.losses}', 'Lost'),
        _divider(),
        _stat('${club.points}', 'Pts'),
        _divider(),
        _stat('${club.votes}', 'Fans'),
      ],
    ),
  );

  Widget _stat(String val, String label) => Column(
    children: [
      Text(
        val,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
      ),
    ],
  );

  Widget _divider() => Container(width: 1, height: 32, color: AppTheme.divider);
}

// ─── TABS ─────────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final ClubModel club;
  const _InfoTab({required this.club});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (club.description.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                club.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Club Info',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.location_city_outlined, 'City', club.city),
          _infoRow(Icons.public, 'Country', club.country),
          _infoRow(Icons.emoji_events_outlined, 'League', club.league),
          _infoRow(
            Icons.category_outlined,
            'Category',
            'Category ${club.category}',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: AppTheme.navyGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.primaryLight, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

// ─── PLAYERS PUBLIC TAB ───────────────────────────────────────────────────────

class _PlayersPublicTab extends StatelessWidget {
  final String clubId;
  final String clubName;
  const _PlayersPublicTab({required this.clubId, required this.clubName});

  static const _positions = ['GK', 'DEF', 'MID', 'FWD'];
  static const _posLabels = {
    'GK': 'ΤΕΡΜΑΤΟΦΥΛΑΚΕΣ',
    'DEF': 'ΑΜΥΝΤΙΚΟΙ',
    'MID': 'ΜΕΣΟΙ',
    'FWD': 'ΕΠΙΘΕΤΙΚΟΙ',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
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
            .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((p) => p.isActive)
            .toList();
        if (players.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text('No players listed yet', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            for (final pos in _positions) ...[
              Builder(builder: (_) {
                final group = players.where((p) => p.position == pos).toList();
                if (group.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _posColor(pos),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _posLabels[pos] ?? pos,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${group.length}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: group
                          .map((p) => _PlayerGridTile(
                                player: p,
                                clubId: clubId,
                                clubName: clubName,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ],
          ],
        );
      },
    );
  }

  static Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }
}

class _PlayerGridTile extends StatelessWidget {
  final PlayerModel player;
  final String clubId;
  final String clubName;
  const _PlayerGridTile({required this.player, required this.clubId, required this.clubName});

  Color get _color {
    switch (player.position) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = player.name.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(player: player, clubId: clubId, clubName: clubName),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Photo or avatar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: player.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: player.photoUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _AvatarFallback(initials: initials, color: _color),
                          )
                        : _AvatarFallback(initials: initials, color: _color),
                  ),
                  // Number badge
                  if (player.number != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${player.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  // Injury indicator
                  if (player.isInjured)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.liveRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_services, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
            ),
            // Name + position strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: _color.withValues(alpha: 0.4))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    player.name.split(' ').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (player.goals > 0)
                    Text(
                      '⚽ ${player.goals}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final Color color;
  const _AvatarFallback({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String value;
  const _StatPill(this.emoji, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        '$emoji $value',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    );
  }
}

// ─── MATCHES TAB ─────────────────────────────────────────────────────────────

class _MatchesTab extends StatelessWidget {
  final String clubId;
  const _MatchesTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where(
            Filter.or(
              Filter('homeClubId', isEqualTo: clubId),
              Filter('awayClubId', isEqualTo: clubId),
            ),
          )
          .orderBy('scheduledAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (matches.isEmpty) {
          return const Center(
            child: Text(
              'No matches yet',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => MatchCard(
            match: matches[i],
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => MatchDetailScreen(matchId: matches[i].id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransfersTab extends StatelessWidget {
  final String clubId;
  const _TransfersTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('transfers')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final transfers = (snap.data?.docs ?? [])
            .map(
              (d) =>
                  TransferModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (transfers.isEmpty) {
          return const Center(
            child: Text(
              'No transfers recorded',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        final ins = transfers.where((t) => t.type == 'in').toList();
        final outs = transfers.where((t) => t.type == 'out').toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ins.isNotEmpty) ...[
                const Text(
                  'Arrivals',
                  style: TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...ins.map((t) => _TransferRow(transfer: t)),
                const SizedBox(height: 16),
              ],
              if (outs.isNotEmpty) ...[
                const Text(
                  'Departures',
                  style: TextStyle(
                    color: AppTheme.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...outs.map((t) => _TransferRow(transfer: t)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TransferRow extends StatelessWidget {
  final TransferModel transfer;
  const _TransferRow({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final isIn = transfer.type == 'in';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isIn
              ? AppTheme.green.withValues(alpha: 0.3)
              : AppTheme.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isIn
                  ? AppTheme.green.withValues(alpha: 0.15)
                  : AppTheme.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? AppTheme.green : AppTheme.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.playerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (isIn && transfer.fromClub != null)
                  Text(
                    'From: ${transfer.fromClub}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  )
                else if (!isIn && transfer.toClub != null)
                  Text(
                    'To: ${transfer.toClub}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${transfer.date.day}/${transfer.date.month}/${transfer.date.year}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final String clubId;
  const _FeedTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('feed')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final posts = snap.data?.docs ?? [];
        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final d = posts[i].data() as Map<String, dynamic>;
            final imageUrl = d['imageUrl'] as String?;
            final text = (d['text'] as String?)?.trim() ?? '';
            return Container(
              decoration: BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          (d['createdAt'] as dynamic)?.toDate().toString().substring(0, 16) ?? '',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── STATS TAB ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  final String clubId;
  const _StatsTab({required this.clubId});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String get clubId => widget.clubId;

  @override
  void initState() {
    super.initState();
    _future = _loadStats();
  }

  Future<void> _refresh() async {
    final next = _loadStats();
    setState(() => _future = next);
    await next;
  }

  Future<List<Map<String, dynamic>>> _loadStats() async {
    final homeSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('homeClubId', isEqualTo: clubId)
        .get();
    final awaySnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('awayClubId', isEqualTo: clubId)
        .get();

    final matchIds = [
      ...homeSnap.docs.map((d) => d.id),
      ...awaySnap.docs.map((d) => d.id),
    ];

    if (matchIds.isEmpty) return [];

    final stats = <String, Map<String, dynamic>>{};

    await Future.wait(matchIds.map((matchId) async {
      final eventsSnap = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('events')
          .where('clubId', isEqualTo: clubId)
          .get();

      for (final doc in eventsSnap.docs) {
        final data = doc.data();
        final playerName = data['playerName'] as String? ?? '';
        if (playerName.isEmpty) continue;

        stats.putIfAbsent(playerName, () => {
          'name': playerName,
          'goals': 0,
          'assists': 0,
          'yellowCards': 0,
          'redCards': 0,
        });

        switch (data['type'] as String? ?? '') {
          case 'goal':
            stats[playerName]!['goals'] = (stats[playerName]!['goals'] as int) + 1;
          case 'assist':
            stats[playerName]!['assists'] = (stats[playerName]!['assists'] as int) + 1;
          case 'yellow_card':
            stats[playerName]!['yellowCards'] = (stats[playerName]!['yellowCards'] as int) + 1;
          case 'red_card':
            stats[playerName]!['redCards'] = (stats[playerName]!['redCards'] as int) + 1;
        }
      }
    }));

    final result = stats.values.toList();
    result.sort((a, b) {
      final gDiff = (b['goals'] as int).compareTo(a['goals'] as int);
      if (gDiff != 0) return gDiff;
      return (b['assists'] as int).compareTo(a['assists'] as int);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data ?? [];
        if (stats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text(
                  'No stats yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'Stats are collected from match events',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Player',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Text('G', style: TextStyle(color: AppTheme.supportGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Text('A', style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Text('YC', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Text('RC', style: TextStyle(color: AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...stats.map((s) => _StatsRow(data: s)),
            const SizedBox(height: 80),
          ],
        );
      },
    ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data['name'] as String,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _statCell('${data['goals']}', AppTheme.supportGreen),
          _statCell('${data['assists']}', AppTheme.primaryLight),
          _statCell('${data['yellowCards']}', AppTheme.accent),
          _statCell('${data['redCards']}', AppTheme.red),
        ],
      ),
    );
  }

  Widget _statCell(String value, Color color) {
    final isZero = value == '0';
    return SizedBox(
      width: 44,
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: isZero ? AppTheme.textSecondary : color,
            fontWeight: isZero ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─── TAB BAR DELEGATE ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xCC0A1628), child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

// ─── REWARDS PUBLIC TAB ───────────────────────────────────────────────────────

class _RewardsPublicTab extends StatelessWidget {
  final String clubId;
  const _RewardsPublicTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rewards')
          .where('clubId', isEqualTo: clubId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rewards = (snap.data?.docs ?? [])
            .map((d) => RewardModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        if (rewards.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_outlined, size: 56, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text('No rewards yet', style: TextStyle(color: AppTheme.textSecondary)),
                SizedBox(height: 6),
                Text(
                  'The club hasn\'t added rewards yet',
                  style: TextStyle(color: AppTheme.cardBg2, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user != null
                          ? 'You have ${user.points} pts — redeem them for club games!'
                          : 'Earn points by voting & predicting matches!',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            ...rewards.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.supportGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(r.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (r.description.isNotEmpty)
                            Text(
                              r.description,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.supportGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.supportGreen.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${r.pointsCost} pts',
                            style: const TextStyle(
                              color: AppTheme.supportGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: OutlinedButton(
                            onPressed: user == null
                                ? null
                                : user.points >= r.pointsCost
                                    ? () => _showRedeemDialog(ctx, r, user.points)
                                    : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accent,
                              side: const BorderSide(color: AppTheme.accent),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text(
                              user != null && user.points >= r.pointsCost
                                  ? 'Redeem'
                                  : 'Locked',
                            ),
                          ),
                        ),
                      ],
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

  void _showRedeemDialog(BuildContext context, RewardModel reward, int userPoints) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool processing = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: Row(
              children: [
                Text(reward.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reward.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
            content: Text(
              'Redeem "${reward.title}" for ${reward.pointsCost} pts?\n\nYour balance: $userPoints pts → ${userPoints - reward.pointsCost} pts remaining.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: processing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.supportGreen),
            onPressed: processing ? null : () async {
              setDlg(() => processing = true);
              final user = context.read<AppProvider>().user;
              final provider = context.read<AppProvider>();
              if (user == null) return;
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'points': FieldValue.increment(-reward.pointsCost)});
                provider.updateUser(
                  user.copyWith(points: user.points - reward.pointsCost),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${reward.emoji} Game redeemed! Contact the club to claim it.'),
                      backgroundColor: AppTheme.supportGreen,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) setDlg(() => processing = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to redeem: $e'), backgroundColor: AppTheme.red),
                  );
                }
              }
            },
            child: const Text('Redeem'),
          ),
          ],
        ),
        );
      },
    );
  }
}

// ─── SPONSORS TAB ─────────────────────────────────────────────────────────────

class _SponsorsTab extends StatelessWidget {
  final String clubId;
  const _SponsorsTab({required this.clubId});

  Future<void> _open(BuildContext context, SponsorModel s) async {
    final url = s.pdfUrl ?? s.website;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsors')
          .where('isActive', isEqualTo: true)
          .where('clubId', isEqualTo: clubId)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Σφάλμα: ${snap.error}',
                style: const TextStyle(color: AppTheme.textSecondary)),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sponsors = (snap.data?.docs ?? [])
            .map((d) =>
                SponsorModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        if (sponsors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text('No sponsors yet',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: sponsors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final s = sponsors[i];
            final hasLink = (s.pdfUrl ?? s.website) != null;
            final tierColors = {
              'platinum': const Color(0xFF7DF9FF),
              'gold': const Color(0xFFFFD700),
              'silver': const Color(0xFFC0C0C0),
              'bronze': const Color(0xFFCD7F32),
            };
            final tierColor = tierColors[s.tier] ?? AppTheme.textSecondary;
            return GestureDetector(
              onTap: hasLink ? () => _open(ctx, s) : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasLink
                        ? tierColor.withValues(alpha: 0.5)
                        : AppTheme.divider,
                  ),
                ),
                child: Row(
                  children: [
                    if (s.logoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          s.logoUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.business,
                            color: AppTheme.textSecondary,
                            size: 40,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business,
                            color: AppTheme.textSecondary, size: 28),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.tier.toUpperCase(),
                              style: TextStyle(
                                color: tierColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (s.website != null && s.website!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              s.website!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasLink)
                      Column(
                        children: [
                          Icon(
                            s.pdfUrl != null
                                ? Icons.picture_as_pdf
                                : Icons.open_in_new,
                            color: AppTheme.primaryLight,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.pdfUrl != null ? 'PDF' : 'Visit',
                            style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── TOP FANS TAB ─────────────────────────────────────────────────────────────

class _TopFansTab extends StatelessWidget {
  final String clubId;
  const _TopFansTab({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fan_stats')
          .where('clubId', isEqualTo: clubId)
          .orderBy('clubScore', descending: true)
          .limit(30)
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
        final fans = (snap.data?.docs ?? [])
            .map((d) =>
                FanStatsModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((f) => f.clubScore > 0)
            .toList();

        if (fans.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text(
                  'No top fans yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Follow this club, predict matches and donate to climb the leaderboard',
                    style: TextStyle(color: AppTheme.cardBg2, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: fans.length,
          itemBuilder: (ctx, i) => TopFanRow(rank: i + 1, stats: fans[i]),
        );
      },
    );
  }
}
