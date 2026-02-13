import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/session.dart';
import '../providers/sessions_provider.dart';
import 'session_detail_screen.dart';
import '../core/utils/session_format.dart';

class ConceptDetailScreen extends ConsumerWidget {
  final String concept;

  const ConceptDetailScreen({super.key, required this.concept});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final related = _filterSessions(sessions, concept);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          concept,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            'Sessions mentioning this concept',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 12),
          if (related.isEmpty)
            const _EmptyState()
          else
            ...[
              for (final s in related) ...[
                _SessionTile(session: s),
                const SizedBox(height: 12),
              ],
            ],
          const SizedBox(height: 18),
          Text(
            'Related flashcards',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 12),
          ..._flashcardsFor(related),
        ],
      ),
    );
  }

  List<Session> _filterSessions(List<Session> sessions, String concept) {
    final needle = concept.toLowerCase();
    return sessions.where((s) {
      final insights = s.parsedInsights;
      if (insights == null) return false;
      return insights.keyConcepts
          .any((c) => c.toLowerCase().contains(needle));
    }).toList();
  }

  List<Widget> _flashcardsFor(List<Session> sessions) {
    final cards = <Widget>[];
    for (final s in sessions) {
      final insights = s.parsedInsights;
      if (insights == null) continue;
      for (final f in insights.flashcards) {
        cards.add(
          _FlashcardTile(
            question: f.question,
            answer: f.answer,
          ),
        );
        cards.add(const SizedBox(height: 10));
      }
    }

    if (cards.isEmpty) {
      return [
        const _EmptyState(
          label: 'No flashcards tied to this concept yet.',
          icon: Icons.style_outlined,
        ),
      ];
    }

    return cards;
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.createdAt;
    final label = date == null ? '' : '${date.month}/${date.day}/${date.year}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.book, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displaySessionTitle(session),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (label.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _FlashcardTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FlashcardTile({
    required this.question,
    required this.answer,
  });

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final text = _showAnswer ? widget.answer : widget.question;
    return GestureDetector(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showAnswer ? 'ANSWER' : 'QUESTION',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showAnswer ? 'Tap to see question' : 'Tap to reveal answer',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  final IconData icon;

  const _EmptyState({
    this.label = 'No sessions yet.',
    this.icon = Icons.auto_awesome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            label,
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


