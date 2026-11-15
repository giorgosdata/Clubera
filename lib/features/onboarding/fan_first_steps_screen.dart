import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clubera/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notifications_service.dart';
import '../../core/providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/club_ball.dart';
import '../../core/widgets/clubera_icons.dart';
import '../../models/club_model.dart';
import '../clubs/ui/club_profile_screen.dart';
import '../teams/ui/teams_screen.dart' show kCountries;

/// The fan's first steps: a short guided tour where every screen has one
/// thing to tap, so nobody has to read instructions.
///
///   1. find your team among the clubs of your country (follows the club)
///   2. take a free penalty
///   3. see your place among the other fans
///   4. your participation matters to your club
///   5. support the club
///   6. see you tomorrow
///
/// The welcome points for steps 1 and 2 are saved once per account.
class FanFirstStepsScreen extends StatefulWidget {
  final VoidCallback onDone;
  const FanFirstStepsScreen({super.key, required this.onDone});

  /// Remembers on this device that the tour was seen.
  static const prefsKey = 'first_steps_done';

  @override
  State<FanFirstStepsScreen> createState() => _FanFirstStepsScreenState();
}

class _RankRow {
  final String rank;
  final String name;
  final int points;
  final bool isMe;
  const _RankRow({
    required this.rank,
    required this.name,
    required this.points,
    this.isMe = false,
  });
}

class _FanFirstStepsScreenState extends State<FanFirstStepsScreen>
    with TickerProviderStateMixin {
  static const int _stepCount = 6;
  static const int _teamPoints = 10;
  static const int _goalPoints = 10;

  // Penalty scene: where the goal and the spot are on stadium.jpg.
  static const double _sceneAspect = 0.8112;
  static const double _goalL = 0.121, _goalR = 0.879;
  static const double _goalT = 0.161, _goalB = 0.382;
  static const double _spotX = 0.5, _spotY = 0.714;

  late final AnimationController _pulse;
  late final AnimationController _kick;

  int _step = 0;
  int _points = 0;
  int _gain = 0;

  String _country = 'Greece';
  String _query = '';
  List<ClubModel>? _clubs;
  ClubModel? _club;

  /// The club this tour started following, if any.
  String? _followedHere;

  /// Which welcome points this account already has.
  final Map<String, dynamic> _awarded = {};

  int? _shotSide; // 0 = left, 1 = right
  List<_RankRow>? _rank;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _kick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _points = context.read<AppProvider>().user?.points ?? 0;
    _country = _guessCountry();
    _loadAwarded();
    _loadClubs();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _kick.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  String _guessCountry() {
    const byCode = {
      'GR': 'Greece',
      'CY': 'Cyprus',
      'DE': 'Germany',
      'IT': 'Italy',
      'ES': 'Spain',
      'FR': 'France',
      'GB': 'England',
      'PT': 'Portugal',
      'NL': 'Netherlands',
      'BE': 'Belgium',
      'AT': 'Austria',
      'CH': 'Switzerland',
      'TR': 'Turkey',
    };
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final guess = byCode[code];
    if (guess != null && kCountries.any((c) => c['name'] == guess)) {
      return guess;
    }
    return 'Greece';
  }

  Future<void> _loadAwarded() async {
    final uid = context.read<AppProvider>().user?.uid;
    if (uid == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final done = snap.data()?['firstSteps'];
      if (done is Map) {
        _awarded.addAll(Map<String, dynamic>.from(done));
      }
    } catch (_) {
      // Without this we simply try to award; the write is still once-only
      // per key because the same field is set again.
    }
  }

  Future<void> _loadClubs() async {
    final country = _country;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clubs')
          .where('country', isEqualTo: country)
          .limit(500)
          .get();
      if (!mounted || country != _country) return;
      final list = snap.docs
          .map((d) => ClubModel.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() => _clubs = list);
    } catch (_) {
      if (mounted && country == _country) setState(() => _clubs = []);
    }
  }

  Future<void> _loadRank() async {
    final me = context.read<AppProvider>().user;
    if (me == null) return;
    String first(Object? name) {
      final t = (name is String ? name : '').trim();
      return t.isEmpty ? '—' : t.split(RegExp(r'\s+')).first;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .limit(100)
          .get();
      final docs = snap.docs;
      final idx = docs.indexWhere((d) => d.id == me.uid);
      final rows = <_RankRow>[];
      if (idx >= 0) {
        final from = idx - 2 < 0 ? 0 : idx - 2;
        final to = idx + 2 > docs.length - 1 ? docs.length - 1 : idx + 2;
        for (var i = from; i <= to; i++) {
          final d = docs[i].data();
          rows.add(_RankRow(
            rank: '${i + 1}',
            name: first(d['name']),
            points: i == idx ? _points : ((d['points'] as num?)?.toInt() ?? 0),
            isMe: i == idx,
          ));
        }
      } else {
        for (var i = 0; i < docs.length && i < 3; i++) {
          final d = docs[i].data();
          rows.add(_RankRow(
            rank: '${i + 1}',
            name: first(d['name']),
            points: (d['points'] as num?)?.toInt() ?? 0,
          ));
        }
        rows.add(_RankRow(rank: '100+', name: '', points: _points, isMe: true));
      }
      if (mounted) setState(() => _rank = rows);
    } catch (_) {
      if (mounted) {
        setState(() {
          _rank = [_RankRow(rank: '—', name: '', points: _points, isMe: true)];
        });
      }
    }
  }

  /// Gives the welcome points for [key] once per account.
  void _award(String key, int amount) {
    if (_awarded[key] == true) {
      setState(() => _gain = 0);
      return;
    }
    _awarded[key] = true;
    setState(() {
      _points += amount;
      _gain = amount;
    });
    unawaited(_saveAward(key, amount));
  }

  Future<void> _saveAward(String key, int amount) async {
    final prov = context.read<AppProvider>();
    final uid = prov.user?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'points': FieldValue.increment(amount),
        'firstSteps.$key': true,
      });
      final u = prov.user;
      if (u != null) prov.updateUser(u.copyWith(points: u.points + amount));
    } catch (_) {
      // Not saved: take the points back so the screen matches the account.
      _awarded.remove(key);
      if (mounted) {
        setState(() {
          _points -= amount;
          _gain = 0;
        });
      }
    }
  }

  Future<void> _follow(AppProvider prov, String uid, String clubId) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(uid), {
        'followedClubs': FieldValue.arrayUnion([clubId]),
      });
      batch.update(db.collection('clubs').doc(clubId), {
        'followers': FieldValue.increment(1),
      });
      await batch.commit();
      final u = prov.user;
      if (u != null && !u.followedClubs.contains(clubId)) {
        prov.updateUser(
          u.copyWith(followedClubs: [...u.followedClubs, clubId]),
        );
      }
      await NotificationsService.subscribe('club_$clubId');
    } catch (_) {
      // The fan can still follow the club later from its page.
    }
  }

  Future<void> _unfollow(AppProvider prov, String uid, String clubId) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(uid), {
        'followedClubs': FieldValue.arrayRemove([clubId]),
      });
      batch.update(db.collection('clubs').doc(clubId), {
        'followers': FieldValue.increment(-1),
      });
      await batch.commit();
      final u = prov.user;
      if (u != null && u.followedClubs.contains(clubId)) {
        prov.updateUser(
          u.copyWith(
            followedClubs: u.followedClubs.where((id) => id != clubId).toList(),
          ),
        );
      }
      await NotificationsService.unsubscribe('club_$clubId');
    } catch (_) {
      // The fan can still unfollow the club from its page.
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _goTo(int step) {
    setState(() => _step = step);
    if (step == 2 && _rank == null) _loadRank();
  }

  void _next() {
    setState(() => _gain = 0);
    _goTo(_step + 1);
  }

  /// Back to the previous screen, so the fan moves on only when they want.
  void _back() {
    if (_step == 0) return;
    setState(() {
      _gain = 0;
      _step -= 1;
      if (_step == 1) {
        // The penalty can be taken again; the points are not given twice.
        _shotSide = null;
        _kick.reset();
      }
    });
  }

  void _pickClub(ClubModel club) {
    final prov = context.read<AppProvider>();
    final user = prov.user;
    FocusScope.of(context).unfocus();
    setState(() => _club = club);
    // Coming back and choosing another team replaces the first choice.
    final before = _followedHere;
    if (user != null && before != null && before != club.id) {
      _followedHere = null;
      unawaited(_unfollow(prov, user.uid, before));
    }
    if (user != null && !user.followedClubs.contains(club.id)) {
      _followedHere = club.id;
      unawaited(_follow(prov, user.uid, club.id));
    }
    _award('team', _teamPoints);
    _goTo(1);
  }

  Future<void> _shoot(int side) async {
    if (_shotSide != null) return;
    setState(() => _shotSide = side);
    await _kick.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _award('penalty', _goalPoints);
    _goTo(2);
  }

  Future<void> _finish({bool openClub = false}) async {
    final nav = Navigator.of(context);
    final clubId = _club?.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(FanFirstStepsScreen.prefsKey, true);
    widget.onDone();
    if (openClub && clubId != null) {
      nav.push(
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId)),
      );
    }
  }

  Future<void> _chooseCountry() async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.fs_choose_country,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in kCountries)
                    ListTile(
                      leading: Text(
                        c['flag'] ?? '',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        c['name'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(ctx, c['name']),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _country || !mounted) return;
    setState(() {
      _country = picked;
      _clubs = null;
    });
    _loadClubs();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Lower case without Greek accents, so «νικη» finds «Νίκη».
  static String _plain(String s) {
    const from = 'άέήίόύώϊΐϋΰς';
    const to = 'αεηιουωιιυυσ';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().trim();
  }

  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 28,
    height: 1.12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    shadows: [Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 2))],
  );

  BoxDecoration _tile({double radius = 16, bool highlight = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment(-0.4, -1),
        end: Alignment(0.4, 1),
        colors: [Color(0xFF2D3E9A), Color(0xFF141D52), Color(0xFF0C1238)],
        stops: [0, 0.6, 1],
      ),
      border: highlight
          ? Border.all(color: AppTheme.accent, width: 2)
          : Border.all(color: const Color(0x24FFFFFF)),
      boxShadow: [
        const BoxShadow(
          color: Color(0x73000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
        if (highlight) const BoxShadow(color: Color(0x40B4FF1E), blurRadius: 18),
      ],
    );
  }

  Widget _clubAvatar(ClubModel club, double size) {
    final img = safeNetworkImage(club.logoUrl);
    if (img == null) return ClubBall(club.name, size: size);
    return ClipOval(
      child: Image(
        image: img,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ClubBall(club.name, size: size),
      ),
    );
  }

  /// A lime ring that keeps spreading out from [child]: «tap here».
  Widget _pulsing({required Widget child, double radius = 14}) {
    return AnimatedBuilder(
      animation: _pulse,
      child: child,
      builder: (_, child) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.7 * (1 - t)),
                spreadRadius: 16 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  /// The bobbing hand that points at the thing to tap.
  Widget _hand() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -9 * sin(pi * _pulse.value)),
          child: child,
        ),
        child: const Icon(
          Icons.touch_app,
          color: Colors.white,
          size: 44,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
        ),
      ),
    );
  }

  Widget _gainBadge(AppLocalizations l, {String? prefix}) {
    if (_gain <= 0) return const SizedBox.shrink();
    final text = prefix == null ? l.fs_gain(_gain) : '$prefix ${l.fs_gain(_gain)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.surface,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _cta(String label, VoidCallback onTap) {
    return _pulsing(
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(l),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _stepBody(l),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stepCount; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _step ? AppTheme.accent : const Color(0x38FFFFFF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_step > 0)
              IconButton(
                onPressed: _back,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              )
            else
              Image.asset('assets/images/shield.png', width: 36, height: 36),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_points',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.fs_points_label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _finish,
              child: Text(
                l.fs_skip,
                style: const TextStyle(color: Color(0xFFAFBEE6), fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepBody(AppLocalizations l) {
    switch (_step) {
      case 0:
        return _findTeamStep(l);
      case 1:
        return _penaltyStep(l);
      case 2:
        return _rankStep(l);
      case 3:
        return _clubStep(l);
      case 4:
        return _supportStep(l);
      default:
        return _endStep(l);
    }
  }

  // ── Step 1: find your team ──────────────────────────────────────────────────

  Widget _findTeamStep(AppLocalizations l) {
    final flag = kCountries
        .firstWhere((c) => c['name'] == _country, orElse: () => const {})['flag'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.fs_find_title, style: _titleStyle),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: AppTheme.cardBg2,
            shape: const StadiumBorder(
              side: BorderSide(color: AppTheme.primaryLight),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _chooseCountry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (flag != null) ...[
                      Text(flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _country,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, color: Color(0xFFAFBEE6)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l.fs_search_hint,
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        Expanded(child: _clubList(l)),
      ],
    );
  }

  Widget _clubList(AppLocalizations l) {
    final clubs = _clubs;
    if (clubs == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }
    final q = _plain(_query);
    final shown = q.isEmpty
        ? clubs
        : clubs.where((c) => _plain(c.name).contains(q)).toList();
    if (shown.isEmpty) {
      return Center(
        child: Text(
          l.fs_no_clubs,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _clubRow(shown[i]),
        ),
        if (q.isEmpty) Positioned(right: 20, top: 14, child: _hand()),
      ],
    );
  }

  Widget _clubRow(ClubModel club) {
    final sub = [club.category, club.city].where((s) => s.trim().isNotEmpty).join(' · ');
    return DecoratedBox(
      decoration: _tile(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pickClub(club),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _clubAvatar(club, 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 2: free penalty ────────────────────────────────────────────────────

  Widget _penaltyStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gainBadge(l),
        Text(l.fs_shoot_title, style: _titleStyle),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _sceneAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LayoutBuilder(
                  builder: (_, box) => AnimatedBuilder(
                    animation: _kick,
                    builder: (_, _) => _penaltyScene(l, box.maxWidth, box.maxHeight),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _penaltyScene(AppLocalizations l, double w, double h) {
    final goalLeft = w * _goalL;
    final goalW = w * (_goalR - _goalL);
    final goalTop = h * _goalT;
    final goalBottom = h * _goalB;
    final goalH = goalBottom - goalTop;
    final cx = w / 2;

    Offset target(int side) => Offset(
          goalLeft + goalW * (side == 0 ? 1 / 6 : 5 / 6),
          goalTop + goalH * 0.45,
        );

    final side = _shotSide;
    final t = Curves.easeOut.transform(_kick.value);

    // Ball: from the spot to the corner the fan chose, getting smaller.
    final spot = Offset(w * _spotX, h * _spotY);
    final ballBase = h * 0.085;
    var ballCenter = spot;
    var ballSize = ballBase;
    if (side != null) {
      final to = target(side);
      ballCenter = Offset.lerp(spot, to, t)!.translate(0, -sin(pi * t) * h * 0.05);
      ballSize = ballBase * (1 - 0.45 * t);
    }

    // Keeper: stands in the middle, then dives the other way.
    final diving = side != null && t > 0.15;
    final keeperH = goalH * 0.75;
    final keeperW = keeperH * 0.741;
    final diveW = goalW * 0.52;
    final diveH = diveW / 2.7;
    final diveCx = goalLeft + goalW * (side == 1 ? 0.27 : 0.73);

    final targetSize = max(48.0, goalH * 0.5);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/penalty/stadium.jpg', fit: BoxFit.fill),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xD1080E2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.fs_free,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        if (!diving)
          Positioned(
            left: cx - keeperW / 2,
            top: goalBottom - keeperH,
            width: keeperW,
            height: keeperH,
            child: Image.asset('assets/images/penalty/keeper.png', fit: BoxFit.contain),
          )
        else
          Positioned(
            left: diveCx - diveW / 2,
            top: goalBottom - goalH * 0.3 - diveH / 2,
            width: diveW,
            height: diveH,
            child: Image.asset(
              side == 1
                  ? 'assets/images/penalty/keeper_dive_left.png'
                  : 'assets/images/penalty/keeper_dive_right.png',
              fit: BoxFit.contain,
            ),
          ),
        if (side == null)
          for (final s in const [0, 1])
            Positioned(
              left: target(s).dx - targetSize / 2,
              top: target(s).dy - targetSize / 2,
              width: targetSize,
              height: targetSize,
              child: _pulsing(
                radius: targetSize / 2,
                child: Material(
                  color: const Color(0x38B4FF1E),
                  shape: const CircleBorder(
                    side: BorderSide(color: AppTheme.accent, width: 3),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _shoot(s),
                  ),
                ),
              ),
            ),
        Positioned(
          left: ballCenter.dx - ballSize / 2,
          top: ballCenter.dy - ballSize / 2,
          width: ballSize,
          height: ballSize,
          child: Transform.rotate(
            angle: t * 8,
            child: Image.asset('assets/images/penalty/ball.png', fit: BoxFit.contain),
          ),
        ),
        if (side == null)
          Positioned(
            left: target(1).dx - 8,
            top: target(1).dy + targetSize * 0.3,
            child: _hand(),
          ),
      ],
    );
  }

  // ── Step 3: your place ──────────────────────────────────────────────────────

  Widget _rankStep(AppLocalizations l) {
    final rows = _rank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gainBadge(l, prefix: l.fs_goal),
        Text(l.fs_rank_title, style: _titleStyle),
        const SizedBox(height: 14),
        Expanded(
          child: rows == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                )
              : ListView(
                  children: [
                    for (final r in rows) ...[
                      _rankRow(l, r),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      l.fs_rank_sub,
                      style: const TextStyle(color: Color(0xFFD5DEF7), fontSize: 16),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _cta(l.fs_continue, _next),
      ],
    );
  }

  Widget _rankRow(AppLocalizations l, _RankRow r) {
    final color = r.isMe ? Colors.white : const Color(0xFFAFBEE6);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: r.isMe ? 16 : 13),
      decoration: r.isMe
          ? _tile(radius: 14, highlight: true)
          : BoxDecoration(
              color: const Color(0xEB101840),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              r.rank,
              style: TextStyle(
                color: r.isMe ? AppTheme.accent : color,
                fontSize: r.isMe ? 20 : 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              r.isMe ? l.fs_you : r.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: r.isMe ? 19 : 17,
                fontWeight: r.isMe ? FontWeight.w900 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${r.points}',
            style: TextStyle(
              color: r.isMe ? AppTheme.accent : color,
              fontSize: r.isMe ? 19 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: your participation matters ──────────────────────────────────────

  Widget _clubBadge(double size) {
    final club = _club;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: _tile(radius: size * 0.3, highlight: true),
        alignment: Alignment.center,
        child: club == null
            ? Image.asset('assets/images/shield.png', width: size * 0.7)
            : _clubAvatar(club, size * 0.7),
      ),
    );
  }

  Widget _clubName() {
    return Text(
      _club?.name ?? '',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _clubStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.fs_club_title, style: _titleStyle),
        const Spacer(),
        _clubBadge(148),
        const SizedBox(height: 18),
        _clubName(),
        const Spacer(),
        _cta(l.fs_continue, _next),
      ],
    );
  }

  // ── Step 5: support the club ────────────────────────────────────────────────

  Widget _supportStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.fs_support_title, style: _titleStyle),
        const Spacer(),
        _clubBadge(148),
        const SizedBox(height: 18),
        _clubName(),
        const SizedBox(height: 10),
        Text(
          l.fs_support_sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFD5DEF7), fontSize: 17),
        ),
        const Spacer(),
        _pulsing(
          child: Material(
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.supportGreenDark, Color(0xFF1B5E20)],
                ),
              ),
              child: InkWell(
                onTap: () => _finish(openClub: true),
                child: SizedBox(
                  height: 62,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ClIconView(ClIcon.support, size: 30),
                      const SizedBox(width: 12),
                      Text(
                        l.fs_support_btn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _next,
          child: Text(
            l.fs_not_now,
            style: const TextStyle(color: Color(0xFFD5DEF7), fontSize: 17),
          ),
        ),
      ],
    );
  }

  // ── Step 6: see you tomorrow ────────────────────────────────────────────────

  Widget _endStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: Image.asset('assets/images/shield.png', width: 160, height: 160),
        ),
        const SizedBox(height: 20),
        Text(l.fs_end_title, textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 10),
        Text(
          l.fs_end_sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFD5DEF7), fontSize: 18),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xEB101840),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_points',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l.fs_points_label,
                  style: const TextStyle(color: Color(0xFFD5DEF7), fontSize: 18),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _cta(l.fs_start, _finish),
      ],
    );
  }
}
