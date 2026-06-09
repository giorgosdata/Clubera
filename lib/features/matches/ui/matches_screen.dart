import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/match_model.dart';
import '../../../models/prediction_model.dart';
import '../../../core/providers/app_provider.dart';
import 'match_card.dart';
import 'match_detail_screen.dart';
import 'create_match_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
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
    final canCreate = user?.role == 'club' || user?.role == 'admin';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Matches'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Coupon'),
            Tab(text: 'Results'),
          ],
        ),
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primaryLight),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const _MatchList(filter: 'live'),
          const _MatchListWithDatePicker(filter: 'upcoming'),
          _CouponTab(userId: user?.uid ?? ''),
          const _MatchListWithDatePicker(filter: 'finished'),
        ],
      ),
    );
  }
}

// ─── MATCH LIST ──────────────────────────────────────────────────────────────

class _MatchList extends StatelessWidget {
  final String filter;
  const _MatchList({required this.filter});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('matches');
    if (filter == 'live') {
      query = query
          .where('status', whereIn: ['live', 'halftime'])
          .orderBy('scheduledAt', descending: true);
    } else if (filter == 'upcoming') {
      query = query
          .where('status', isEqualTo: 'upcoming')
          .orderBy('scheduledAt');
    } else {
      query = query
          .where('status', isEqualTo: 'finished')
          .orderBy('scheduledAt', descending: true);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  size: 64,
                  color: AppTheme.cardBg2,
                ),
                const SizedBox(height: 12),
                Text(
                  filter == 'live'
                      ? 'No live matches right now'
                      : 'No matches found',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
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
        );
      },
    );
  }
}

// ─── MATCH LIST WITH DATE PICKER ─────────────────────────────────────────────

class _MatchListWithDatePicker extends StatefulWidget {
  final String filter;
  const _MatchListWithDatePicker({required this.filter});

  @override
  State<_MatchListWithDatePicker> createState() =>
      _MatchListWithDatePickerState();
}

class _MatchListWithDatePickerState extends State<_MatchListWithDatePicker> {
  late DateTime _selectedDate;
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    if (widget.filter == 'upcoming') {
      _dates = List.generate(7, (i) => _selectedDate.add(Duration(days: i)));
    } else {
      _dates = List.generate(
        7,
        (i) => _selectedDate.subtract(Duration(days: 6 - i)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DatePickerRow(
          dates: _dates,
          selectedDate: _selectedDate,
          onDateSelected: (d) => setState(() => _selectedDate = d),
        ),
        Expanded(
          child: _DateFilteredList(filter: widget.filter, date: _selectedDate),
        ),
      ],
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DatePickerRow({
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: AppTheme.cardBg,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: dates.length,
        itemBuilder: (ctx, i) {
          final date = dates[i];
          final isToday = _isSameDay(date, DateTime.now());
          final isSelected = _isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryLight : AppTheme.divider,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('EEE').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateFilteredList extends StatelessWidget {
  final String filter;
  final DateTime date;
  const _DateFilteredList({required this.filter, required this.date});

  @override
  Widget build(BuildContext context) {
    final start = Timestamp.fromDate(date);
    final end = Timestamp.fromDate(date.add(const Duration(days: 1)));

    Query query = FirebaseFirestore.instance
        .collection('matches')
        .where('scheduledAt', isGreaterThanOrEqualTo: start)
        .where('scheduledAt', isLessThan: end)
        .orderBy('scheduledAt');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 56, color: AppTheme.cardBg2),
                const SizedBox(height: 12),
                Text(
                  'No matches on ${DateFormat('EEEE d MMM').format(date)}',
                  style: const TextStyle(color: AppTheme.textSecondary),
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
        );
      },
    );
  }
}

// ─── COUPON TAB ──────────────────────────────────────────────────────────────

class _CouponTab extends StatefulWidget {
  final String userId;
  const _CouponTab({required this.userId});

  @override
  State<_CouponTab> createState() => _CouponTabState();
}

class _CouponTabState extends State<_CouponTab> {
  final Map<String, String> _picks = {}; // matchId → '1' | 'X' | '2'
  final Map<String, (int, int)> _exactScores = {}; // matchId → (home, away)
  bool _submitting = false;

  Future<void> _submitCoupon(List<MatchModel> matches) async {
    if (_picks.isEmpty || widget.userId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in _picks.entries) {
        final matchIdx = matches.indexWhere((m) => m.id == entry.key);
        if (matchIdx < 0) continue;
        final match = matches[matchIdx];
        final exact = _exactScores[entry.key];
        final ref = FirebaseFirestore.instance.collection('coupon_picks').doc();
        batch.set(
          ref,
          CouponPick(
            id: ref.id,
            userId: widget.userId,
            matchId: entry.key,
            homeClubName: match.homeClubName,
            awayClubName: match.awayClubName,
            pick: entry.value,
            predictedHomeScore: exact?.$1,
            predictedAwayScore: exact?.$2,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }
      final count = _picks.length;
      await batch.commit();
      if (mounted) {
        setState(() {
          _picks.clear();
          _exactScores.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon submitted! $count picks saved.'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('scheduledAt')
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = (snap.data?.docs ?? [])
            .map(
              (d) => MatchModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();

        if (matches.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: AppTheme.cardBg2),
                SizedBox(height: 12),
                Text(
                  'No matches available for prediction',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: AppTheme.accent,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Coupon',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Pick 1 (Home), X (Draw) or 2 (Away) for each match. Earn 5 pts per correct pick!',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_picks.length}/${matches.length}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
                color: AppTheme.primaryLight,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _CouponMatchRow(
                    match: matches[i],
                    selectedPick: _picks[matches[i].id],
                    exactScore: _exactScores[matches[i].id],
                    onPick: (pick) => setState(() {
                      if (_picks[matches[i].id] == pick) {
                        _picks.remove(matches[i].id);
                        _exactScores.remove(matches[i].id);
                      } else {
                        _picks[matches[i].id] = pick;
                      }
                    }),
                    onExactScore: (h, a) => setState(() {
                      if (h == null || a == null) {
                        _exactScores.remove(matches[i].id);
                      } else {
                        _exactScores[matches[i].id] = (h, a);
                        // Auto-infer 1X2 from exact score
                        _picks[matches[i].id] =
                            h > a ? '1' : h < a ? '2' : 'X';
                      }
                    }),
                  ),
                ),
              ),
            ),
            if (_picks.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : () => _submitCoupon(matches),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.supportGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Submit ${_picks.length} Pick${_picks.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
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

class _CouponMatchRow extends StatefulWidget {
  final MatchModel match;
  final String? selectedPick;
  final (int, int)? exactScore;
  final ValueChanged<String> onPick;
  final void Function(int?, int?) onExactScore;
  const _CouponMatchRow({
    required this.match,
    this.selectedPick,
    this.exactScore,
    required this.onPick,
    required this.onExactScore,
  });

  @override
  State<_CouponMatchRow> createState() => _CouponMatchRowState();
}

class _CouponMatchRowState extends State<_CouponMatchRow> {
  bool _exactExpanded = false;
  late final TextEditingController _homeCtrl;
  late final TextEditingController _awayCtrl;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(
      text: widget.exactScore?.$1.toString() ?? '',
    );
    _awayCtrl = TextEditingController(
      text: widget.exactScore?.$2.toString() ?? '',
    );
    _exactExpanded = widget.exactScore != null;
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  void _commitExact() {
    final h = int.tryParse(_homeCtrl.text);
    final a = int.tryParse(_awayCtrl.text);
    if (h != null && a != null && h >= 0 && a >= 0) {
      widget.onExactScore(h, a);
    } else {
      widget.onExactScore(null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPick = widget.selectedPick;
    final match = widget.match;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedPick != null ? AppTheme.cardBg2 : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedPick != null
              ? AppTheme.primaryLight.withOpacity(0.5)
              : AppTheme.divider,
          width: selectedPick != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeClubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'vs',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  match.awayClubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PickButton(
                label: '1',
                sublabel: 'Home',
                selected: selectedPick == '1',
                onTap: () => widget.onPick('1'),
              ),
              const SizedBox(width: 8),
              _PickButton(
                label: 'X',
                sublabel: 'Draw',
                selected: selectedPick == 'X',
                onTap: () => widget.onPick('X'),
              ),
              const SizedBox(width: 8),
              _PickButton(
                label: '2',
                sublabel: 'Away',
                selected: selectedPick == '2',
                onTap: () => widget.onPick('2'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() => _exactExpanded = !_exactExpanded);
              if (!_exactExpanded) {
                widget.onExactScore(null, null);
                _homeCtrl.clear();
                _awayCtrl.clear();
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _exactExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.accent,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _exactExpanded
                      ? 'Hide exact score'
                      : 'Predict exact score (+10 pts)',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_exactExpanded) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _homeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: AppTheme.cardBg2,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => _commitExact(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _awayCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: AppTheme.cardBg2,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => _commitExact(),
                  ),
                ),
              ],
            ),
          ],
          if (match.isLive) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.liveRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "LIVE ${match.minute != null ? "${match.minute}'" : ''}",
                  style: const TextStyle(
                    color: AppTheme.liveRed,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _PickButton({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : AppTheme.cardBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.divider,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
