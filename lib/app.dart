import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/app_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/streak_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/clubera_icons.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/club_admin/invite/club_invite.dart';
import 'features/clubs/ui/club_profile_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/intro/intro_splash.dart';
import 'features/matches/ui/match_detail_screen.dart';
import 'features/matches/ui/matches_screen.dart';
import 'features/teams/ui/teams_screen.dart';
import 'features/profile/ui/profile_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/tournaments/ui/tournament_detail_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class CluperaApp extends StatelessWidget {
  const CluperaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Clubera',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/stadium_bg.jpeg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xCC000000), Color(0xEE0A1628)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(child: _PhoneWidth(child: OfflineBanner(child: child!))),
        ],
      ),
      home: const _Root(),
    );
  }
}

/// The screens are designed for a phone. On a wide screen (the web version
/// on a computer) the app is shown as a centred column instead of stretching
/// grids and cards across the whole window; the stadium background fills the
/// rest. MediaQuery reports the column width, so code that sizes itself from
/// the screen width sees the column, not the window.
class _PhoneWidth extends StatelessWidget {
  static const double maxWidth = 640;
  final Widget child;
  const _PhoneWidth({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;
    return Center(
      child: SizedBox(
        width: maxWidth,
        child: MediaQuery(
          data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _onboardingChecked = false;
  bool _onboardingDone = false;
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppProvider>().init());
    // An invite link (?invite=…) is kept until the user has signed in.
    captureInviteFromUrl();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _onboardingDone = prefs.getBool('onboarding_done') ?? false;
        _onboardingChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    // The opening animation plays while the app loads in the background.
    if (!_introDone) {
      return IntroSplash(onDone: () => setState(() => _introDone = true));
    }
    if (!prov.initialized || !_onboardingChecked) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(image: AssetImage('assets/images/logo.jpeg'), height: 160),
            SizedBox(height: 40),
            CircularProgressIndicator(color: AppTheme.primaryLight),
          ],
        ),
      );
    }
    if (!prov.isLoggedIn) return const LoginScreen();
    if (!_onboardingDone) {
      return OnboardingScreen(onDone: () => setState(() => _onboardingDone = true));
    }
    return const _MainShell();
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  bool _streakChecked = false;
  StreamSubscription<Uri>? _linkSub;

  static const _screens = [
    HomeScreen(),
    MatchesScreen(),
    TeamsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkInvite();
      await _checkStreak();
    });
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (initial != null) _handleDeepLink(initial);
    _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final invite = uri.queryParameters['invite'];
    if (invite != null && invite.isNotEmpty) {
      rememberInvite(invite).then((_) => _checkInvite());
      return;
    }
    final segs = uri.pathSegments;
    if (segs.isEmpty) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    switch (segs[0]) {
      case 'match':
        if (segs.length > 1) {
          nav.push(MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: segs[1])));
        }
        break;
      case 'club':
        if (segs.length > 1) {
          nav.push(MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: segs[1])));
        }
        break;
      case 'invite':
        if (segs.length > 1) {
          rememberInvite(segs[1]).then((_) => _checkInvite());
        }
        break;
      case 'tournament':
        if (segs.length > 1) {
          nav.push(MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: segs[1])));
        }
        break;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _checkInvite() async {
    final user = context.read<AppProvider>().user;
    if (user == null || !mounted) return;
    await checkPendingInvite(context, user);
  }

  Future<void> _checkStreak() async {
    if (_streakChecked || !mounted) return;
    _streakChecked = true;
    final result = await StreakService.check(context.read<AppProvider>());
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accent,
          content: Text(
            result.isNewStreak
                ? '🎉 Καλημέρα! +${result.bonusPoints} pts (streak: ${result.newStreak} day)'
                : '🔥 Streak: ${result.newStreak} days • +${result.bonusPoints} pts',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: ClNavIcon(ClIcon.home), activeIcon: ClNavIcon(ClIcon.home, active: true), label: 'Αρχική'),
          BottomNavigationBarItem(icon: ClNavIcon(ClIcon.matches), activeIcon: ClNavIcon(ClIcon.matches, active: true), label: 'Αγώνες'),
          BottomNavigationBarItem(icon: ClNavIcon(ClIcon.clubs), activeIcon: ClNavIcon(ClIcon.clubs, active: true), label: 'Σύλλογοι'),
          BottomNavigationBarItem(icon: ClNavIcon(ClIcon.profile), activeIcon: ClNavIcon(ClIcon.profile, active: true), label: 'Προφίλ'),
        ],
      ),
    );
  }
}
