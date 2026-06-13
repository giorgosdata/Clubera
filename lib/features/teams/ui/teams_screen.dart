import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/player_model.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../clubs/ui/create_club_screen.dart' show kCountryList;
import '../../tournaments/ui/tournaments_screen.dart';

const kCountries = [
  {'flag': '🇩🇪', 'name': 'Germany'},
  {'flag': '🇬🇷', 'name': 'Greece'},
  {'flag': '🇮🇹', 'name': 'Italy'},
  {'flag': '🇪🇸', 'name': 'Spain'},
  {'flag': '🇫🇷', 'name': 'France'},
  {'flag': '🇬🇧', 'name': 'England'},
  {'flag': '🇵🇹', 'name': 'Portugal'},
  {'flag': '🇳🇱', 'name': 'Netherlands'},
  {'flag': '🇧🇪', 'name': 'Belgium'},
  {'flag': '🇦🇹', 'name': 'Austria'},
  {'flag': '🇨🇭', 'name': 'Switzerland'},
  {'flag': '🇵🇱', 'name': 'Poland'},
  {'flag': '🇷🇴', 'name': 'Romania'},
  {'flag': '🇷🇸', 'name': 'Serbia'},
  {'flag': '🇭🇷', 'name': 'Croatia'},
  {'flag': '🇹🇷', 'name': 'Turkey'},
  {'flag': '🇺🇦', 'name': 'Ukraine'},
  {'flag': '🇸🇪', 'name': 'Sweden'},
  {'flag': '🇳🇴', 'name': 'Norway'},
  {'flag': '🇩🇰', 'name': 'Denmark'},
  {'flag': '🇨🇿', 'name': 'Czech Republic'},
  {'flag': '🇸🇰', 'name': 'Slovakia'},
  {'flag': '🇭🇺', 'name': 'Hungary'},
  {'flag': '🇧🇬', 'name': 'Bulgaria'},
  {'flag': '🇦🇱', 'name': 'Albania'},
  {'flag': '🇽🇰', 'name': 'Kosovo'},
  {'flag': '🇲🇰', 'name': 'North Macedonia'},
  {'flag': '🇸🇮', 'name': 'Slovenia'},
  {'flag': '🇧🇦', 'name': 'Bosnia'},
  {'flag': '🇲🇪', 'name': 'Montenegro'},
];

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Teams'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'Search'),
            Tab(text: 'Standings'),
            Tab(text: 'Τουρνουά'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _BrowseTab(),
          _SearchTab(),
          _StandingsTab(),
          TournamentsScreen(showAppBar: false),
        ],
      ),
    );
  }
}

// ─── BROWSE TAB ───────────────────────────────────────────────────────────────

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final myClubId = user?.clubId;

    final filtered = kCountries
        .where((c) => c['name']!.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search country...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
            color: AppTheme.primaryLight,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (myClubId != null) ...[
                  _MyClubCard(clubId: myClubId),
                  const SizedBox(height: 16),
                ],
                ...filtered.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CountryTile(flag: c['flag']!, country: c['name']!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MyClubCard extends StatelessWidget {
  final String clubId;
  const _MyClubCard({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final club = ClubModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          clubId,
        );
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0D2B56)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.supportGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.supportGreen, width: 2),
                    image: safeNetworkImage(club.logoUrl) != null
                        ? DecorationImage(
                            image: safeNetworkImage(club.logoUrl)!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: safeNetworkImage(club.logoUrl) == null
                      ? const Icon(Icons.sports_soccer,
                          color: AppTheme.supportGreen, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.supportGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MY CLUB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        club.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${club.city} • ${club.league}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── SEARCH TAB ───────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String _query = '';
  bool _searchClubs = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _searchClubs ? 'Search clubs...' : 'Search players...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ToggleChip(
                    label: 'Clubs',
                    selected: _searchClubs,
                    onTap: () => setState(() => _searchClubs = true),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Players',
                    selected: !_searchClubs,
                    onTap: () => setState(() => _searchClubs = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _query.length < 2
              ? const Center(
                  child: Text(
                    'Type at least 2 characters to search...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : _searchClubs
                  ? _ClubResults(query: _query)
                  : _PlayerResults(query: _query),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryLight : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ClubResults extends StatelessWidget {
  final String query;
  const _ClubResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final queryLower = query.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('\u03a3\u03c6\u03ac\u03bb\u03bc\u03b1: ${snap.error}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clubs = (snap.data?.docs ?? [])
            .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((c) =>
                c.name.toLowerCase().contains(queryLower) ||
                c.city.toLowerCase().contains(queryLower))
            .take(30)
            .toList();
        if (clubs.isEmpty) {
          return Center(
            child: Text(
              'No clubs found for "$query"',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clubs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _ClubListTile(club: clubs[i], rank: i + 1),
        );
      },
    );
  }
}

class _PlayerResults extends StatelessWidget {
  final String query;
  const _PlayerResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final queryLower = query.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('players')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('\u03a3\u03c6\u03ac\u03bb\u03bc\u03b1: ${snap.error}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = (snap.data?.docs ?? [])
            .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((p) => p.isActive && p.name.toLowerCase().contains(queryLower))
            .take(50)
            .toList();
        if (players.isEmpty) {
          return Center(
            child: Text(
              'No players found for "$query"',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _PlayerResultTile(player: players[i]),
        );
      },
    );
  }
}

class _PlayerResultTile extends StatelessWidget {
  final PlayerModel player;
  const _PlayerResultTile({required this.player});

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _posColor(player.position);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                player.number != null ? '#${player.number}' : player.position,
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
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
          if (player.nationality != null)
            Text(player.nationality!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── STANDINGS TAB ────────────────────────────────────────────────────────────

class _StandingsTab extends StatefulWidget {
  const _StandingsTab();

  @override
  State<_StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<_StandingsTab> {
  String _country = kCountryList.first;
  String _category = kCategories.first;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButton<String>(
                  value: _country,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                  items: kCountryList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _country = v!),
                ),
              ),
              const SizedBox(height: 10),
              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kCategories.map((cat) {
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryLight : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? AppTheme.primaryLight : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(child: _StandingsList(country: _country, category: _category)),
      ],
    );
  }
}

class _StandingsList extends StatelessWidget {
  final String country;
  final String category;
  const _StandingsList({required this.country, required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('country', isEqualTo: country)
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Σφάλμα φόρτωσης', style: const TextStyle(color: Colors.red)),
          );
        }
        final clubs = (snap.data?.docs ?? [])
            .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList()
          ..sort((a, b) {
            final ptDiff = b.points.compareTo(a.points);
            if (ptDiff != 0) return ptDiff;
            final gdDiff = b.goalDiff.compareTo(a.goalDiff);
            if (gdDiff != 0) return gdDiff;
            return b.goalsFor.compareTo(a.goalsFor);
          });

        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: AppTheme.cardBg2),
                const SizedBox(height: 12),
                Text(
                  'No clubs in $country / $category',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Clubs can register and select their category',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Club', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                    SizedBox(width: 28, child: Center(child: Text('P', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('W', style: TextStyle(color: AppTheme.supportGreen, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('D', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('L', style: TextStyle(color: AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 32, child: Center(child: Text('GD', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 32, child: Center(child: Text('Pts', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: clubs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) => _StandingRow(club: clubs[i], rank: i + 1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StandingRow extends StatelessWidget {
  final ClubModel club;
  final int rank;
  const _StandingRow({required this.club, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [AppTheme.accent, Colors.grey[400]!, Colors.brown[400]!];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop3 ? rankColors[rank - 1].withValues(alpha: 0.4) : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3 ? rankColors[rank - 1] : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                image: safeNetworkImage(club.logoUrl) != null
                    ? DecorationImage(image: safeNetworkImage(club.logoUrl)!, fit: BoxFit.cover)
                    : null,
              ),
              child: safeNetworkImage(club.logoUrl) == null
                  ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(club.city, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(width: 28, child: Center(child: Text('${club.played}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
            SizedBox(width: 28, child: Center(child: Text('${club.wins}', style: const TextStyle(color: AppTheme.supportGreen, fontSize: 13, fontWeight: FontWeight.bold)))),
            SizedBox(width: 28, child: Center(child: Text('${club.draws}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
            SizedBox(width: 28, child: Center(child: Text('${club.losses}', style: const TextStyle(color: AppTheme.red, fontSize: 13)))),
            SizedBox(width: 32, child: Center(child: Text(
              club.goalDiff >= 0 ? '+${club.goalDiff}' : '${club.goalDiff}',
              style: TextStyle(
                color: club.goalDiff > 0 ? AppTheme.supportGreen : club.goalDiff < 0 ? AppTheme.red : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ))),
            SizedBox(width: 32, child: Center(child: Text('${club.points}', style: const TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.w900)))),
          ],
        ),
      ),
    );
  }
}

// ─── REUSED WIDGETS ───────────────────────────────────────────────────────────

class _CountryTile extends StatelessWidget {
  final String flag;
  final String country;
  const _CountryTile({required this.flag, required this.country});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CountryClubsScreen(country: country, flag: flag),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.navyGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  country,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .where('country', isEqualTo: country)
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  if (count == 0) {
                    return const Icon(Icons.chevron_right, color: AppTheme.textSecondary);
                  }
                  return Row(
                    children: [
                      Text('$count', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(width: 2),
                      const Text('clubs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kTeamFilters = ['All', 'Α΄ Ομάδα', 'Β΄ Ομάδα', 'Γυναικεία'];

class CountryClubsScreen extends StatefulWidget {
  final String country;
  final String flag;
  const CountryClubsScreen({super.key, required this.country, required this.flag});

  @override
  State<CountryClubsScreen> createState() => _CountryClubsScreenState();
}

class _CountryClubsScreenState extends State<CountryClubsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('${widget.flag} ${widget.country}'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _kTeamFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _kTeamFilters[i];
                final selected = _filter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  selectedColor: AppTheme.primaryLight,
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
                  .where('country', isEqualTo: widget.country)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = (snap.data?.docs ?? [])
                    .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .toList()
                  ..sort((a, b) => b.votes.compareTo(a.votes));
                final clubs = _filter == 'All'
                    ? all
                    : all.where((c) => c.category == _filter).toList();
                if (clubs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.flag, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'No clubs in this category',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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
                    itemCount: clubs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _ClubListTile(club: clubs[i], rank: i + 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubListTile extends StatelessWidget {
  final ClubModel club;
  final int rank;
  const _ClubListTile({required this.club, required this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                image: safeNetworkImage(club.logoUrl) != null
                    ? DecorationImage(image: safeNetworkImage(club.logoUrl)!, fit: BoxFit.cover)
                    : null,
              ),
              child: safeNetworkImage(club.logoUrl) == null
                  ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 26)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          club.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          club.category,
                          style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${club.city} • ${club.league}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.how_to_vote, size: 13, color: AppTheme.accent),
                      const SizedBox(width: 3),
                      Text('${club.votes} votes', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.people, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text('${club.followers} fans', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
