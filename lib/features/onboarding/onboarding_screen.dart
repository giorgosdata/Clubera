import 'package:clubera/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/clubera_icons.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  List<_OnboardPage> _pagesOf(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
    _OnboardPage(
      art: _Art.welcome,
      color: AppTheme.primaryLight,
      title: l.ob_title_welcome,
      subtitle: l.ob_sub_welcome,
    ),
    _OnboardPage(
      art: _Art.follow,
      color: AppTheme.supportGreen,
      title: l.ob_title_follow,
      subtitle: l.ob_sub_follow,
    ),
    _OnboardPage(
      art: _Art.predict,
      color: AppTheme.accent,
      title: l.ob_title_predict,
      subtitle: l.ob_sub_predict,
    ),
    _OnboardPage(
      art: _Art.live,
      color: AppTheme.liveRed,
      title: l.ob_title_live,
      subtitle: l.ob_sub_live,
    ),
    ];
  }

  Future<void> _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pagesOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: TextButton(
                  onPressed: _done,
                  child: const Text('Παράλειψη', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppTheme.primaryLight : AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_page < pages.length - 1) {
                      _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _done();
                    }
                  },
                  child: Text(
                    _page < pages.length - 1 ? AppLocalizations.of(context).ob_next : AppLocalizations.of(context).ob_start,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final _Art art;
  final Color color;
  final String title;
  final String subtitle;
  const _OnboardPage({
    required this.art,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: _OnboardArt(art: art),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _Art { welcome, follow, predict, live }

/// Picture at the top of each onboarding page: the Clubera stadium at night
/// with the shield or the page's subject in front.
class _OnboardArt extends StatelessWidget {
  final _Art art;
  const _OnboardArt({required this.art});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.05,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/stadium_clubera.jpg', fit: BoxFit.cover, alignment: const Alignment(0, 0.55)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x00000000), Color(0x99080E2A)],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
            ),
            Center(child: _content(context)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (art) {
      case _Art.welcome:
        return Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x594ADE80), blurRadius: 60, spreadRadius: 4)],
          ),
          child: Image.asset('assets/images/shield.png', width: 170, height: 170),
        );
      case _Art.follow:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Opacity(opacity: 0.75, child: ClIconTile(ClIcon.clubs, size: 64)),
                SizedBox(width: 14),
                ClIconTile(ClIcon.clubs, size: 96),
                SizedBox(width: 14),
                Opacity(opacity: 0.75, child: ClIconTile(ClIcon.clubs, size: 64)),
              ],
            ),
            const SizedBox(height: 18),
            _chip(ClIcon.support, AppLocalizations.of(context).ob_chip_following),
          ],
        );
      case _Art.predict:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClIconView(ClIcon.clubs, size: 34),
                  SizedBox(width: 14),
                  Text('2  –  1', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                  SizedBox(width: 14),
                  ClIconView(ClIcon.clubs, size: 34, muted: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClIconTile(ClIcon.rewards, size: 64),
                const SizedBox(width: 12),
                _chip(null, AppLocalizations.of(context).ob_chip_points),
              ],
            ),
          ],
        );
      case _Art.live:
        return _card(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ClIconTile(ClIcon.matches, size: 56),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppTheme.liveRed, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('LIVE · 67΄', style: TextStyle(color: AppTheme.liveRed, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('ΓΚΟΛ!  1 – 0', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  const Text('Η ομάδα σου προηγείται', style: TextStyle(color: Color(0xFFC7D2F0), fontSize: 13)),
                ],
              ),
            ],
          ),
        );
    }
  }

  static Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE61A2560), Color(0xE60C1238)],
          ),
          border: Border.all(color: const Color(0x24FFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: child,
      );

  static Widget _chip(ClIcon? icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x334ADE80),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x804ADE80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[ClIconView(icon, size: 18), const SizedBox(width: 6)],
            Text(text, style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      );
}
