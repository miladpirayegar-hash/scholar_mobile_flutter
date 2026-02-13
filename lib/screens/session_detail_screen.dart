// lib/screens/session_detail_screen.dart
// STEP 10 (A+B+C) APPLIED IN ONE PASS
// - Tasks preview + "View all tasks"
// - Trust/processing affordances
// - Micro-copy polish
// - Single full file replacement
// - No backend or provider changes

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/session.dart';
import '../providers/session_detail_provider.dart';
import '../providers/flashcard_deck_provider.dart';
import 'syntra_screen.dart';
import '../core/utils/session_format.dart';
import '../providers/sessions_provider.dart';
import '../providers/session_overrides_provider.dart';
import '../models/session_insights.dart';
import '../providers/tasks_providers.dart';
import '../features/tasks/models/manual_task.dart';
import 'assign_session_to_unit_sheet.dart';
import '../services/api/api_providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(session.id));
    final deck = ref.watch(flashcardDeckProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displaySessionTitle(session),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showEditTitle(context, ref, session),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AssignSessionToUnitSheet(session: session),
              );
            },
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Change course',
          ),
          IconButton(
            onPressed: () {
              showDeleteConfirm(
                context: context,
                title: 'Delete Session?',
                message: 'This action is permanent and cannot be undone.',
                onConfirm: () {
                  ref.read(sessionsProvider.notifier).removeSession(session.id);
                  Navigator.of(context).pop();
                },
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: sessionAsync.when(
        loading: () => const _LoadingState(),
        error: (_, _) => const _ErrorState(),
        data: (fullSession) {
          final override =
              ref.watch(sessionOverridesProvider)[fullSession.id];
          final baseInsights = fullSession.parsedInsights;
          final mergedInsights = _mergeInsights(baseInsights, override);
          final isReady = fullSession.isReady;

          final actionItems =
              mergedInsights?.actionItems ?? const <String>[];
          final summary = mergedInsights?.summary;
          final sessionTasks = ref
              .watch(tasksProvider)
              .where((t) {
                if (t is StudyTask) return t.sessionId == fullSession.id;
                if (t is ManualTask) return t.sessionId == fullSession.id;
                return false;
              })
              .toList();

          final transcript =
              override?.transcript ?? fullSession.transcript;
          final hasTranscript =
              transcript != null && transcript.trim().isNotEmpty;
          final transcriptTooShort = isReady && !hasTranscript;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  status: fullSession.status,
                ),
                const SizedBox(height: 12),
                _SyntraButton(session: fullSession),

                if (!isReady) ...[
                  const SizedBox(height: 12),
                  const _InfoBanner(
                    title: 'We\'re working on this',
                    subtitle:
                        'Your transcript and insights will appear here once analysis is complete. You can come back anytime.',
                    icon: Icons.auto_awesome,
                  ),
                ],

                const SizedBox(height: 24),

                // Transcript
                Row(
                  children: [
                    const Expanded(child: _SectionTitle('Transcript')),
                    if (hasTranscript)
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: transcript),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transcript copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    TextButton(
                      onPressed: () =>
                          _editTranscript(context, ref, fullSession, transcript),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Card(
                  child: hasTranscript
                      ? Text(
                          transcript,
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : transcriptTooShort
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'We couldn\'t generate a transcript.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'The recording was too quiet or too short. '
                                  'Try re-recording with clearer speech and less background noise.',
                                  style: TextStyle(
                                    color: AppColors.subtext,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            )
                          : const _ProcessingText(
                              'We\'re generating your transcript.',
                            ),
                ),
                if (transcriptTooShort) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(apiServiceProvider)
                              .reprocessSession(fullSession.id);
                          await ref
                              .read(sessionsProvider.notifier)
                              .refresh();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reprocessing started'),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Failed to reprocess. Please try again.'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reprocess recording'),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Insights
                const _SectionTitle('Insights'),
                const SizedBox(height: 12),

                if (mergedInsights == null)
                  const _Card(
                    child: _ProcessingText(
                      'We\'re turning this session into insights.',
                    ),
                  ),

                if (mergedInsights != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox.shrink(),
                      TextButton(
                        onPressed: () => _editInsights(
                          context,
                          ref,
                          fullSession,
                          mergedInsights,
                        ),
                        child: const Text('Edit insights'),
                      ),
                    ],
                  ),
                  if (summary != null) ...[
                    _InsightSection(
                      title: 'Summary',
                      child: Text(summary),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (mergedInsights.keyConcepts.isNotEmpty) ...[
                    _InsightSection(
                      title: 'Key Concepts',
                      child: Column(
                        children: mergedInsights.keyConcepts
                            .map((c) => _Bullet(c))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (mergedInsights.flashcards.isNotEmpty) ...[
                    _InsightSection(
                      title: 'Flashcards',
                      child: Column(
                        children: mergedInsights.flashcards
                            .map(
                              (f) => _FlashcardView(
                                question: f.question,
                                answer: f.answer,
                                isSaved: deck.any(
                                  (d) => d.id ==
                                      '${fullSession.id}::${'${f.question}::${f.answer}'.hashCode}',
                                ),
                                onSave: () {
                                  final id =
                                      '${fullSession.id}::${'${f.question}::${f.answer}'.hashCode}';
                                  ref
                                      .read(flashcardDeckProvider.notifier)
                                      .add(
                                        DeckCard(
                                          id: id,
                                          sessionId: fullSession.id,
                                          question: f.question,
                                          answer: f.answer,
                                          createdAt:
                                              fullSession.createdAt ??
                                                  DateTime.now(),
                                        ),
                                      );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (actionItems.isNotEmpty)
                    _InsightSection(
                      title: 'Action Items',
                      child: Column(
                        children: actionItems
                            .map((a) => _ActionItem(text: a))
                            .toList(),
                      ),
                    )
                  else if (sessionTasks.isNotEmpty)
                    _InsightSection(
                      title: 'Tasks',
                      child: Column(
                        children: sessionTasks
                            .map((t) => _TaskItem(text: t.text as String))
                            .toList(),
                      ),
                    ),
                ],

                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  SessionInsights? _mergeInsights(
    SessionInsights? base,
    SessionOverride? override,
  ) {
    if (override == null || !override.hasAny) return base;

    return SessionInsights(
      summary: override.summary ?? base?.summary,
      keyConcepts: override.keyConcepts ?? base?.keyConcepts ?? const [],
      flashcards: override.flashcards ?? base?.flashcards ?? const [],
      actionItems: override.actionItems ?? base?.actionItems ?? const [],
    );
  }

  void _editTranscript(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String? current,
  ) {
    final controller = TextEditingController(text: current ?? '');
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Edit Transcript',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste or edit transcript...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(sessionOverridesProvider.notifier).setTranscript(
                        session.id,
                        controller.text.trim(),
                      );
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editInsights(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SessionInsights insights,
  ) {
    final summary = TextEditingController(text: insights.summary ?? '');
    final concepts = TextEditingController(
      text: insights.keyConcepts.join('\n'),
    );
    final actionItems = TextEditingController(
      text: insights.actionItems.join('\n'),
    );
    final flashcards = TextEditingController(
      text: insights.flashcards
          .map((f) => '${f.question} | ${f.answer}')
          .join('\n'),
    );

    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Edit Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: summary,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Summary',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: concepts,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Key Concepts (one per line)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: actionItems,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Action Items (one per line)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: flashcards,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Flashcards (Q | A per line)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final parsedConcepts = concepts.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  final parsedActions = actionItems.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  final parsedCards = flashcards.text
                      .split('\n')
                      .map((e) => e.split('|'))
                      .where((parts) => parts.length >= 2)
                      .map<Flashcard>((parts) => Flashcard(
                            question: parts[0].trim(),
                            answer: parts.sublist(1).join('|').trim(),
                          ))
                      .toList();

                  ref.read(sessionOverridesProvider.notifier).setInsights(
                        sessionId: session.id,
                        summary: summary.text.trim(),
                        keyConcepts: parsedConcepts,
                        actionItems: parsedActions,
                        flashcards: parsedCards,
                      );
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditTitle(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) {
    showEditModal(
      context: context,
      title: 'Rename Session',
      initialValue: session.title,
      hintText: 'Session title',
      saveLabel: 'Save',
      onSave: (value) {
        ref.read(sessionsProvider.notifier).updateSessionTitle(
              sessionId: session.id,
              title: value,
            );
      },
    );
  }
}

// ---------- STATES ----------

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Failed to load session'),
    );
  }
}

// ---------- HEADER ----------

class _Header extends StatelessWidget {
  final String status;

  const _Header({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;

    switch (status.toLowerCase()) {
      case 'recording':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFF9A3412);
        icon = Icons.mic;
        label = 'Recording';
        break;
      case 'uploading':
        bg = AppColors.surface;
        fg = AppColors.subtext;
        icon = Icons.cloud_upload;
        label = 'Uploading';
        break;
      case 'processing':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFF9A3412);
        icon = Icons.auto_awesome;
        label = 'Analyzing your session';
        break;
      default:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        icon = Icons.check_circle;
        label = 'Ready';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyntraButton extends StatelessWidget {
  final Session session;

  const _SyntraButton({required this.session});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SyntraScreen(
              initialMessage: 'Summarize this session and highlight key tasks.',
              initialSessionId: session.id,
            ),
          ),
        );
      },
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Ask Syntra about this session'),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.subtext),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.subtext,
                    height: 1.25,
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

// ---------- SHARED UI ----------

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _ProcessingText extends StatelessWidget {
  final String text;

  const _ProcessingText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.subtext),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InsightSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('-  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FlashcardView extends StatefulWidget {
  final String question;
  final String answer;
  final bool isSaved;
  final VoidCallback onSave;

  const _FlashcardView({
    required this.question,
    required this.answer,
    required this.isSaved,
    required this.onSave,
  });

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  bool _saved = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.answer,
            style: const TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 10),
          if (_saved)
            const Text(
              'Saved',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_skipped)
            const Text(
              'Skipped',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave();
                      setState(() => _saved = true);
                    },
                    child: const Text('Save Flashcard'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _skipped = true),
                  child: const Text('Skip'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String text;

  const _ActionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String text;

  const _TaskItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.task_alt, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}



