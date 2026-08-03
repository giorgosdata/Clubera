import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/game_model.dart';
import '../../../models/prize_model.dart';

// Placeholder tile colors used when no image URL is provided.
const List<Color> _kPlaceholderColors = [
  Color(0xFF4361EE),
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF8B5CF6),
];

class PuzzlePlayScreen extends StatefulWidget {
  final GameModel game;

  const PuzzlePlayScreen({super.key, required this.game});

  @override
  State<PuzzlePlayScreen> createState() => _PuzzlePlayScreenState();
}

class _PuzzlePlayScreenState extends State<PuzzlePlayScreen> {
  // 0-8 tile indices in current board positions.
  late List<int> _order;
  int? _selected;

  bool _checkingLimit = true;
  bool _canPlay = false;
  String _limitMessage = '';

  bool _solved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
    _checkDailyLimit();
  }

  // Build a shuffled order that is guaranteed not to equal the solved state.
  void _initPuzzle() {
    final rng = Random();
    do {
      _order = List.generate(9, (i) => i)..shuffle(rng);
    } while (_isSolved(_order));
  }

  bool _isSolved(List<int> order) {
    for (int i = 0; i < 9; i++) {
      if (order[i] != i) return false;
    }
    return true;
  }

  // ── Daily-limit check ───────────────────────────────────────────────────────

  Future<void> _checkDailyLimit() async {
    final user = context.read<AppProvider>().user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checkingLimit = false;
        _canPlay = false;
        _limitMessage = 'Δεν είσαι συνδεδεμένος';
      });
      return;
    }

    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('game_plays')
          .where('userId', isEqualTo: user.uid)
          .where('gameId', isEqualTo: widget.game.id)
          .where('playedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (!mounted) return;

      final todayCount = snap.docs.length;
      if (todayCount >= widget.game.dailyLimit) {
        setState(() {
          _checkingLimit = false;
          _canPlay = false;
          _limitMessage =
              'Έφτασες το ημερήσιο όριο (${widget.game.dailyLimit}/μέρα). Δοκίμασε αύριο!';
        });
      } else {
        setState(() {
          _checkingLimit = false;
          _canPlay = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingLimit = false;
        _canPlay = false;
        _limitMessage = 'Σφάλμα ελέγχου: $e';
      });
    }
  }

  // ── Tile interaction ────────────────────────────────────────────────────────

  void _onTileTap(int boardIndex) {
    if (!_canPlay || _solved || _saving) return;

    if (_selected == null) {
      setState(() => _selected = boardIndex);
      return;
    }

    if (_selected == boardIndex) {
      setState(() => _selected = null);
      return;
    }

    // Swap the two tiles.
    final a = _selected!;
    final b = boardIndex;
    setState(() {
      final tmp = _order[a];
      _order[a] = _order[b];
      _order[b] = tmp;
      _selected = null;
    });

    // Check for win.
    if (_isSolved(_order)) {
      _onSolved();
    }
  }

  // ── Save prize & show dialog ────────────────────────────────────────────────

  Future<void> _onSolved() async {
    setState(() {
      _solved = true;
      _saving = true;
    });

    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final prize =
        widget.game.prizes.isNotEmpty ? widget.game.prizes.first : null;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Write game_play record.
    final playRef = db.collection('game_plays').doc();
    batch.set(playRef, {
      'userId': user.uid,
      'gameId': widget.game.id,
      'gameTitle': widget.game.title,
      'pointsWon': (prize != null && prize.isPoints) ? prize.pointsValue : 0,
      'playedAt': FieldValue.serverTimestamp(),
    });

    // Write user_prize record and update points if applicable.
    if (prize != null) {
      final prizeRef = db.collection('user_prizes').doc();
      batch.set(prizeRef, {
        'userId': user.uid,
        'gameId': widget.game.id,
        'gameTitle': widget.game.title,
        'gameType': 'puzzle',
        'prizeTitle': prize.title,
        'prizeEmoji': prize.emoji,
        'prizeType': prize.type,
        'pointsValue': prize.pointsValue,
        'description': prize.description,
        'wonAt': FieldValue.serverTimestamp(),
        'status': prize.isPoints ? 'redeemed' : 'pending',
        if (prize.photoUrl != null) 'photoUrl': prize.photoUrl,
        if (prize.digitalContent != null) 'digitalContent': prize.digitalContent,
        if (prize.redeemByDate != null) 'redeemByDate': prize.redeemByDate,
      });

      if (prize.isPoints && prize.pointsValue > 0) {
        final userRef = db.collection('users').doc(user.uid);
        batch.update(userRef, {
          'points': FieldValue.increment(prize.pointsValue),
        });
      }
    }

    try {
      await batch.commit();
    } catch (e) {
      // Non-fatal — we still show the dialog.
      debugPrint('PuzzlePlayScreen: batch commit error: $e');
    }

    if (!mounted) return;
    setState(() => _saving = false);

    _showWinDialog(prize);
  }

  void _showWinDialog(PrizeModel? prize) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WinDialog(
        prize: prize,
        onContinue: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pop(); // leave puzzle screen
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.game.isExpired) {
      return Scaffold(
        backgroundColor: AppTheme.cardBg2,
        appBar: AppBar(
          title: Text(widget.game.title),
          backgroundColor: AppTheme.cardBg,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('⏰', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text(
                'Το παιχνίδι έχει λήξει',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Αυτό το παιχνίδι δεν είναι πλέον διαθέσιμο.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.game.title),
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checkingLimit) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryLight),
      );
    }

    if (!_canPlay) {
      return _AlreadyPlayedView(message: _limitMessage);
    }

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildPuzzleArea()),
          _buildHintBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Text('🧩', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Λύσε το Puzzle',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (widget.game.description.isNotEmpty)
                  Text(
                    widget.game.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_saving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.supportGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPuzzleArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(0.0, constraints.maxHeight) - 32;
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: 9,
                itemBuilder: (ctx, boardIndex) {
                  final tileIndex = _order[boardIndex];
                  final isSelected = _selected == boardIndex;
                  return _PuzzleTile(
                    tileIndex: tileIndex,
                    isSelected: isSelected,
                    imageUrl: widget.game.puzzleImageUrl,
                    onTap: () => _onTileTap(boardIndex),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHintBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Text(
        _selected != null
            ? 'Τώρα επίλεξε το κομμάτι που θέλεις να αλλάξεις'
            : 'Πάτησε ένα κομμάτι για να το επιλέξεις',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Puzzle tile ──────────────────────────────────────────────────────────────

class _PuzzleTile extends StatelessWidget {
  final int tileIndex;
  final bool isSelected;
  final String? imageUrl;
  final VoidCallback onTap;

  const _PuzzleTile({
    required this.tileIndex,
    required this.isSelected,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: AppTheme.supportGreen, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
        ),
        child: imageUrl != null
            ? _ImageTile(tileIndex: tileIndex, imageUrl: imageUrl!)
            : _ColorTile(tileIndex: tileIndex),
      ),
    );
  }
}

/// Clips to a 1/3 x 1/3 portion of a network image.
class _ImageTile extends StatelessWidget {
  final int tileIndex;
  final String imageUrl;

  const _ImageTile({required this.tileIndex, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // Row and column in the 3x3 grid.
    final col = tileIndex % 3;
    final row = tileIndex ~/ 3;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tileW = constraints.maxWidth;
        final tileH = constraints.maxHeight;

        // Full image is 3x the tile size; offset shifts to the correct slice.
        final fullW = tileW * 3;
        final fullH = tileH * 3;
        final offsetX = -col * tileW;
        final offsetY = -row * tileH;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: fullW,
            maxHeight: fullH,
            child: Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: SizedBox(
                width: fullW,
                height: fullH,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.cardBg2,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _ColorTile(tileIndex: tileIndex),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Solid-color placeholder tile when no image is available.
class _ColorTile extends StatelessWidget {
  final int tileIndex;

  const _ColorTile({required this.tileIndex});

  @override
  Widget build(BuildContext context) {
    final col = tileIndex % 3;
    final row = tileIndex ~/ 3;
    final color = _kPlaceholderColors[tileIndex % _kPlaceholderColors.length];

    return Container(
      color: color.withValues(alpha: 0.85),
      child: Center(
        child: Text(
          '${row + 1}-${col + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ── Already-played view ──────────────────────────────────────────────────────

class _AlreadyPlayedView extends StatelessWidget {
  final String message;

  const _AlreadyPlayedView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⏰', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Επιστροφή'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cardBg,
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.divider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Win dialog ───────────────────────────────────────────────────────────────

class _WinDialog extends StatelessWidget {
  final PrizeModel? prize;
  final VoidCallback onContinue;

  const _WinDialog({required this.prize, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final hasPoints = prize != null && prize!.isPoints && prize!.pointsValue > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2560), Color(0xFF101840)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.supportGreen.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.supportGreen.withValues(alpha: 0.3),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Big emoji
            Text(
              prize?.emoji ?? '🎉',
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),

            // "Συγχαρητήρια!" headline
            const Text(
              'Συγχαρητήρια!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Prize title
            if (prize != null) ...[
              Text(
                prize!.title,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],

            // Points badge
            if (hasPoints) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.supportGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.supportGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars,
                        color: AppTheme.accent, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '+${prize!.pointsValue} πόντοι',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Description
            if (prize != null && prize!.description.isNotEmpty) ...[
              Text(
                prize!.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 16),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.supportGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Συνέχεια'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
