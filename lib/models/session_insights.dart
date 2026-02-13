class SessionInsights {
  final String? summary;
  final List<String> keyConcepts;
  final List<Flashcard> flashcards;
  final List<String> actionItems;

  SessionInsights({
    required this.summary,
    required this.keyConcepts,
    required this.flashcards,
    required this.actionItems,
  });

  factory SessionInsights.fromJson(Map<String, dynamic> json) {
    String? parseSummary(dynamic value) {
      if (value is String) return value;
      if (value is Map<String, dynamic>) {
        final text = value['text'];
        if (text is String) return text;
      }
      return null;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<String> parseTermsList(dynamic value) {
      if (value is List) {
        return value
            .map((e) {
              if (e is String) return e;
              if (e is Map<String, dynamic>) {
                final term = e['term'];
                if (term is String) return term;
              }
              return '';
            })
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<String> parseActionItems(dynamic value) {
      if (value is List) {
        return value
            .map((e) {
              if (e is String) return e;
              if (e is Map<String, dynamic>) {
                final text = e['text'];
                if (text is String) return text;
              }
              return '';
            })
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<Flashcard> parseFlashcards(dynamic value) {
      if (value is List) {
        return value
            .map((e) {
              if (e is Map<String, dynamic>) {
                return Flashcard.fromJson(e);
              }
              return null;
            })
            .whereType<Flashcard>()
            .toList();
      }
      return [];
    }

    return SessionInsights(
      summary: parseSummary(json['summary']),
      keyConcepts: parseStringList(json['keyConcepts']).isNotEmpty
          ? parseStringList(json['keyConcepts'])
          : parseTermsList(json['keyTerms']),
      flashcards: parseFlashcards(json['flashcards']),
      actionItems: parseActionItems(json['actionItems']),
    );
  }
}

class Flashcard {
  final String question;
  final String answer;

  Flashcard({
    required this.question,
    required this.answer,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    final q = json['question'] ?? json['q'];
    final a = json['answer'] ?? json['a'];

    return Flashcard(
      question: (q ?? '').toString(),
      answer: (a ?? '').toString(),
    );
  }
}
