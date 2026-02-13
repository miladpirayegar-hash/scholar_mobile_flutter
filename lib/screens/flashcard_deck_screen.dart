import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/flashcard_deck_provider.dart';
import 'flashcard_quiz_screen.dart';

class FlashcardDeckScreen extends ConsumerWidget {
  const FlashcardDeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(flashcardDeckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Deck'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              Text(
                '${deck.length} cards saved',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtext,
                ),
              ),
              const Spacer(),
              if (deck.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FlashcardQuizScreen(),
                      ),
                    );
                  },
                  child: const Text('Start Quiz'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (deck.isEmpty)
            const _EmptyState()
          else
            ...[
              for (final card in deck) ...[
                _DeckCardTile(card: card),
                const SizedBox(height: 12),
              ],
            ],
        ],
      ),
    );
  }
}

class _DeckCardTile extends ConsumerWidget {
  final DeckCard card;

  const _DeckCardTile({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.question,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            card.answer,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                ref.read(flashcardDeckProvider.notifier).remove(card.id);
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text(
                'Remove',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.style_outlined, size: 26, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            'No cards saved yet.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}


