class TriviaQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int pointsPerCorrect;

  const TriviaQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.pointsPerCorrect = 10,
  });

  factory TriviaQuestion.fromMap(Map<String, dynamic> m, String id) =>
      TriviaQuestion(
        id: id,
        question: m['question'] ?? '',
        options: List<String>.from(m['options'] ?? const []),
        correctIndex: m['correctIndex'] ?? 0,
        pointsPerCorrect: m['pointsPerCorrect'] ?? 10,
      );

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'pointsPerCorrect': pointsPerCorrect,
      };
}
