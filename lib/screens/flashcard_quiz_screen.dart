import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/flashcard_deck_provider.dart';

class FlashcardQuizScreen extends ConsumerStatefulWidget {
  const FlashcardQuizScreen({super.key});

  @override
  ConsumerState<FlashcardQuizScreen> createState() =>
      _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends ConsumerState<FlashcardQuizScreen> {
  int _index = 0;
  bool _showAnswer = false;
  late List<DeckCard> _deck;
  final List<int> _skipHistory = [];

  @override
  void initState() {
    super.initState();
    _deck = [];
  }

  void _shuffle(List<DeckCard> deck) {
    final random = Random();
    setState(() {
      _deck = [...deck]..shuffle(random);
      _index = 0;
      _showAnswer = false;
      _skipHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(flashcardDeckProvider);

    if (_deck.isEmpty && deck.isNotEmpty) {
      _deck = [...deck];
    }

    if (deck.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Mode')),
        body: const Center(
          child: Text('Add cards to your deck first.'),
        ),
      );
    }

    final card = _deck[_index];
    final total = _deck.length;
    final hasUndo = _skipHistory.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Mode'),
        actions: [
          IconButton(
            onPressed: () => _shuffle(deck),
            icon: const Icon(Icons.shuffle),
          ),
          if (hasUndo)
            IconButton(
              onPressed: () {
                final last = _skipHistory.removeLast();
                setState(() {
                  _index = last;
                  _showAnswer = false;
                });
              },
              icon: const Icon(Icons.undo),
              tooltip: 'Undo skip',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Card ${_index + 1} of $total',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showAnswer ? 'ANSWER' : 'QUESTION',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.subtext,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showAnswer ? card.answer : card.question,
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _showAnswer
                            ? 'Tap to see question'
                            : 'Tap to reveal answer',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index == 0
                        ? null
                        : () {
                            setState(() {
                              _index--;
                              _showAnswer = false;
                            });
                          },
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _skipHistory.add(_index);
                      setState(() {
                        if (_index < total - 1) {
                          _index++;
                          _showAnswer = false;
                        } else {
                          _index = 0;
                          _showAnswer = false;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Card skipped'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              if (_skipHistory.isEmpty) return;
                              final last = _skipHistory.removeLast();
                              setState(() {
                                _index = last;
                                _showAnswer = false;
                              });
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_index < total - 1) {
                          _index++;
                          _showAnswer = false;
                        } else {
                          _index = 0;
                          _showAnswer = false;
                        }
                      });
                    },
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


