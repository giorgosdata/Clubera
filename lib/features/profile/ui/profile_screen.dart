import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/club_model.dart';
import '../../../models/donation_model.dart';
import '../../../models/prediction_model.dart';
import '../../../models/reward_model.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../clubs/ui/create_club_screen.dart' show CreateClubScreen, kLeagues;
import '../../admin/ui/admin_screen.dart';
import '../../club_admin/ui/club_admin_screen.dart';
import '../../help/ui/gazette_screen.dart';
import '../../gamification/ui/prediction_history_screen.dart';
import 'notification_prefs_screen.dart';
import '../widgets/fan_card.dart';
import '../widgets/badges_section.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/logo_picker.dart';
import '../../../core/utils/storage_utils.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
        color: AppTheme.primaryLight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(user),
            SliverToBoxAdapter(child: _StatsRow(user: user)),
            SliverToBoxAdapter(child: _FanCardsSection(user: user)),
            SliverToBoxAdapter(child: BadgesSection(userId: user.uid)),
            SliverToBoxAdapter(child: _WalletCard(user: user)),
            SliverToBoxAdapter(child: _FollowedClubsSection(user: user)),
            SliverToBoxAdapter(child: _GamesSection(user: user)),
            SliverToBoxAdapter(child: _MenuSection(user: user)),
            SliverToBoxAdapter(child: _ActivitiesSection(userId: user.uid)),
            SliverToBoxAdapter(child: _CouponHistorySection(userId: user.uid)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(UserModel user) {
    return SliverAppBar(
      expandedHeight: 200,
      backgroundColor: AppTheme.primary,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, Color(0xFF0D1B3E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.cardBg2,
                  backgroundImage: safeNetworkImage(user.photoUrl),
                  child: safeNetworkImage(user.photoUrl) == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role == 'fan'
                        ? '⭐ Fan'
                        : user.role == 'club'
                        ? '⚽ Club Manager'
                        : '🛡️ Admin',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── STATS ROW ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserModel user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    color: AppTheme.cardBg,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat('${user.points}', 'Points', AppTheme.accent),
        _vdiv(),
        _stat('${user.streak}', 'Streak', AppTheme.primaryLight),
        _vdiv(),
        _stat('${user.followedClubs.length}', 'Clubs', Colors.white),
      ],
    ),
  );

  Widget _stat(String val, String label, Color color) => Column(
    children: [
      Text(
        val,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _vdiv() => Container(width: 1, height: 40, color: AppTheme.divider);
}

// ─── FAN CARDS (per followed club) ───────────────────────────────────────────

class _FanCardsSection extends StatelessWidget {
  final UserModel user;
  const _FanCardsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.followedClubs.isEmpty) return const SizedBox.shrink();
    final clubs = user.followedClubs.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final clubId in clubs)
            FanCard(userId: user.uid, clubId: clubId),
        ],
      ),
    );
  }
}

// ─── WALLET CARD ─────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final UserModel user;
  const _WalletCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF4361EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Wallet Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'EUR',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '€${user.balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDepositSheet(context, user),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Deposit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.supportGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showHistorySheet(context, user.uid),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDepositSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DepositSheet(user: user),
    );
  }

  void _showHistorySheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, ctrl) =>
            _PaymentHistorySheet(userId: userId, controller: ctrl),
      ),
    );
  }
}

// ─── DEPOSIT SHEET ───────────────────────────────────────────────────────────

class _DepositSheet extends StatefulWidget {
  final UserModel user;
  const _DepositSheet({required this.user});

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _ctrl = TextEditingController();
  double? _selectedQuick;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _deposit(BuildContext context) async {
    final raw = _ctrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.user.uid),
        {'balance': FieldValue.increment(amount)},
      );
      batch.set(
        FirebaseFirestore.instance.collection('payments').doc(),
        {
          'userId': widget.user.uid,
          'userName': widget.user.name,
          'type': 'deposit',
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      final currentUser = provider.user;
      if (currentUser != null) {
        provider.updateUser(
          currentUser.copyWith(balance: currentUser.balance + amount),
        );
      }
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('€${amount.toStringAsFixed(2)} added to wallet!'),
          backgroundColor: AppTheme.supportGreen,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add funds: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  void _pickQuick(double amount) {
    setState(() {
      _selectedQuick = amount;
      _ctrl.text = amount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const Icon(
            Icons.account_balance_wallet,
            color: AppTheme.primaryLight,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Add Funds',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quick select or enter any amount',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // Quick amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1.0, 2.0, 5.0, 10.0, 20.0].map((a) {
              final sel = _selectedQuick == a;
              return GestureDetector(
                onTap: () => _pickQuick(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primaryLight : AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppTheme.primaryLight : AppTheme.divider,
                    ),
                  ),
                  child: Text(
                    '€${a.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: sel ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Custom amount field
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            onChanged: (v) => setState(() => _selectedQuick = null),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixText: '€ ',
              prefixStyle: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
              ),
              filled: true,
              fillColor: AppTheme.cardBg2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryLight,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _deposit(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.supportGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Add to Wallet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulated deposit — payment integration coming soon',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── PAYMENT HISTORY SHEET ───────────────────────────────────────────────────

class _PaymentHistorySheet extends StatelessWidget {
  final String userId;
  final ScrollController controller;
  const _PaymentHistorySheet({required this.userId, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('userId', isEqualTo: userId)
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
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No payment history',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AppTheme.divider),
                itemBuilder: (ctx, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final type = d['type'] ?? 'deposit';
                  final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                  final date = (d['createdAt'] as Timestamp?)?.toDate();
                  final isDonate = type == 'donate' || type == 'support';
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDonate
                            ? AppTheme.liveRed.withOpacity(0.2)
                            : AppTheme.supportGreen.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDonate ? Icons.favorite : Icons.add_circle,
                        color: isDonate
                            ? AppTheme.liveRed
                            : AppTheme.supportGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      type == 'deposit'
                          ? 'Deposit'
                          : type == 'donate'
                          ? 'Donation to ${d['clubName'] ?? ''}'
                          : 'Support ${d['clubName'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: date != null
                        ? Text(
                            DateFormat('d MMM yyyy, HH:mm').format(date),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Text(
                      '${isDonate ? '-' : '+'}€${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDonate
                            ? AppTheme.liveRed
                            : AppTheme.supportGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── MENU SECTION ─────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final UserModel user;
  const _MenuSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.role == 'fan' && user.clubId == null)
            _ClubApplicationTile(user: user),
          if (user.role == 'club') ...[
            const _SectionLabel('Club Management'),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.dashboard,
              label: 'Club Panel',
              color: AppTheme.supportGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClubAdminScreen()),
              ),
            ),
            if (user.clubId != null)
              _MenuItem(
                icon: Icons.shield_outlined,
                label: 'My Club Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubProfileScreen(clubId: user.clubId!),
                  ),
                ),
              )
            else
              _MenuItem(
                icon: Icons.add_circle_outline,
                label: 'Create My Club',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (user.role == 'admin') ...[
            const _SectionLabel('Administration'),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.admin_panel_settings,
              label: 'Admin Panel',
              color: AppTheme.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (user.role == 'admin') ...[
            _MenuItem(
              icon: Icons.lock_outlined,
              label: 'Admin Access',
              color: AppTheme.textSecondary,
              onTap: () => _showAdminPinDialog(context, user),
            ),
            const SizedBox(height: 8),
          ],
          const _SectionLabel('My Activity'),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.analytics_outlined,
            label: 'Prediction History',
            color: AppTheme.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PredictionHistoryScreen()),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Εμφάνιση'),
          const SizedBox(height: 8),
          _ThemeToggleTile(),
          const SizedBox(height: 16),
          const _SectionLabel('Account'),
          const SizedBox(height: 8),
          if (user.clubId == null)
            _MenuItem(
              icon: Icons.vpn_key_outlined,
              label: 'Join Club with Code',
              color: AppTheme.primaryLight,
              onTap: () => _showJoinWithCodeSheet(context, user),
            ),
          _MenuItem(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            onTap: () => _showEditProfile(context, user),
          ),
          _MenuItem(
            icon: Icons.notifications_outlined,
            label: 'Ειδοποιήσεις',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()),
            ),
          ),
          _MenuItem(
            icon: Icons.auto_stories,
            label: 'The Gazette — User Guide',
            onTap: () => _showHelp(context),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppTheme.red,
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textSecondary),
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
              await context.read<AppProvider>().signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAdminPinDialog(BuildContext context, UserModel user) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppTheme.accent, size: 20),
            SizedBox(width: 8),
            Text('Admin Access', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter admin PIN to unlock admin panel',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                letterSpacing: 8,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () async {
              const adminPin = String.fromEnvironment('CLUBERA_ADMIN_PIN');
              if (adminPin.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Admin PIN not configured. Set role via Firebase Console.',
                    ),
                    backgroundColor: AppTheme.red,
                  ),
                );
                return;
              }
              if (pinCtrl.text == adminPin) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'role': 'admin'});
                if (ctx.mounted) {
                  ctx.read<AppProvider>().updateUser(
                    user.copyWith(role: 'admin'),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Admin access granted!'),
                      backgroundColor: AppTheme.accent,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Wrong PIN'),
                    backgroundColor: AppTheme.red,
                  ),
                );
              }
            },
            child: const Text('Unlock', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    File? newPhotoFile;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
            const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            LogoPicker(
              initialUrl: user.photoUrl,
              onPicked: (f) => newPhotoFile = f,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              style: const TextStyle(color: AppTheme.textSecondary),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: user.email,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : () async {
                  final newName = nameCtrl.text.trim();
                  if (newName.isEmpty) return;
                  setSheet(() => saving = true);
                  final messenger = ScaffoldMessenger.of(ctx);
                  final prov = ctx.read<AppProvider>();
                  try {
                    String? photoUrl;
                    if (newPhotoFile != null) {
                      photoUrl = await StorageUtils.uploadUserPhoto(
                        newPhotoFile!,
                        user.uid,
                      );
                    }
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'name': newName,
                      if (photoUrl != null) 'photoUrl': photoUrl,
                    });
                    prov.updateUser(user.copyWith(
                      name: newName,
                      photoUrl: photoUrl ?? user.photoUrl,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated!'),
                        backgroundColor: AppTheme.primaryLight,
                      ),
                    );
                  } catch (e) {
                    if (ctx.mounted) setSheet(() => saving = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppTheme.red,
                      ),
                    );
                  }
                },
                child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
      },
    ).then((_) => nameCtrl.dispose());
  }

  void _showJoinWithCodeSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _JoinWithCodeSheet(user: user),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _NotificationsSheet(),
    );
  }

  void _showHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GazetteScreen()),
    );
  }
}

// ─── NOTIFICATIONS SHEET ─────────────────────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _liveMatches = true;
  bool _matchResults = true;
  bool _clubNews = false;
  bool _newPredictions = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _NotifToggle(
            label: 'Live Matches',
            subtitle: 'When a match goes live',
            value: _liveMatches,
            onChanged: (v) => setState(() => _liveMatches = v),
          ),
          _NotifToggle(
            label: 'Match Results',
            subtitle: 'Full time results',
            value: _matchResults,
            onChanged: (v) => setState(() => _matchResults = v),
          ),
          _NotifToggle(
            label: 'Club News',
            subtitle: 'News from clubs you follow',
            value: _clubNews,
            onChanged: (v) => setState(() => _clubNews = v),
          ),
          _NotifToggle(
            label: 'Predictions',
            subtitle: 'When your predictions are scored',
            value: _newPredictions,
            onChanged: (v) => setState(() => _newPredictions = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'Push notification settings coming soon',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.cardBg2,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primaryLight,
        ),
      ],
    ),
  );
}

// ─── ACTIVITIES SECTION ──────────────────────────────────────────────────────

class _ActivitiesSection extends StatelessWidget {
  final String userId;
  const _ActivitiesSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        final limited = (snap.data?.docs ?? [])
            .map(
              (d) =>
                  DonationModel.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (limited.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('My Support & Donations'),
              const SizedBox(height: 10),
              ...limited.map(
                (d) => _ActivityRow(
                  emoji: d.typeEmoji,
                  title: '${d.typeLabel} to ${d.clubName}',
                  subtitle: DateFormat('d MMM yyyy').format(d.createdAt),
                  amount: '€${d.amount.toStringAsFixed(2)}',
                  amountColor: AppTheme.liveRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── COUPON HISTORY SECTION ──────────────────────────────────────────────────

class _CouponHistorySection extends StatelessWidget {
  final String userId;
  const _CouponHistorySection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('coupon_picks')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        final limited = (snap.data?.docs ?? [])
            .map(
              (d) => CouponPick.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (limited.isEmpty) return const SizedBox.shrink();

        final earned = limited.fold<int>(
          0,
          (sum, p) => sum + (p.pointsEarned ?? 0),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SectionLabel('My Predictions'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+$earned pts total',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...limited
                  .take(5)
                  .map(
                    (p) => _ActivityRow(
                      emoji: p.isPending
                          ? '⏳'
                          : (p.pointsEarned ?? 0) > 0
                          ? '✅'
                          : '❌',
                      title: '${p.homeClubName} vs ${p.awayClubName}',
                      subtitle:
                          'Pick: ${p.pick == '1'
                              ? 'Home Win'
                              : p.pick == 'X'
                              ? 'Draw'
                              : 'Away Win'} • ${DateFormat('d MMM').format(p.createdAt)}',
                      amount: p.isPending
                          ? 'Pending'
                          : '${p.pointsEarned ?? 0} pts',
                      amountColor: p.isPending
                          ? AppTheme.textSecondary
                          : (p.pointsEarned ?? 0) > 0
                          ? AppTheme.supportGreen
                          : AppTheme.red,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  const _ActivityRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _ThemeToggleTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          tp.isDark ? Icons.dark_mode : Icons.light_mode,
          color: tp.isDark ? AppTheme.primaryLight : AppTheme.accent,
        ),
        title: Text(
          tp.isDark ? 'Dark Mode' : 'Light Mode',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
        ),
        trailing: Switch(
          value: tp.isDark,
          onChanged: (_) => tp.toggle(),
          activeColor: AppTheme.primaryLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── JOIN WITH CODE SHEET ─────────────────────────────────────────────────────

class _JoinWithCodeSheet extends StatefulWidget {
  final UserModel user;
  const _JoinWithCodeSheet({required this.user});

  @override
  State<_JoinWithCodeSheet> createState() => _JoinWithCodeSheetState();
}

class _JoinWithCodeSheetState extends State<_JoinWithCodeSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('clubs')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _error = 'Invalid code. Check with your club admin.';
          _loading = false;
        });
        return;
      }

      final clubId = query.docs.first.id;
      final clubData = query.docs.first.data();

      if (clubData['adminUid'] == widget.user.uid) {
        setState(() {
          _error = 'You are already the owner of this club.';
          _loading = false;
        });
        return;
      }

      final staffUids = List<String>.from(clubData['staffUids'] ?? []);
      if (staffUids.contains(widget.user.uid)) {
        setState(() {
          _error = 'You are already a member of this club.';
          _loading = false;
        });
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.user.uid),
        {'clubId': clubId, 'role': 'club'},
      );
      batch.update(
        FirebaseFirestore.instance.collection('clubs').doc(clubId),
        {'staffUids': FieldValue.arrayUnion([widget.user.uid])},
      );
      await batch.commit();

      if (mounted) {
        context.read<AppProvider>().updateUser(
          widget.user.copyWith(role: 'club', clubId: clubId),
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined club successfully!'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const Icon(Icons.vpn_key, color: AppTheme.primaryLight, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Join Club with Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask your club admin for the 6-character invite code',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'XXXXXX',
              hintStyle: const TextStyle(
                color: AppTheme.textSecondary,
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: AppTheme.cardBg2,
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryLight,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _join,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
                      'Join Club',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FOLLOWED CLUBS SECTION ───────────────────────────────────────────────────

class _FollowedClubsSection extends StatelessWidget {
  final UserModel user;
  const _FollowedClubsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.followedClubs.isEmpty) return const SizedBox.shrink();
    final clubIds = user.followedClubs.take(30).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MY CLUBS'),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .where(FieldPath.documentId, whereIn: clubIds)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final byId = {
                  for (final d in snap.data!.docs)
                    d.id: ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id),
                };
                final clubs = clubIds
                    .map((id) => byId[id])
                    .whereType<ClubModel>()
                    .toList();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: clubs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _ProfileClubChip(club: clubs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileClubChip extends StatelessWidget {
  final ClubModel club;
  const _ProfileClubChip({required this.club});

  @override
  Widget build(BuildContext context) {
    final logo = safeNetworkImage(club.logoUrl);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                image: logo != null
                    ? DecorationImage(image: logo, fit: BoxFit.cover)
                    : null,
              ),
              child: logo == null
                  ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  club.city,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GAMES SECTION ────────────────────────────────────────────────────────────

class _GamesSection extends StatelessWidget {
  final UserModel user;
  const _GamesSection({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.followedClubs.isEmpty) return const SizedBox.shrink();

    final clubs = user.followedClubs.take(30).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rewards')
          .where('clubId', whereIn: clubs)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final games = (snap.data?.docs ?? [])
            .map((d) => RewardModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (games.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SectionLabel('GAMES'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.supportGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${user.points} pts',
                      style: const TextStyle(
                        color: AppTheme.supportGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...games.map((g) => _GameCard(game: g, userPoints: user.points)),
            ],
          ),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  final RewardModel game;
  final int userPoints;
  const _GameCard({required this.game, required this.userPoints});

  @override
  Widget build(BuildContext context) {
    final canRedeem = userPoints >= game.pointsCost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canRedeem
              ? AppTheme.supportGreen.withOpacity(0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Text(game.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (game.description.isNotEmpty)
                  Text(
                    game.description,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                if (game.clubName != null)
                  Text(
                    game.clubName!,
                    style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.supportGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${game.pointsCost} pts',
                  style: const TextStyle(
                    color: AppTheme.supportGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 70,
                child: OutlinedButton(
                  onPressed: canRedeem ? () => _showRedeem(context) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(color: canRedeem ? AppTheme.accent : AppTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    textStyle: const TextStyle(fontSize: 11),
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
                Text(game.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    game.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              'Redeem "${game.title}" for ${game.pointsCost} pts?\n\nBalance: ${user.points} pts → ${user.points - game.pointsCost} pts remaining.',
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
                  try {
                    final provider = context.read<AppProvider>();
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'points': FieldValue.increment(-game.pointsCost)});
                    provider.updateUser(user.copyWith(points: user.points - game.pointsCost));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('${game.emoji} Redeemed! Contact the club to claim it.'),
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

// ─── CLUB APPLICATION ─────────────────────────────────────────────────────────

class _ClubApplicationTile extends StatelessWidget {
  final UserModel user;
  const _ClubApplicationTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('club_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('CLUB'),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.sports_soccer,
                label: 'Apply as Club',
                color: AppTheme.primaryLight,
                onTap: () => _showApplySheet(context),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final data = docs.first.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('CLUB APPLICATION'),
            const SizedBox(height: 8),
            _ApplicationStatusCard(status: status, clubName: data['clubName'] ?? ''),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ApplyAsClubSheet(user: user),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  final String status;
  final String clubName;
  const _ApplicationStatusCard({required this.status, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    final color = isPending
        ? AppTheme.accent
        : isApproved
            ? AppTheme.supportGreen
            : AppTheme.red;

    final icon = isPending
        ? Icons.hourglass_empty
        : isApproved
            ? Icons.check_circle_outline
            : Icons.cancel_outlined;

    final title = isPending
        ? 'Application Under Review'
        : isApproved
            ? 'Application Approved!'
            : 'Application Rejected';

    final subtitle = isPending
        ? 'Your application for "$clubName" is being reviewed by our team.'
        : isApproved
            ? '"$clubName" has been approved. Check your Club Panel!'
            : 'Your application for "$clubName" was not approved.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyAsClubSheet extends StatefulWidget {
  final UserModel user;
  const _ApplyAsClubSheet({required this.user});

  @override
  State<_ApplyAsClubSheet> createState() => _ApplyAsClubSheetState();
}

class _ApplyAsClubSheetState extends State<_ApplyAsClubSheet> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _league = kLeagues.first;
  String _category = kCategories.first;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (name.isEmpty || city.isEmpty) {
      setState(() => _error = 'Club name and city are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection('club_requests').add({
        'userId': widget.user.uid,
        'userName': widget.user.name,
        'userEmail': widget.user.email,
        'clubName': name,
        'city': city,
        'league': _league,
        'category': _category,
        'description': _descCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted! We\'ll review it shortly.'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 40),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Apply as Club',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Fill in your club details and we\'ll review your application.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Club Name *',
                prefixIcon: Icon(Icons.shield_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _cityCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City *',
                prefixIcon: Icon(Icons.location_city_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            const Text('League', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String>(
                value: _league,
                isExpanded: true,
                dropdownColor: AppTheme.cardBg,
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                items: kLeagues.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _league = v!),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Category', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: kCategories.map((cat) => ChoiceChip(
                label: Text(cat),
                selected: _category == cat,
                selectedColor: AppTheme.primaryLight,
                labelStyle: TextStyle(
                  color: _category == cat ? Colors.white : AppTheme.textSecondary,
                  fontWeight: _category == cat ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _category = cat),
              )).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About your club (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
