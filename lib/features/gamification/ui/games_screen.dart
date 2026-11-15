import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/game_model.dart';
import '../../../models/trivia_question.dart';
import 'leaderboard_screen.dart';
import 'penalty_play_screen.dart';
import 'puzzle_play_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.videogame_asset, color: AppTheme.accent, size: 22),
            SizedBox(width: 8),
            Text('Play & Earn'),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: const GamesContent(),
    );
  }
}

class GamesContent extends StatelessWidget {
  const GamesContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Σφάλμα: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = (snap.data?.docs ?? [])
              .map((d) =>
                  GameModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              // Games of chance were removed; show only the playable types.
              .where((g) => kPlayableGameTypes.contains(g.type))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (games.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videogame_asset_outlined,
                      size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('Δεν υπάρχουν παιχνίδια',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Δοκίμασε ξανά αργότερα',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Points header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.navyGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: AppTheme.accent, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Οι πόντοι σου',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          Text(
                            '${user?.points ?? 0} pts',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.leaderboard, color: AppTheme.accent, size: 28),
                      tooltip: 'Leaderboard',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'PLAY TO EARN',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              ...games.map((g) => _GameCard(game: g)),
            ],
          );
        },
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameModel game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final expired = game.isExpired;
    return Opacity(
      opacity: expired ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(game.typeEmoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  if (game.description.isNotEmpty)
                    Text(game.description,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Win ${game.minPoints}–${game.maxPoints} pts',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  if (game.expiresAt != null && !expired)
                    Text(
                      'Έως ${game.expiresAt!.day}/${game.expiresAt!.month}/${game.expiresAt!.year}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (expired)
              Chip(
                label: const Text(
                  'Έληξε',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
                padding: EdgeInsets.zero,
              )
            else
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                onPressed: () => _openGame(context, game),
                child: const Text('Play'),
              ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, GameModel game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => switch (game.type) {
              'trivia' => TriviaPlayScreen(game: game),
              'penalty' => PenaltyPlayScreen(game: game),
              _ => PuzzlePlayScreen(game: game),
            },
      ),
    );
  }
}

// ─── TRIVIA PLAY SCREEN ──────────────────────────────────────────────────────

class TriviaPlayScreen extends StatefulWidget {
  final GameModel game;
  const TriviaPlayScreen({super.key, required this.game});

  @override
  State<TriviaPlayScreen> createState() => _TriviaPlayScreenState();
}

class _TriviaPlayScreenState extends State<TriviaPlayScreen> {
  List<TriviaQuestion> _questions = [];
  int _index = 0;
  int _correctCount = 0;
  int _pointsWon = 0;
  bool _loading = true;
  bool _canPlay = false;
  String _limitMessage = '';
  int? _selectedAnswer;
  bool _showResult = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = context.read<AppProvider>().user;
    if (user == null) {
      setState(() {
        _loading = false;
        _limitMessage = 'Not logged in';
      });
      return;
    }
    try {
      final nowUtc = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final playsSnap = await FirebaseFirestore.instance
          .collection('game_plays')
          .where('userId', isEqualTo: user.uid)
          .where('gameId', isEqualTo: widget.game.id)
          .where('playedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      if (playsSnap.docs.length >= widget.game.dailyLimit) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _limitMessage = 'Έφτασες το όριο (${widget.game.dailyLimit}/μέρα). Δοκίμασε αύριο!';
        });
        return;
      }
      final qSnap = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.game.id)
          .collection('questions')
          .get();
      final questions = qSnap.docs
          .map((d) => TriviaQuestion.fromMap(d.data(), d.id))
          .toList()
        ..shuffle();
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
          _loading = false;
          _limitMessage = 'Δεν υπάρχουν ερωτήσεις σε αυτό το quiz';
        });
        return;
      }
      setState(() {
        _questions = questions.take(5).toList();
        _canPlay = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _limitMessage = 'Σφάλμα: $e';
      });
    }
  }

  void _answer(int i) {
    if (_showResult) return;
    final q = _questions[_index];
    final isCorrect = i == q.correctIndex;
    setState(() {
      _selectedAnswer = i;
      _showResult = true;
      if (isCorrect) {
        _correctCount++;
        _pointsWon += q.pointsPerCorrect;
      }
    });
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selectedAnswer = null;
        _showResult = false;
      });
    } else {
      // Finished — save play
      final user = context.read<AppProvider>().user;
      if (user == null) return;
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(user.uid),
          {'points': FieldValue.increment(_pointsWon)},
        );
        batch.set(FirebaseFirestore.instance.collection('game_plays').doc(), {
          'userId': user.uid,
          'userName': user.name,
          'gameId': widget.game.id,
          'gameTitle': widget.game.title,
          'pointsWon': _pointsWon,
          'playedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        if (mounted) {
          context.read<AppProvider>().updateUser(
                user.copyWith(points: user.points + _pointsWon),
              );
          setState(() => _finished = true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.game.title),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TriviaLeaderboardScreen(
                  gameId: widget.game.id,
                  gameTitle: widget.game.title,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !_canPlay
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🧠', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 16),
                          Text(_limitMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      ),
                    )
                  : _finished
                      ? _buildResult()
                      : _buildQuestion(),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ερώτηση ${_index + 1}/${_questions.length}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            Text('$_pointsWon pts',
                style: const TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          q.question,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...q.options.asMap().entries.map((e) {
          final isSelected = _selectedAnswer == e.key;
          final isCorrect = e.key == q.correctIndex;
          Color borderColor = AppTheme.divider;
          Color bg = AppTheme.cardBg;
          if (_showResult) {
            if (isCorrect) {
              borderColor = AppTheme.supportGreen;
              bg = AppTheme.supportGreen.withValues(alpha: 0.15);
            } else if (isSelected) {
              borderColor = AppTheme.red;
              bg = AppTheme.red.withValues(alpha: 0.15);
            }
          } else if (isSelected) {
            borderColor = AppTheme.accent;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: () => _answer(e.key),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                    if (_showResult && isCorrect)
                      const Icon(Icons.check_circle, color: AppTheme.supportGreen),
                    if (_showResult && isSelected && !isCorrect)
                      const Icon(Icons.cancel, color: AppTheme.red),
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        if (_showResult)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _next,
              child: Text(
                _index == _questions.length - 1 ? 'Δες τα αποτελέσματα' : 'Επόμενη',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(
            '$_correctCount/${_questions.length} σωστές',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '+$_pointsWon pts',
            style: const TextStyle(
                color: AppTheme.supportGreen, fontSize: 48, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(context),
            child: const Text('Συνέχεια'),
          ),
        ],
      ),
    );
  }
}

// ─── TRIVIA LEADERBOARD ───────────────────────────────────────────────────────

class TriviaLeaderboardScreen extends StatelessWidget {
  final String gameId;
  final String gameTitle;
  const TriviaLeaderboardScreen({
    super.key,
    required this.gameId,
    required this.gameTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('$gameTitle – Top Players'),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('game_plays')
            .where('gameId', isEqualTo: gameId)
            .orderBy('pointsWon', descending: true)
            .limit(200)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          // De-dup: keep best score per user
          final seen = <String>{};
          final entries = <Map<String, dynamic>>[];
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final uid = data['userId'] as String? ?? '';
            if (!seen.contains(uid)) {
              seen.add(uid);
              entries.add(data);
            }
          }
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'Κανείς δεν έχει παίξει ακόμα',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final e = entries[i];
              final rank = i + 1;
              final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          medal,
                          style: TextStyle(
                            fontSize: rank <= 3 ? 22 : 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e['userName'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${e['pointsWon']} pts',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
