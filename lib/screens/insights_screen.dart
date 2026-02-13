import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/session.dart';
import '../providers/sessions_provider.dart';
import '../providers/flashcard_deck_provider.dart';
import 'concept_detail_screen.dart';
import '../models/unit.dart';
import '../core/utils/session_format.dart';
import '../providers/session_overrides_provider.dart';
import '../models/session_insights.dart';
import '../providers/units_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/content_visibility_provider.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFlashcards = true;
  String _selectedUnitId = 'all';
  final bool _readyOnly = false;
  String _flashcardSort = 'date'; // date | az
  String _conceptSort = 'date'; // date | az

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final hideContent = ref.watch(contentVisibilityProvider);
    final sourceSessions = hideContent ? const <Session>[] : sessions;
    final deck = ref.watch(flashcardDeckProvider);
    final units = ref.watch(unitsProvider);
    final filteredSessions = _applyFilters(sourceSessions);
    final savedIds = deck.map((d) => d.id).toSet();
    final unitLabel = _unitLabel(units, _selectedUnitId);
    final isNewUser = hideContent;

    final hasSessions = filteredSessions.isNotEmpty;
    final cards = _buildFlashcards(filteredSessions);
    final concepts = _buildConcepts(filteredSessions);
    final hasProcessing = filteredSessions
        .any((s) => !s.isReady || s.parsedInsights == null);

    if (_flashcardSort == 'az') {
      cards.sort((a, b) => a.question.toLowerCase().compareTo(
            b.question.toLowerCase(),
          ));
    } else {
      cards.sort((a, b) {
        final da = a.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    }

    if (_conceptSort == 'az') {
      concepts.sort((a, b) =>
          a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    } else {
      concepts.sort((a, b) {
        final da = a.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    }

    final trailingLabel = _showFlashcards
        ? (_flashcardSort == 'az' ? 'A to Z' : 'By Date')
        : (_conceptSort == 'az' ? 'A to Z' : 'By Date');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              _Header(
                onAdd: () => _openAddInsight(context, sessions, units),
              ),
            const SizedBox(height: 24),
            if (isNewUser)
              const _NewUserEmptyState()
            else ...[
              Row(
                children: [
                  _MetricCard(
                    title: 'FLASHCARDS',
                    value: '${cards.length}',
                    active: _showFlashcards,
                    onTap: () => setState(() => _showFlashcards = true),
                  ),
                  const SizedBox(width: 14),
                  _MetricCard(
                    title: 'CONCEPTS',
                    value: '${concepts.length}',
                    active: !_showFlashcards,
                    onTap: () => setState(() => _showFlashcards = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                hintText: _showFlashcards
                    ? 'Search flashcards...'
                    : 'Search concepts...',
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _FilterPill(
                    label: unitLabel,
                    active: _selectedUnitId != 'all',
                    onTap: () => _openUnitFilter(context, units),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Date',
                    active: _showFlashcards
                        ? _flashcardSort == 'date'
                        : _conceptSort == 'date',
                    onTap: () {
                      setState(() {
                        if (_showFlashcards) {
                          _flashcardSort = 'date';
                        } else {
                          _conceptSort = 'date';
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'A to Z',
                    active: _showFlashcards
                        ? _flashcardSort == 'az'
                        : _conceptSort == 'az',
                    onTap: () {
                      setState(() {
                        if (_showFlashcards) {
                          _flashcardSort = 'az';
                        } else {
                          _conceptSort = 'az';
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: _showFlashcards
                    ? 'ACTIVE LEARNING CARDS'
                    : 'VOCABULARY & DEFINITIONS',
                trailing: trailingLabel,
              ),
              const SizedBox(height: 12),
              if (_showFlashcards)
                if (cards.isEmpty)
                  hasSessions && hasProcessing
                      ? const _ProcessingState(
                          label: 'Processing flashcards...',
                        )
                      : const _EmptyState()
                else
                  Column(
                    children: [
                      for (final group in _groupBySession(cards)) ...[
                        _SessionRow(title: group.title),
                        const SizedBox(height: 12),
                        for (final card in group.cards) ...[
                          _FlashcardCard(
                            card: card,
                            isSaved: savedIds.contains(card.id),
                            onSave: () {
                              ref.read(flashcardDeckProvider.notifier).add(
                                    DeckCard(
                                      id: card.id,
                                      sessionId: card.session.id,
                                      question: card.question,
                                      answer: card.answer,
                                      createdAt: card.session.createdAt ??
                                          DateTime.now(),
                                    ),
                                  );
                            },
                            onEdit: () => _openEditFlashcard(context, ref, card),
                            onDelete: () => _deleteFlashcard(ref, card),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 6),
                      ],
                    ],
                  )
              else
                if (concepts.isEmpty)
                  hasSessions && hasProcessing
                      ? const _ProcessingState(
                          label: 'Processing concepts...',
                          icon: Icons.lightbulb_outline,
                        )
                      : const _EmptyState(
                          label: 'No concepts yet.',
                          icon: Icons.lightbulb_outline,
                        )
                else
                  Column(
                    children: [
                      for (final group
                          in _groupConceptsBySession(concepts)) ...[
                        _SessionRow(title: group.title),
                        const SizedBox(height: 10),
                        _ConceptCardList(
                          items: group.items,
                          onTap: (concept) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ConceptDetailScreen(concept: concept),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
            ],
          ],
        ),
      ),
    );
  }

  List<_FlashcardItem> _buildFlashcards(List<Session> sessions) {
    final items = <_FlashcardItem>[];
    for (final s in sessions) {
      final insights = s.parsedInsights;
      if (insights == null) continue;
      for (final f in insights.flashcards) {
        final text = '${f.question}::${f.answer}';
        final id = '${s.id}::${text.hashCode}';
        items.add(
          _FlashcardItem(
            session: s,
            question: f.question,
            answer: f.answer,
            id: id,
          ),
        );
      }
    }
    items.sort((a, b) {
      final da = a.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return items;
  }

  List<_FlashcardGroup> _groupBySession(List<_FlashcardItem> items) {
    final Map<String, List<_FlashcardItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.session.id, () => []).add(item);
    }

    final groups = grouped.values.map((cards) {
      final session = cards.first.session;
      final title = _formatSessionTitle(session);
      return _FlashcardGroup(title: title, cards: cards);
    }).toList();

    groups.sort((a, b) => b.cards.first.session.createdAt
        ?.compareTo(a.cards.first.session.createdAt ?? DateTime(0)) ??
        -1);

    return groups;
  }

  void _openEditFlashcard(
    BuildContext context,
    WidgetRef ref,
    _FlashcardItem card,
  ) {
    final question = TextEditingController(text: card.question);
    final answer = TextEditingController(text: card.answer);
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Edit Flashcard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: question,
              decoration: const InputDecoration(
                labelText: 'Question',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: answer,
              decoration: const InputDecoration(
                labelText: 'Answer',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final q = question.text.trim();
                  final a = answer.text.trim();
                  if (q.isEmpty || a.isEmpty) return;
                  _updateFlashcard(
                    ref,
                    card.session,
                    oldCard: Flashcard(
                      question: card.question,
                      answer: card.answer,
                    ),
                    nextCard: Flashcard(question: q, answer: a),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Save Changes'),
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

  void _deleteFlashcard(WidgetRef ref, _FlashcardItem card) {
    _removeFlashcard(
      ref,
      card.session,
      Flashcard(question: card.question, answer: card.answer),
    );
  }

  void _updateFlashcard(
    WidgetRef ref,
    Session session, {
    required Flashcard oldCard,
    required Flashcard nextCard,
  }) {
    final override = ref.read(sessionOverridesProvider)[session.id];
    final base = session.parsedInsights;
    final current =
        override?.flashcards ?? base?.flashcards ?? const <Flashcard>[];
    final next = [
      for (final f in current)
        if (f.question == oldCard.question && f.answer == oldCard.answer)
          nextCard
        else
          f,
    ];
    ref.read(sessionOverridesProvider.notifier).setInsights(
          sessionId: session.id,
          flashcards: next,
        );
  }

  void _removeFlashcard(
    WidgetRef ref,
    Session session,
    Flashcard target,
  ) {
    final override = ref.read(sessionOverridesProvider)[session.id];
    final base = session.parsedInsights;
    final current =
        override?.flashcards ?? base?.flashcards ?? const <Flashcard>[];
    final next = [
      for (final f in current)
        if (f.question == target.question && f.answer == target.answer)
          null
        else
          f,
    ].whereType<Flashcard>().toList();
    ref.read(sessionOverridesProvider.notifier).setInsights(
          sessionId: session.id,
          flashcards: next,
        );
  }

  String _formatSessionTitle(Session session) {
    return displaySessionTitle(session);
  }

  String? _latestSessionIdForUnit(
    String unitId,
    List<Session> sessions,
  ) {
    final filtered = sessions.where((s) {
      final sid = (s.eventId == null || s.eventId!.isEmpty)
          ? 'general'
          : s.eventId!;
      return sid == unitId;
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    if (filtered.isEmpty) return null;
    return filtered.first.id;
  }

  void _openAddInsight(
    BuildContext context,
    List<Session> sessions,
    List<Unit> units,
  ) {
    if (units.isEmpty) {
      AppModal.show(
        context: context,
        builder: (_) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Insight',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please add a course first, then you can create insights.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(navIndexProvider.notifier).state = 1;
                  },
                  child: const Text('Add Course'),
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
      return;
    }
    final sorted = [...sessions]
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    String type = _showFlashcards ? 'flashcard' : 'concept';
    String selectedUnitId =
        _selectedUnitId != 'all' ? _selectedUnitId : units.first.id;
    String sessionId = _latestSessionIdForUnit(selectedUnitId, sorted) ?? '';
    final question = TextEditingController();
    final answer = TextEditingController();
    final concept = TextEditingController();

    AppModal.show(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Insight',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'flashcard',
                        child: Text('Flashcard'),
                    ),
                    DropdownMenuItem(
                      value: 'concept',
                      child: Text('Concept'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setModalState(() => type = v);
                  },
                    decoration: const InputDecoration(
                      labelText: 'Type',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUnitId,
                    items: [
                      for (final u in units)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text(u.title),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() {
                        selectedUnitId = v;
                        sessionId =
                            _latestSessionIdForUnit(v, sorted) ?? '';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Course',
                    ),
                  ),
                  if (sessionId.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Add a recording to this course before creating insights.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (type == 'flashcard') ...[
                    TextField(
                      controller: question,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: answer,
                    decoration: const InputDecoration(
                      labelText: 'Answer',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: concept,
                    decoration: const InputDecoration(
                      labelText: 'Concept',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (sessionId.isEmpty) return;
                      final s = sorted.firstWhere((x) => x.id == sessionId);
                      final override =
                          ref.read(sessionOverridesProvider)[sessionId];
                      final base = s.parsedInsights;

                      if (type == 'flashcard') {
                        final q = question.text.trim();
                        final a = answer.text.trim();
                        if (q.isEmpty || a.isEmpty) return;
                        final current =
                            override?.flashcards ?? base?.flashcards ?? const [];
                        final next = [
                          ...current,
                          Flashcard(question: q, answer: a),
                        ];
                        ref
                            .read(sessionOverridesProvider.notifier)
                            .setInsights(sessionId: sessionId, flashcards: next);
                      } else {
                        final c = concept.text.trim();
                        if (c.isEmpty) return;
                        final current =
                            override?.keyConcepts ?? base?.keyConcepts ?? const [];
                        final next = [...current, c];
                        ref
                            .read(sessionOverridesProvider.notifier)
                            .setInsights(sessionId: sessionId, keyConcepts: next);
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Add'),
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
      },
    );
  }

  String _unitLabel(List<Unit> units, String unitId) {
    if (unitId == 'all') return 'All Courses';
    final match = units.firstWhere(
      (u) => u.id == unitId,
      orElse: () =>
          Unit(id: 'general', title: 'Unassigned', createdAt: DateTime(0)),
    );
    return match.title;
  }

  void _openUnitFilter(BuildContext context, List<Unit> units) {
    final options = [
      const _UnitFilterOption(id: 'all', label: 'All Courses'),
      for (final u in units) _UnitFilterOption(id: u.id, label: u.title),
    ];
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter by Course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final opt in options)
              GestureDetector(
                onTap: () {
                  setState(() => _selectedUnitId = opt.id);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedUnitId == opt.id
                        ? AppColors.primarySoft
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedUnitId == opt.id
                          ? AppColors.primary
                          : AppColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_selectedUnitId == opt.id)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Session> _applyFilters(List<Session> sessions) {
    return sessions.where((s) {
      if (_readyOnly && !s.isReady) return false;
      if (_selectedUnitId == 'all') return true;

      final unitId =
          (s.eventId == null || s.eventId!.isEmpty) ? 'general' : s.eventId!;
      return unitId == _selectedUnitId;
    }).toList();
  }

  List<_ConceptItem> _buildConcepts(List<Session> sessions) {
    final items = <_ConceptItem>[];
    for (final s in sessions) {
      final insights = s.parsedInsights;
      if (insights == null) continue;
      for (final c in insights.keyConcepts) {
        if (c.trim().isEmpty) continue;
        items.add(
          _ConceptItem(
            session: s,
            text: c.trim(),
          ),
        );
      }
    }
    items.sort((a, b) {
      final da = a.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return items;
  }

  List<_ConceptGroup> _groupConceptsBySession(List<_ConceptItem> items) {
    final Map<String, List<_ConceptItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.session.id, () => []).add(item);
    }

    final groups = grouped.values.map((items) {
      final session = items.first.session;
      final title = _formatSessionTitle(session);
      return _ConceptGroup(title: title, items: items);
    }).toList();

    groups.sort((a, b) => b.items.first.session.createdAt
        ?.compareTo(a.items.first.session.createdAt ?? DateTime(0)) ??
        -1);

    return groups;
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAdd;

  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intelligence',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 6),
              Text(
                'Aggregated Knowledge',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtext,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.text,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final bool active;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConcepts = title.toLowerCase().contains('concept');
    final bg = active
        ? (isConcepts ? AppColors.text : AppColors.primary)
        : Colors.white;
    final fg = active ? Colors.white : AppColors.text;
    final border =
        active ? Colors.transparent : AppColors.line;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: fg.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.manrope(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ),
    );
  }
}

class _UnitFilterOption {
  final String id;
  final String label;

  const _UnitFilterOption({
    required this.id,
    required this.label,
  });
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
              color: active ? AppColors.primary : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionHeader({
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.swap_vert, size: 14, color: AppColors.subtext),
            const SizedBox(width: 6),
            Text(
              trailing,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.subtext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final String title;

  const _SessionRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 8, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.muted),
      ],
    );
  }
}

class _FlashcardCard extends StatefulWidget {
  final _FlashcardItem card;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlashcardCard({
    required this.card,
    required this.isSaved,
    required this.onSave,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<_FlashcardCard> {
  bool _showAnswer = false;
  bool _saved = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    final text = _showAnswer ? widget.card.answer : widget.card.question;
    final bg = _showAnswer ? AppColors.text : Colors.white;
    final fg = _showAnswer ? Colors.white : AppColors.text;
    final sub = _showAnswer ? Colors.white70 : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => setState(() => _showAnswer = !_showAnswer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showAnswer ? 'REVEALED' : 'FLASHCARD',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _showAnswer ? AppColors.primary : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Text(
                text,
                key: ValueKey(text),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: _showAnswer ? Colors.white12 : const Color(0xFFF3F4F6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _showAnswer ? 'Tap to see question' : 'Tap to flip',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (_showAnswer) ...[
              const SizedBox(height: 14),
              if (_saved)
                Text(
                  'Saved',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                )
              else if (_skipped)
                Row(
                  children: [
                    Text(
                      'Skipped',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => setState(() => _skipped = false),
                      child: const Text('Undo'),
                    ),
                  ],
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Save Flashcard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          widget.onDelete();
                          setState(() => _skipped = true);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor:
                              _showAnswer ? Colors.white : AppColors.subtext,
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              _showAnswer ? Colors.white : AppColors.text,
                          side: BorderSide(
                            color: _showAnswer ? Colors.white24 : AppColors.line,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Remove',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ).merge(
                          OutlinedButton.styleFrom(
                            foregroundColor:
                                _showAnswer ? Colors.white : AppColors.text,
                            side: BorderSide(
                              color:
                                  _showAnswer ? Colors.white24 : AppColors.line,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    this.label = 'No flashcards yet.',
    this.icon = Icons.auto_awesome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardItem {
  final Session session;
  final String question;
  final String answer;
  final String id;

  const _FlashcardItem({
    required this.session,
    required this.question,
    required this.answer,
    required this.id,
  });
}

class _FlashcardGroup {
  final String title;
  final List<_FlashcardItem> cards;

  const _FlashcardGroup({
    required this.title,
    required this.cards,
  });
}

class _ConceptItem {
  final Session session;
  final String text;

  const _ConceptItem({
    required this.session,
    required this.text,
  });
}

class _ConceptGroup {
  final String title;
  final List<_ConceptItem> items;

  const _ConceptGroup({
    required this.title,
    required this.items,
  });
}

class _ConceptCardList extends StatelessWidget {
  final List<_ConceptItem> items;
  final ValueChanged<String> onTap;

  const _ConceptCardList({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => onTap(item.text),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _conceptSubtitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProcessingState extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ProcessingState({
    this.label = 'Processing insights...',
    this.icon = Icons.hourglass_top,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewUserEmptyState extends StatelessWidget {
  const _NewUserEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 28, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'No insights yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record your first session to generate summaries, flashcards, and key concepts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subtext,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _conceptSubtitle(_ConceptItem item) {
  final summary = item.session.parsedInsights?.summary;
  if (summary != null && summary.trim().isNotEmpty) {
    return summary.trim();
  }
  return 'Tap to open the full concept details.';
}

