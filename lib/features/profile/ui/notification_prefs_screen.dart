import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool _goals = true;
  bool _matchStart = true;
  bool _matchEnd = true;
  bool _announcements = true;
  bool _predictions = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _goals = prefs.getBool('notif_goals') ?? true;
      _matchStart = prefs.getBool('notif_match_start') ?? true;
      _matchEnd = prefs.getBool('notif_match_end') ?? true;
      _announcements = prefs.getBool('notif_announcements') ?? true;
      _predictions = prefs.getBool('notif_predictions') ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ειδοποιήσεις'),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _section('Αγώνες'),
                _toggle(
                  icon: Icons.sports_soccer,
                  color: AppTheme.supportGreen,
                  label: 'Γκολ',
                  subtitle: 'Ειδοποίηση για κάθε γκολ σε live αγώνα',
                  value: _goals,
                  onChanged: (v) {
                    setState(() => _goals = v);
                    _save('notif_goals', v);
                  },
                ),
                _toggle(
                  icon: Icons.play_circle_outline,
                  color: AppTheme.primaryLight,
                  label: 'Έναρξη αγώνα',
                  subtitle: 'Όταν ξεκινά αγώνας σωματείου που ακολουθείς',
                  value: _matchStart,
                  onChanged: (v) {
                    setState(() => _matchStart = v);
                    _save('notif_match_start', v);
                  },
                ),
                _toggle(
                  icon: Icons.sports_score,
                  color: AppTheme.accent,
                  label: 'Τελικό αποτέλεσμα',
                  subtitle: 'Ειδοποίηση για το τελικό σκορ αγώνα',
                  value: _matchEnd,
                  onChanged: (v) {
                    setState(() => _matchEnd = v);
                    _save('notif_match_end', v);
                  },
                ),
                const SizedBox(height: 8),
                _section('Σωματείο'),
                _toggle(
                  icon: Icons.campaign_outlined,
                  color: AppTheme.liveRed,
                  label: 'Ανακοινώσεις',
                  subtitle: 'Νέες ανακοινώσεις από σωματεία που ακολουθείς',
                  value: _announcements,
                  onChanged: (v) {
                    setState(() => _announcements = v);
                    _save('notif_announcements', v);
                  },
                ),
                const SizedBox(height: 8),
                _section('Gamification'),
                _toggle(
                  icon: Icons.analytics_outlined,
                  color: AppTheme.primaryLight,
                  label: 'Προβλέψεις',
                  subtitle: 'Όταν βαθμολογηθούν οι προβλέψεις σου',
                  value: _predictions,
                  onChanged: (v) {
                    setState(() => _predictions = v);
                    _save('notif_predictions', v);
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Βεβαιώσου ότι έχεις ενεργοποιήσει ειδοποιήσεις για το Clubera στις ρυθμίσεις του τηλεφώνου σου.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _toggle({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
