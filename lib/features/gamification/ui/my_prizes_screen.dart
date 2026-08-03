import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserPrizeModel {
  final String id;
  final String userId;
  final String gameId;
  final String gameTitle;
  final String gameType;
  final String prizeTitle;
  final String prizeEmoji;
  final String prizeType; // 'points' | 'physical' | 'digital'
  final int pointsValue;
  final String description;
  final String? clubId;
  final String? clubName;
  final DateTime wonAt;
  final DateTime? redeemedAt;
  final String status; // 'pending' | 'redeemed'
  final String? photoUrl;
  final String? digitalContent;
  final DateTime? redeemByDate;

  const UserPrizeModel({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.gameTitle,
    required this.gameType,
    required this.prizeTitle,
    required this.prizeEmoji,
    required this.prizeType,
    required this.pointsValue,
    required this.description,
    this.clubId,
    this.clubName,
    required this.wonAt,
    this.redeemedAt,
    required this.status,
    this.photoUrl,
    this.digitalContent,
    this.redeemByDate,
  });

  bool get isExpiredForRedeem =>
      redeemByDate != null && DateTime.now().isAfter(redeemByDate!);

  factory UserPrizeModel.fromMap(Map<dynamic, dynamic> m, String id) {
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return UserPrizeModel(
      id: id,
      userId: m['userId'] as String? ?? '',
      gameId: m['gameId'] as String? ?? '',
      gameTitle: m['gameTitle'] as String? ?? '',
      gameType: m['gameType'] as String? ?? '',
      prizeTitle: m['prizeTitle'] as String? ?? '',
      prizeEmoji: m['prizeEmoji'] as String? ?? '🎁',
      prizeType: m['prizeType'] as String? ?? 'points',
      pointsValue: (m['pointsValue'] as num?)?.toInt() ?? 0,
      description: m['description'] as String? ?? '',
      clubId: m['clubId'] as String?,
      clubName: m['clubName'] as String?,
      wonAt: parseTs(m['wonAt']),
      redeemedAt: m['redeemedAt'] != null ? parseTs(m['redeemedAt']) : null,
      status: m['status'] as String? ?? 'pending',
      photoUrl: m['photoUrl'] as String?,
      digitalContent: m['digitalContent'] as String?,
      redeemByDate:
          m['redeemByDate'] != null ? parseTs(m['redeemByDate']) : null,
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyPrizesScreen extends StatelessWidget {
  const MyPrizesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AppProvider>().user!.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('🎁 Τα Δώρα μου'),
        backgroundColor: AppTheme.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_prizes')
            .where('userId', isEqualTo: uid)
            .orderBy('wonAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState();
          }

          final prizes = docs
              .map((d) => UserPrizeModel.fromMap(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ))
              .toList();

          final pending =
              prizes.where((p) => p.status == 'pending').toList();
          final redeemed =
              prizes.where((p) => p.status == 'redeemed').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (pending.isNotEmpty) ...[
                _GroupLabel('ΕΚΚΡΕΜΗ (${pending.length})'),
                const SizedBox(height: 10),
                ...pending.map((p) => _PrizeCard(prize: p)),
                const SizedBox(height: 20),
              ],
              if (redeemed.isNotEmpty) ...[
                _GroupLabel('ΕΞΑΡΓΥΡΩΜΕΝΑ (${redeemed.length})'),
                const SizedBox(height: 10),
                ...redeemed.map((p) => _PrizeCard(prize: p)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─── Group Label ─────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, color: AppTheme.textSecondary, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Δεν έχεις δώρα ακόμα!',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Prize Card ──────────────────────────────────────────────────────────────

class _PrizeCard extends StatefulWidget {
  final UserPrizeModel prize;
  const _PrizeCard({required this.prize});

  @override
  State<_PrizeCard> createState() => _PrizeCardState();
}

class _PrizeCardState extends State<_PrizeCard> {
  Color get _borderColor {
    switch (widget.prize.prizeType) {
      case 'points':
        return AppTheme.supportGreen;
      case 'digital':
        return AppTheme.primaryLight;
      case 'physical':
        return const Color(0xFFEAB308);
      default:
        return AppTheme.divider;
    }
  }

  Color get _badgeColor {
    switch (widget.prize.prizeType) {
      case 'points':
        return AppTheme.supportGreen;
      case 'digital':
        return AppTheme.primaryLight;
      case 'physical':
        return const Color(0xFFEAB308);
      default:
        return AppTheme.textSecondary;
    }
  }

  String get _badgeLabel {
    switch (widget.prize.prizeType) {
      case 'points':
        return 'Πόντοι';
      case 'digital':
        return 'Ψηφιακό';
      case 'physical':
        return 'Φυσικό';
      default:
        return widget.prize.prizeType;
    }
  }

  Future<void> _markAsRedeemed() async {
    try {
      await FirebaseFirestore.instance
          .collection('user_prizes')
          .doc(widget.prize.id)
          .update({
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Σφάλμα: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  void _showRedeemSheet(BuildContext context) {
    final prize = widget.prize;
    final code = prize.id.length > 8
        ? prize.id.substring(prize.id.length - 8).toUpperCase()
        : prize.id.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RedeemSheet(prize: prize, code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prize = widget.prize;
    final dateStr = DateFormat('dd/MM/yyyy').format(prize.wonAt);
    final isRedeemed = prize.status == 'redeemed';
    final canRedeem = !isRedeemed && prize.prizeType != 'points';

    final bool isDigitalWithContent =
        prize.prizeType == 'digital' && prize.digitalContent != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor.withOpacity(isRedeemed ? 0.2 : 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji
              Text(prize.prizeEmoji,
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(width: 14),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prize.prizeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prize.gameTitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (prize.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        prize.description,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _badgeLabel,
                  style: TextStyle(
                    color: _badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // (1) Physical prize photo
          if (prize.photoUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                prize.photoUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          // (2) Digital prize content
          if (isDigitalWithContent) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.accent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Το δώρο σου:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    prize.digitalContent!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Αντιγραφή'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: prize.digitalContent!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Αντιγράφηκε!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          // (3) Redeem expiry
          if (prize.redeemByDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 13,
                  color: prize.isExpiredForRedeem
                      ? Colors.red
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  prize.isExpiredForRedeem
                      ? 'Έληξε ${DateFormat('dd/MM/yyyy').format(prize.redeemByDate!)}'
                      : 'Λήξη: ${DateFormat('dd/MM/yyyy').format(prize.redeemByDate!)}',
                  style: TextStyle(
                    color: prize.isExpiredForRedeem
                        ? Colors.red
                        : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Date row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 4),
              Text(
                'Κερδήθηκε: $dateStr',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // (4) Action row
          if (canRedeem) ...[
            if (isDigitalWithContent)
              // Digital with content: mark as used directly
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _markAsRedeemed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  child: const Text('Σημείωσε ως χρησιμοποιημένο'),
                ),
              )
            else if (prize.isExpiredForRedeem)
              // Physical expired: disabled button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor:
                        AppTheme.textSecondary.withOpacity(0.2),
                    disabledForegroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  child: const Text('Έληξε'),
                ),
              )
            else
              // Physical not expired: normal redeem flow
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showRedeemSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.supportGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  child: const Text('Εξαργύρωση'),
                ),
              ),
          ],
          if (isRedeemed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.supportGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.supportGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppTheme.supportGreen, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    prize.redeemedAt != null
                        ? '✓ Εξαργυρωμένο στις ${DateFormat('dd/MM/yyyy').format(prize.redeemedAt!)}'
                        : '✓ Εξαργυρωμένο',
                    style: const TextStyle(
                      color: AppTheme.supportGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Redeem Bottom Sheet ─────────────────────────────────────────────────────

class _RedeemSheet extends StatefulWidget {
  final UserPrizeModel prize;
  final String code;
  const _RedeemSheet({required this.prize, required this.code});

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('user_prizes')
          .doc(widget.prize.id)
          .update({
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Σφάλμα: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Big emoji
          Text(widget.prize.prizeEmoji,
              style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          // Title
          Text(
            widget.prize.prizeTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Instruction
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryLight.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.primaryLight, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Δείξε αυτή την οθόνη στον club admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Code box
          const Text(
            'CODE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text(
              widget.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Επιβεβαίωσε Εξαργύρωση'),
            ),
          ),
        ],
      ),
    );
  }
}
