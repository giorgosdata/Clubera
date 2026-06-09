import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/app_provider.dart';
import 'core/services/streak_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/matches/ui/matches_screen.dart';
import 'features/teams/ui/teams_screen.dart';
import 'features/profile/ui/profile_screen.dart';

class CluperaApp extends StatelessWidget {
  const CluperaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clubera',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
          child!,
        ],
      ),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppProvider>().init());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    if (!prov.initialized) {
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

  static const _screens = [
    HomeScreen(),
    MatchesScreen(),
    TeamsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStreak());
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer_outlined), activeIcon: Icon(Icons.sports_soccer), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Teams'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
