import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/match_model.dart';
import '../../../models/club_model.dart';
import '../../../models/news_model.dart';
import '../../../models/reward_model.dart';
import '../../../models/sponsor_model.dart';
import '../../matches/ui/match_card.dart';
import '../../matches/ui/match_detail_screen.dart';
import '../../matches/ui/matches_screen.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../teams/ui/teams_screen.dart';
import '../../search/ui/search_screen.dart';
import '../../gamification/ui/games_screen.dart';
import 'news_detail_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            pinned: true,
            title: Image.asset('assets/images/logo.jpeg', height: 36),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                tooltip: 'Αναζήτηση',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              _NotificationsBell(userId: user?.uid),
            ],
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Latest'),
                Tab(text: 'Play'),
                Tab(text: 'Rewards'),
                Tab(text: 'News'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _LatestTab(user: user),
            const _GamesTab(),
            _RewardsTab(user: user),
            const _NewsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── LATEST TAB ──────────────────────────────────────────────────────────────

class _LatestTab extends StatelessWidget {
  final user;
  const _LatestTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
      color: AppTheme.primaryLight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _HeroMatchCard(),
          _PredictGameBanner(),
          _LiveSection(),
          _UpcomingSection(),
          _TopClubsSection(),
          _SponsorsSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─── GAMES TAB ───────────────────────────────────────────────────────────────

class _GamesTab extends StatelessWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context) {
    return const GamesContent();
  }
}

// ─── REWARDS TAB ─────────────────────────────────────────────────────────────

class _RewardsTab extends StatelessWidget {
  final user;
  const _RewardsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rewards')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return const SizedBox.shrink();
        final rewards = (snap.data?.docs ?? [])
            .map((d) => RewardModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        if (rewards.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 16),
                Text(
                  'No rewards yet',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Club admins can add rewards from their Club Panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final userPoints = user?.points ?? 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                  const Icon(Icons.stars, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user != null
                          ? 'You have $userPoints pts — earn more by voting & predicting!'
                          : 'Sign in to earn points and redeem rewards!',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$userPoints pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ...rewards.map((r) => _RewardHomeCard(reward: r, userPoints: userPoints)),
          ],
        );
      },
    );
  }
}

class _RewardHomeCard extends StatelessWidget {
  final RewardModel reward;
  final int userPoints;
  const _RewardHomeCard({required this.reward, required this.userPoints});

  @override
  Widget build(BuildContext context) {
    final canRedeem = userPoints >= reward.pointsCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canRedeem
              ? AppTheme.supportGreen.withOpacity(0.4)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Text(reward.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (reward.description.isNotEmpty)
                  Text(
                    reward.description,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                if (reward.clubName != null)
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 11, color: AppTheme.primaryLight),
                      const SizedBox(width: 4),
                      Text(
                        reward.clubName!,
                        style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.supportGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.supportGreen.withOpacity(0.4)),
                ),
                child: Text(
                  '${reward.pointsCost} pts',
                  style: const TextStyle(
                    color: AppTheme.supportGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 76,
                child: OutlinedButton(
                  onPressed: canRedeem ? () => _showRedeem(context) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canRedeem ? AppTheme.accent : AppTheme.textSecondary,
                    side: BorderSide(
                      color: canRedeem ? AppTheme.accent : AppTheme.divider,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  child: Text(canRedeem ? 'Redeem' : 'Locked'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRedeem(BuildContext context) {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
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
          'Redeem "${reward.title}" for ${reward.pointsCost} pts?\n\nBalance: ${user.points} pts → ${user.points - reward.pointsCost} pts remaining.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: processing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.supportGreen),
            onPressed: processing ? null : () async {
              setDlg(() => processing = true);
              try {
                final provider = context.read<AppProvider>();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'points': FieldValue.increment(-reward.pointsCost)});
                provider.updateUser(user.copyWith(points: user.points - reward.pointsCost));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('${reward.emoji} Redeemed! Contact the club to claim it.'),
                    backgroundColor: AppTheme.supportGreen,
                  ),
                );
              } catch (e) {
                if (ctx.mounted) setDlg(() => processing = false);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
                );
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

// ─── NEWS TAB ────────────────────────────────────────────────────────────────

class _NewsTab extends StatelessWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .orderBy('publishedAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return const SizedBox.shrink();
        final articles = (snap.data?.docs ?? [])
            .map(
              (d) => NewsModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (articles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text(
                  'No news yet',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
          color: AppTheme.primaryLight,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: articles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _NewsCard(article: articles[i]),
          ),
        );
      },
    );
  }
}

// ─── HERO MATCH CARD ─────────────────────────────────────────────────────────

class _HeroMatchCard extends StatefulWidget {
  @override
  State<_HeroMatchCard> createState() => _HeroMatchCardState();
}

class _HeroMatchCardState extends State<_HeroMatchCard> {
  final PageController _pageCtrl = PageController();
  Timer? _timer;
  int _currentPage = 0;
  List<MatchModel> _liveMatches = [];

  void _startTimer() {
    _timer?.cancel();
    if (_liveMatches.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      _currentPage = (_currentPage + 1) % _liveMatches.length;
      _pageCtrl.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', whereIn: ['live', 'halftime'])
          .orderBy('scheduledAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final liveMatches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();

        if (liveMatches.isEmpty) return _HeroUpcomingCard();

        // Restart timer if matches changed
        if (_liveMatches.length != liveMatches.length) {
          _liveMatches = liveMatches;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        } else {
          _liveMatches = liveMatches;
        }

        if (liveMatches.length == 1) {
          return _HeroLiveCard(match: liveMatches.first);
        }

        return Stack(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: liveMatches.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _HeroLiveCard(match: liveMatches[i]),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  liveMatches.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppTheme.liveRed
                          : Colors.white30,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroLiveCard extends StatelessWidget {
  final MatchModel match;
  const _HeroLiveCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B3E), Color(0xFF1A2B6B), Color(0xFF0A3D1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppTheme.liveRed.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.liveRed.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Stadium pattern overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(painter: _StadiumPatternPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.liveRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 6),
                            SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (match.minute != null)
                        Text(
                          "${match.minute}'",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _HeroTeam(
                        name: match.homeClubName,
                        logoUrl: match.homeClubLogo,
                      ),
                      Column(
                        children: [
                          Text(
                            '${match.homeScore}  :  ${match.awayScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            match.league,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      _HeroTeam(
                        name: match.awayClubName,
                        logoUrl: match.awayClubLogo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tap to watch live',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
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

class _HeroTeam extends StatelessWidget {
  final String name;
  final String? logoUrl;
  const _HeroTeam({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.cardBg2,
            shape: BoxShape.circle,
            image: safeNetworkImage(logoUrl) != null
                ? DecorationImage(
                    image: safeNetworkImage(logoUrl)!,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: safeNetworkImage(logoUrl) == null
              ? const Icon(
                  Icons.sports_soccer,
                  color: AppTheme.primaryLight,
                  size: 24,
                )
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HeroUpcomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .where('scheduledAt', isGreaterThan: Timestamp.now())
          .orderBy('scheduledAt')
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();

        if (matches.isEmpty) return _HeroEmptyCard();

        final match = matches.first;
        final dt = match.scheduledAt;
        final dateStr = DateFormat('EEEE, d MMM • HH:mm').format(dt);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: match.id),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D1B3E),
                  Color(0xFF1A237E),
                  Color(0xFF0D2B56),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(painter: _StadiumPatternPainter()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryLight.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          'NEXT MATCH',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _HeroTeam(
                            name: match.homeClubName,
                            logoUrl: match.homeClubLogo,
                          ),
                          Column(
                            children: [
                              const Text(
                                'VS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                match.league,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          _HeroTeam(
                            name: match.awayClubName,
                            logoUrl: match.awayClubLogo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(child: _MatchCountdown(scheduledAt: dt)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchCountdown extends StatefulWidget {
  final DateTime scheduledAt;
  const _MatchCountdown({required this.scheduledAt});

  @override
  State<_MatchCountdown> createState() => _MatchCountdownState();
}

class _MatchCountdownState extends State<_MatchCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.scheduledAt.difference(DateTime.now());
    if (_remaining.isNegative) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = widget.scheduledAt.difference(DateTime.now());
      if (mounted) setState(() => _remaining = r);
      if (r.isNegative) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, color: Colors.white54, size: 14),
        const SizedBox(width: 4),
        if (d > 0) _unit('$d', 'μέρες'),
        if (d > 0) const SizedBox(width: 8),
        _unit(_pad(h), 'ώρες'),
        const SizedBox(width: 8),
        _unit(_pad(m), 'λεπτά'),
        const SizedBox(width: 8),
        _unit(_pad(s), 'δευτ.'),
      ],
    );
  }

  Widget _unit(String value, String label) => Column(
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
    ],
  );

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _HeroEmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppTheme.navyGradient,
        border: Border.all(color: AppTheme.divider),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _StadiumPatternPainter()),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_soccer,
                  size: 40,
                  color: AppTheme.primaryLight,
                ),
                SizedBox(height: 8),
                Text(
                  'No upcoming matches',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Check back soon',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PREDICT GAME BANNER ─────────────────────────────────────────────────────

class _PredictGameBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to matches screen coupon tab - using bottom nav index 1
        // This is a simplified navigation; in production you'd use a router
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Go to Matches → Coupon tab to predict today\'s games!',
            ),
            backgroundColor: AppTheme.primaryLight,
            duration: Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF4361EE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sports_score,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Predict & Win Points',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Pick today\'s match winners and earn up to 50 pts',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Play',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LIVE SECTION ─────────────────────────────────────────────────────────────

class _LiveSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', whereIn: ['live', 'halftime'])
          .orderBy('scheduledAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (matches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.liveRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 7),
                        SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${matches.length} ongoing',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => SizedBox(
                  width: 260,
                  child: MatchCard(
                    match: matches[i],
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) =>
                            MatchDetailScreen(matchId: matches[i].id),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── UPCOMING SECTION ────────────────────────────────────────────────────────

class _UpcomingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .where('scheduledAt', isGreaterThan: Timestamp.now())
          .orderBy('scheduledAt')
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (matches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MatchesScreen()),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),
          ],
        );
      },
    );
  }
}

// ─── TOP CLUBS SECTION ───────────────────────────────────────────────────────

class _TopClubsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .orderBy('votes', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final clubs = (snap.data?.docs ?? [])
            .map(
              (d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (clubs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: AppTheme.accent,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Top Clubs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamsScreen()),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: clubs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ClubProfileScreen(clubId: clubs[i].id),
                    ),
                  ),
                  child: _TopClubChip(club: clubs[i], rank: i + 1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopClubChip extends StatelessWidget {
  final ClubModel club;
  final int rank;
  const _TopClubChip({required this.club, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: rank == 1 ? AppTheme.accent : AppTheme.divider,
                  width: rank == 1 ? 2 : 1,
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
                      size: 28,
                    )
                  : null,
            ),
            if (rank <= 3)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? AppTheme.accent
                        : rank == 2
                        ? Colors.grey[400]!
                        : Colors.brown[400]!,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 68,
          child: Text(
            club.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_vote, size: 10, color: AppTheme.accent),
            const SizedBox(width: 2),
            Text(
              '${club.votes}',
              style: const TextStyle(color: AppTheme.accent, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── SPONSORS SECTION ────────────────────────────────────────────────────────

class _SponsorsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsors')
          .where('isActive', isEqualTo: true)
          .where('clubId', isNull: true) // global sponsors only
          .limit(6)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final sponsors = (snap.data?.docs ?? [])
            .map(
              (d) =>
                  SponsorModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (sponsors.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: AppTheme.textSecondary,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Official Partners',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: sponsors
                        .map((s) => _SponsorChip(sponsor: s))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Proud Sponsors of Clubera',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SponsorChip extends StatelessWidget {
  final SponsorModel sponsor;
  const _SponsorChip({required this.sponsor});

  Future<void> _open(BuildContext context) async {
    final url = sponsor.pdfUrl ?? sponsor.website;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = (sponsor.pdfUrl ?? sponsor.website) != null;
    return GestureDetector(
      onTap: hasLink ? () => _open(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasLink ? AppTheme.primaryLight.withValues(alpha: 0.4) : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sponsor.logoUrl != null) ...[
              Image.network(
                sponsor.logoUrl!,
                height: 28,
                errorBuilder: (_, _, _) => Text(
                  sponsor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ] else
              Text(
                sponsor.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            if (hasLink) ...[
              const SizedBox(width: 6),
              Icon(
                sponsor.pdfUrl != null ? Icons.picture_as_pdf : Icons.open_in_new,
                size: 14,
                color: AppTheme.primaryLight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── NEWS CARD ───────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final NewsModel article;
  const _NewsCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  article.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    color: AppTheme.cardBg2,
                    child: const Icon(
                      Icons.article,
                      color: AppTheme.textSecondary,
                      size: 40,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.excerpt,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        article.author,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('d MMM').format(article.publishedAt),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

// ─── STADIUM PATTERN PAINTER ─────────────────────────────────────────────────

class _StadiumPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw subtle arc lines like stadium lights/circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 1.1),
        size.height * 0.6 * i,
        paint,
      );
    }
    // Bottom corner arcs
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width, size.height),
        radius: size.width * 0.4,
      ),
      -3.14,
      3.14 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NotificationsBell extends StatelessWidget {
  final String? userId;
  const _NotificationsBell({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        final unread = snap.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
