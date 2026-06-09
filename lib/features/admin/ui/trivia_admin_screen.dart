import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/trivia_question.dart';

class TriviaAdminScreen extends StatelessWidget {
  final String gameId;
  final String gameTitle;
  const TriviaAdminScreen({super.key, required this.gameId, required this.gameTitle});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('games').doc(gameId).collection('questions');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Trivia: $gameTitle'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('New Question'),
        onPressed: () => _showQuestionDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Σφάλμα: ${snap.error}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = (snap.data?.docs ?? [])
              .map((d) => TriviaQuestion.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          if (questions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: AppTheme.cardBg2),
                  SizedBox(height: 12),
                  Text('No questions yet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Tap + to add', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: questions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final q = questions[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Q${i + 1}: ${q.question}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.accent, size: 18),
                          onPressed: () => _showQuestionDialog(context, existing: q),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18),
                          onPressed: () => _col.doc(q.id).delete(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...q.options.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                e.key == q.correctIndex
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: e.key == q.correctIndex
                                    ? AppTheme.supportGreen
                                    : AppTheme.textSecondary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(e.value,
                                    style: TextStyle(
                                      color: e.key == q.correctIndex
                                          ? AppTheme.supportGreen
                                          : AppTheme.textSecondary,
                                      fontSize: 12,
                                    )),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 4),
                    Text('${q.pointsPerCorrect} pts για σωστή',
                        style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showQuestionDialog(BuildContext context, {TriviaQuestion? existing}) {
    final qCtrl = TextEditingController(text: existing?.question ?? '');
    final optCtrls = List.generate(
      4,
      (i) => TextEditingController(text: existing?.options.elementAtOrNull(i) ?? ''),
    );
    final ptsCtrl = TextEditingController(text: '${existing?.pointsPerCorrect ?? 10}');
    int correct = existing?.correctIndex ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(existing == null ? 'New Question' : 'Edit Question',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: qCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Ερώτηση'),
                ),
                const SizedBox(height: 8),
                const Text('Απαντήσεις (διάλεξε τη σωστή)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: i,
                        groupValue: correct,
                        activeColor: AppTheme.supportGreen,
                        onChanged: (v) => setS(() => correct = v ?? 0),
                      ),
                      Expanded(
                        child: TextField(
                          controller: optCtrls[i],
                          style: const TextStyle(color: Colors.white),
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: 'Επιλογή ${i + 1}',
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 6),
                TextField(
                  controller: ptsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Πόντοι σωστής απάντησης'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final question = qCtrl.text.trim();
                final options = optCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
                if (question.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Need question + at least 2 options')),
                  );
                  return;
                }
                if (correct >= options.length) correct = 0;
                final pts = int.tryParse(ptsCtrl.text) ?? 10;
                final data = TriviaQuestion(
                  id: existing?.id ?? '',
                  question: question,
                  options: options,
                  correctIndex: correct,
                  pointsPerCorrect: pts,
                ).toMap();
                try {
                  if (existing == null) {
                    await _col.add(data);
                  } else {
                    await _col.doc(existing.id).update(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      qCtrl.dispose();
      for (final c in optCtrls) c.dispose();
      ptsCtrl.dispose();
    });
  }
}
