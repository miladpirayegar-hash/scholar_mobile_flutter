// lib/screens/unit_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessions_provider.dart';
import '../providers/units_provider.dart';
import '../models/session.dart';
import 'session_detail_screen.dart';
import '../core/utils/session_format.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/unit_notes_ai_provider.dart';
import '../providers/unit_notes_pins_provider.dart';
import '../providers/outline_pending_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../services/api/api_providers.dart';
import 'outline_upload_flow.dart';
import 'recording_screen.dart';
import '../providers/course_files_provider.dart';
import '../providers/nav_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UnitDetailScreen extends ConsumerStatefulWidget {
  final String unitTitle;
  final String unitId;
  final int initialTabIndex;

  const UnitDetailScreen({
    super.key,
    required this.unitTitle,
    required this.unitId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  final TextEditingController _search = TextEditingController();
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    final start = widget.initialTabIndex;
    _tabIndex = (start < 0 || start > 3) ? 0 : start;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Session> all = ref.watch(sessionsProvider);
    ref.watch(unitsProvider);
    final hideContent = ref.watch(contentVisibilityProvider);
    final pending = ref.watch(outlinePendingProvider)[widget.unitId];
    final pendingCount = hideContent
        ? 0
        : (pending?.exams.length ?? 0) + (pending?.assignments.length ?? 0);

    final q = _search.text.trim().toLowerCase();

    final List<Session> sessions = all.where((s) {
      final sid = (s.eventId == null || s.eventId!.isEmpty) ? 'general' : s.eventId!;
      if (sid != widget.unitId) return false;
      if (q.isEmpty) return true;
      return displaySessionTitle(s).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    final List<Session> visibleSessions =
        hideContent ? const <Session>[] : sessions;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.unitTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                '${visibleSessions.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.subtext,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Course Brief',
                    active: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'Milestones',
                    active: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                    badgeCount: pendingCount,
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'Sessions',
                    active: _tabIndex == 2,
                    onTap: () => setState(() => _tabIndex = 2),
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'Syntra',
                    active: _tabIndex == 3,
                    onTap: () => setState(() => _tabIndex = 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _tabIndex == 3
                  ? _UnitSyntraTab(
                      unitId: widget.unitId,
                      sessions: visibleSessions,
                    )
                  : _tabIndex == 2
                      ? _CapturesTab(sessions: visibleSessions)
                      : _tabIndex == 1
                          ? _MilestonesTab(
                              unitId: widget.unitId,
                              sessions: visibleSessions,
                            )
                          : _CourseBriefTab(
                              unitId: widget.unitId,
                              sessions: visibleSessions,
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _UnitDetailBottomNav(),
    );
  }
}

class _UnitDetailBottomNav extends ConsumerWidget {
  const _UnitDetailBottomNav();

  void _goTo(WidgetRef ref, BuildContext context, int index) {
    ref.read(navIndexProvider.notifier).state = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _NavItemLite(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'EXPLORE',
                active: index == 0,
                onTap: () => _goTo(ref, context, 0),
              ),
            ),
            Expanded(
              child: _NavItemLite(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'NOTEBOOK',
                active: index == 1,
                onTap: () => _goTo(ref, context, 1),
              ),
            ),
            Expanded(
              child: _NavItemLite(
                icon: Icons.check_box_outlined,
                activeIcon: Icons.check_box,
                label: 'TASKS',
                active: index == 2,
                onTap: () => _goTo(ref, context, 2),
              ),
            ),
            Expanded(
              child: _NavItemLite(
                icon: Icons.lightbulb_outline,
                activeIcon: Icons.lightbulb,
                label: 'INSIGHTS',
                active: index == 3,
                onTap: () => _goTo(ref, context, 3),
              ),
            ),
            Expanded(
              child: _NavItemLite(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                label: 'SYNTRA',
                active: index == 4,
                onTap: () => _goTo(ref, context, 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemLite extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItemLite({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.text,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: active ? 28 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBriefTab extends ConsumerWidget {
  final String unitId;
  final List<Session> sessions;

  const _CourseBriefTab({
    required this.unitId,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(unitNotesProvider)[unitId] ?? const UnitNotes();
    final dismissed =
        ref.watch(unitNotesAiProvider)[unitId] ?? const <String>{};
    final pins = ref.watch(unitNotesPinsProvider)[unitId] ?? const UnitNotesPins();
    final materials =
        ref.watch(courseFilesProvider)[unitId] ?? const <CourseFile>[];
    final ai = _collectAiSuggestions(sessions)
        .where((s) => s.type == _AiSuggestionType.highlight)
        .where((s) => !_isDismissed(dismissed, s))
        .where((s) => !notes.highlights.contains(s.text))
        .toList();
    final highlights = [...notes.highlights]
      ..sort((a, b) {
        final ap = pins.highlights.contains(a);
        final bp = pins.highlights.contains(b);
        if (ap != bp) return bp ? 1 : -1;
        return a.compareTo(b);
      });
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject Highlights',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: () => showOutlineUploadFlow(
                      context,
                      ref,
                      unitId: unitId,
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Upload Outline'),
                  ),
                  TextButton(
                    onPressed: () => _pickCourseFile(
                      context: context,
                      ref: ref,
                      unitId: unitId,
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Upload File'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CourseMaterialsSection(
          items: materials,
          onAdd: () => _pickCourseFile(
            context: context,
            ref: ref,
            unitId: unitId,
          ),
          onRemove: (id) => _confirmRemoveCourseFile(
            context: context,
            ref: ref,
            unitId: unitId,
            fileId: id,
          ),
          unitId: unitId,
        ),
        const SizedBox(height: 16),
        if (ai.isNotEmpty) ...[
          _AiSuggestionSection(
            title: 'AI Suggestions',
            items: ai,
            onApprove: (s) {
              ref
                  .read(unitNotesProvider.notifier)
                  .addHighlight(unitId, s.text);
              ref
                  .read(unitNotesAiProvider.notifier)
                  .dismiss(unitId, _suggestionKey(s));
            },
            onDismiss: (s) => ref
                .read(unitNotesAiProvider.notifier)
                .dismiss(unitId, _suggestionKey(s)),
          ),
          const SizedBox(height: 12),
        ],
        if (notes.highlights.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Session a subject-level insight...',
                    style: TextStyle(color: AppColors.subtext),
                  ),
                ),
                GestureDetector(
                  onTap: () => _addHighlight(context, ref),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < highlights.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => ref
                            .read(unitNotesPinsProvider.notifier)
                            .toggleHighlight(unitId, highlights[i]),
                        icon: Icon(
                          pins.highlights.contains(highlights[i])
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: AppColors.subtext,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editHighlight(
                          context,
                          ref,
                          unitId,
                          highlights[i],
                        ),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.muted),
                      ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showGeneratedItemModal(
                              context: context,
                              title: 'Highlight',
                              text: highlights[i],
                              onApprove: () {},
                              onDecline: () => _confirmRemoveHighlight(
                                context,
                                ref,
                                unitId,
                                highlights[i],
                              ),
                            ),
                            child: Text(
                              highlights[i],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => _confirmRemoveHighlight(
                          context,
                          ref,
                          unitId,
                          highlights[i],
                        ),
                        icon: const Icon(Icons.close, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: () => _addHighlight(context, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Center(
                    child: Text(
                      '+   Add Highlight',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addHighlight(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Highlight',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your subject highlights...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(unitNotesProvider.notifier)
                      .addHighlight(unitId, controller.text);
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
}

void _editHighlight(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  String current,
) {
  final controller = TextEditingController(text: current);
  AppModal.show(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Edit Highlight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Update highlight...',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref
                    .read(unitNotesProvider.notifier)
                    .updateHighlightByValue(
                      unitId,
                      current,
                      controller.text,
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

Future<void> _confirmRemoveHighlight(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  String highlight,
) async {
  await showDeleteConfirm(
    context: context,
    title: 'Remove highlight?',
    message: 'This will remove the highlight from this course.',
    onConfirm: () {
      ref
          .read(unitNotesProvider.notifier)
          .removeHighlightByValue(unitId, highlight);
    },
  );
}

Future<void> _confirmRemoveMilestone(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  DatedItem item, {
  required bool isExam,
}) async {
  final label = isExam ? 'exam' : 'assignment';
  await showDeleteConfirm(
    context: context,
    title: 'Remove $label?',
    message: 'This will remove the $label from this course.',
    onConfirm: () {
      if (isExam) {
        ref
            .read(unitNotesProvider.notifier)
            .removeExamByValue(unitId, item);
      } else {
        ref
            .read(unitNotesProvider.notifier)
            .removeAssignmentByValue(unitId, item);
      }
    },
  );
}

class _MilestonesTab extends ConsumerWidget {
  final String unitId;
  final List<Session> sessions;

  const _MilestonesTab({
    required this.unitId,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(unitNotesProvider)[unitId] ?? const UnitNotes();
    final dismissed =
        ref.watch(unitNotesAiProvider)[unitId] ?? const <String>{};
    final pins = ref.watch(unitNotesPinsProvider)[unitId] ?? const UnitNotesPins();
    final pending =
        ref.watch(outlinePendingProvider)[unitId] ?? const OutlinePending();
    final pendingItems = <_PendingMilestoneItem>[
      for (final e in pending.exams)
        _PendingMilestoneItem(item: e, isExam: true),
      for (final a in pending.assignments)
        _PendingMilestoneItem(item: a, isExam: false),
    ];
    final ai = _collectAiSuggestions(sessions);
    final examSuggestions = ai
        .where((s) => s.type == _AiSuggestionType.exam)
        .where((s) => !_isDismissed(dismissed, s))
        .where((s) => !_containsDated(notes.exams, s))
        .toList();
    final assignmentSuggestions = ai
        .where((s) => s.type == _AiSuggestionType.assignment)
        .where((s) => !_isDismissed(dismissed, s))
        .where((s) => !_containsDated(notes.assignments, s))
        .toList();
    final exams = _sortDated(notes.exams, pins.exams);
    final assignments = _sortDated(notes.assignments, pins.assignments);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        if (pendingItems.isNotEmpty) ...[
          _PendingMilestoneSection(
            items: pendingItems,
            onApprove: (item) {
                if (item.isExam) {
                  ref
                      .read(unitNotesProvider.notifier)
                      .addExamWithDate(
                        unitId,
                        item.item.text,
                        item.item.date,
                        note: item.item.notes,
                        priority: item.item.priority,
                      );
                ref.read(outlinePendingProvider.notifier).removePendingExam(
                      unitId,
                      item.item,
                    );
                } else {
                  ref
                      .read(unitNotesProvider.notifier)
                      .addAssignmentWithDate(
                        unitId,
                        item.item.text,
                        item.item.date,
                        note: item.item.notes,
                        priority: item.item.priority,
                      );
                ref
                    .read(outlinePendingProvider.notifier)
                    .removePendingAssignment(
                      unitId,
                      item.item,
                    );
              }
              ref
                  .read(contentVisibilityProvider.notifier)
                  .markContentStarted();
            },
            onDecline: (item) {
              if (item.isExam) {
                ref.read(outlinePendingProvider.notifier).removePendingExam(
                      unitId,
                      item.item,
                    );
              } else {
                ref
                    .read(outlinePendingProvider.notifier)
                    .removePendingAssignment(
                      unitId,
                      item.item,
                    );
              }
            },
            onEdit: (item) => _editPendingDatedItem(
              context,
              ref,
              unitId,
              item.item,
              isExam: item.isExam,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (examSuggestions.isNotEmpty) ...[
            _AiSuggestionSection(
              title: 'AI Suggested Exams',
              items: examSuggestions,
              onApprove: (s) {
                ref
                    .read(unitNotesProvider.notifier)
                    .addExamWithDate(unitId, s.text, s.date);
                ref
                    .read(unitNotesAiProvider.notifier)
                    .dismiss(unitId, _suggestionKey(s));
                ref
                    .read(contentVisibilityProvider.notifier)
                    .markContentStarted();
              },
              onDismiss: (s) => ref
                  .read(unitNotesAiProvider.notifier)
                  .dismiss(unitId, _suggestionKey(s)),
            ),
            const SizedBox(height: 18),
          ],
        _MilestoneSection(
          title: 'Upcoming Exams',
          emptyText: 'NO EXAMS SCHEDULED',
          items: exams,
          onAdd: () => _addItem(context, ref, 'Add Exam'),
          emptyCtaLabel: 'Add Exam',
          onEmptyTap: () => _addItem(context, ref, 'Add Exam'),
          onRemove: (item) => _confirmRemoveMilestone(
            context,
            ref,
            unitId,
            item,
            isExam: true,
          ),
          onPin: (item) => ref
                .read(unitNotesPinsProvider.notifier)
              .toggleExam(unitId, item),
          onEdit: (item) => _editDatedItem(
            context,
            ref,
            unitId,
            item,
            isExam: true,
          ),
          isPinned: (item) =>
              pins.exams.contains(UnitNotesPinsController.datedKey(item)),
        ),
        const SizedBox(height: 18),
          if (assignmentSuggestions.isNotEmpty) ...[
            _AiSuggestionSection(
              title: 'AI Suggested Assignments',
              items: assignmentSuggestions,
              onApprove: (s) {
                ref
                    .read(unitNotesProvider.notifier)
                    .addAssignmentWithDate(unitId, s.text, s.date);
                ref
                    .read(unitNotesAiProvider.notifier)
                    .dismiss(unitId, _suggestionKey(s));
                ref
                    .read(contentVisibilityProvider.notifier)
                    .markContentStarted();
              },
              onDismiss: (s) => ref
                  .read(unitNotesAiProvider.notifier)
                  .dismiss(unitId, _suggestionKey(s)),
            ),
            const SizedBox(height: 18),
          ],
        _MilestoneSection(
          title: 'Assignments',
          emptyText: 'COURSEWORK CLEAR',
          items: assignments,
          onAdd: () => _addItem(context, ref, 'Add Assignment'),
          emptyCtaLabel: 'Add Assignment',
          onEmptyTap: () => _addItem(context, ref, 'Add Assignment'),
          onRemove: (item) => _confirmRemoveMilestone(
            context,
            ref,
            unitId,
            item,
            isExam: false,
          ),
          onPin: (item) => ref
              .read(unitNotesPinsProvider.notifier)
              .toggleAssignment(unitId, item),
          onEdit: (item) => _editDatedItem(
            context,
            ref,
            unitId,
            item,
            isExam: false,
          ),
          isPinned: (item) => pins.assignments
              .contains(UnitNotesPinsController.datedKey(item)),
        ),
        ],
      ),
    );
  }

  void _addItem(BuildContext context, WidgetRef ref, String title) {
    final controller = TextEditingController();
    DateTime? selectedDate;
    String selectedPriority = _priorityForDate(selectedDate);
    final notes = TextEditingController();
    AppModal.show(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Description...',
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                      builder: (context, child) {
                        return Theme(
                          data: AppTheme.datePickerTheme(context),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate == null
                                ? 'mm/dd/yyyy'
                                : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
                            style: const TextStyle(color: AppColors.subtext),
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PriorityPicker(
                  value: selectedPriority,
                  onChanged: (v) =>
                      setModalState(() => selectedPriority = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (title == 'Add Exam') {
                        ref
                            .read(unitNotesProvider.notifier)
                            .addExamWithDate(
                              unitId,
                              controller.text,
                              selectedDate,
                              note: notes.text.trim().isEmpty
                                  ? null
                                  : notes.text.trim(),
                              priority: selectedPriority,
                            );
                      } else {
                        ref
                            .read(unitNotesProvider.notifier)
                            .addAssignmentWithDate(
                              unitId,
                              controller.text,
                              selectedDate,
                              note: notes.text.trim().isEmpty
                                  ? null
                                  : notes.text.trim(),
                              priority: selectedPriority,
                            );
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save Item'),
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
}

class _PendingMilestoneItem {
  final DatedItem item;
  final bool isExam;

  const _PendingMilestoneItem({
    required this.item,
    required this.isExam,
  });
}

class _PendingMilestoneSection extends StatelessWidget {
  final List<_PendingMilestoneItem> items;
  final ValueChanged<_PendingMilestoneItem> onApprove;
  final ValueChanged<_PendingMilestoneItem> onDecline;
  final ValueChanged<_PendingMilestoneItem> onEdit;

  const _PendingMilestoneSection({
    required this.items,
    required this.onApprove,
    required this.onDecline,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Needs Approval',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.isExam
                              ? 'EXAM - ${item.item.text}'
                              : 'ASSIGNMENT - ${item.item.text}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                          Text(
                            _formatMilestoneDate(item.item.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.subtext,
                            ),
                          ),
                          if (item.item.notes != null &&
                              item.item.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.item.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subtext,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  IconButton(
                    onPressed: () => onEdit(item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  TextButton(
                    onPressed: () => onApprove(item),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onDecline(item),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontSize: 11),
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

void _editDatedItem(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  DatedItem current,
  {required bool isExam}
  ) {
    final controller = TextEditingController(text: current.text);
    DateTime? selectedDate = current.date;
    final notes = TextEditingController(text: current.notes ?? '');
    String selectedPriority =
        current.priority ?? _priorityForDate(selectedDate);
  AppModal.show(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isExam ? 'Edit Exam' : 'Edit Assignment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Description...',
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                    builder: (context, child) {
                      return Theme(
                        data: AppTheme.datePickerTheme(context),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'mm/dd/yyyy'
                              : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
                          style: const TextStyle(color: AppColors.subtext),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PriorityPicker(
                value: selectedPriority,
                onChanged: (v) =>
                    setModalState(() => selectedPriority = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final updated = DatedItem(
                      text: controller.text.trim(),
                      date: selectedDate,
                      notes: notes.text.trim().isEmpty
                          ? null
                          : notes.text.trim(),
                      priority: selectedPriority,
                    );
                    if (isExam) {
                      ref
                          .read(unitNotesProvider.notifier)
                          .updateExamByValue(unitId, current, updated);
                    } else {
                      ref
                          .read(unitNotesProvider.notifier)
                          .updateAssignmentByValue(unitId, current, updated);
                    }
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
    },
  );
}

void _editPendingDatedItem(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  DatedItem current,
  {required bool isExam}
  ) {
    final controller = TextEditingController(text: current.text);
    DateTime? selectedDate = current.date;
    final notes = TextEditingController(text: current.notes ?? '');
    String selectedPriority =
        current.priority ?? _priorityForDate(selectedDate);
  AppModal.show(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isExam ? 'Edit Exam' : 'Edit Assignment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Description...',
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                    builder: (context, child) {
                      return Theme(
                        data: AppTheme.datePickerTheme(context),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'mm/dd/yyyy'
                              : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
                          style: const TextStyle(color: AppColors.subtext),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PriorityPicker(
                value: selectedPriority,
                onChanged: (v) =>
                    setModalState(() => selectedPriority = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final updated = DatedItem(
                      text: controller.text.trim(),
                      date: selectedDate,
                      notes: notes.text.trim().isEmpty
                          ? null
                          : notes.text.trim(),
                      priority: selectedPriority,
                    );
                    final pending = ref.read(outlinePendingProvider.notifier);
                    if (isExam) {
                      pending.updatePendingExam(unitId, current, updated);
                    } else {
                      pending.updatePendingAssignment(unitId, current, updated);
                    }
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
    },
  );
}

String _formatMilestoneDate(DateTime? date) {
  if (date == null) return 'Missing date';
  return '${date.month}/${date.day}/${date.year}';
}

void _showGeneratedItemModal({
  required BuildContext context,
  required String title,
  required String text,
  DateTime? date,
  String? notes,
  bool showActions = true,
  required VoidCallback onApprove,
  required VoidCallback onDecline,
}) {
  final maxHeight = MediaQuery.of(context).size.height * 0.42;
  AppModal.show(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: 140, maxHeight: maxHeight),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ),
            ),
            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  notes,
                  style: const TextStyle(
                    height: 1.4,
                    color: AppColors.subtext,
                  ),
                ),
              ),
            ],
            if (date != null) ...[
              const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${date.month}/${date.day}/${date.year}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      onDecline();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Decline'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onApprove();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

String _suggestionTitle(_AiSuggestion s) {
  switch (s.type) {
    case _AiSuggestionType.exam:
      return 'Exam Suggestion';
    case _AiSuggestionType.assignment:
      return 'Assignment Suggestion';
    case _AiSuggestionType.highlight:
      return 'Highlight Suggestion';
  }
}

class _MilestoneSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<DatedItem> items;
  final VoidCallback onAdd;
  final String? emptyCtaLabel;
  final VoidCallback? onEmptyTap;
  final ValueChanged<DatedItem> onRemove;
  final ValueChanged<DatedItem> onPin;
  final ValueChanged<DatedItem> onEdit;
  final bool Function(DatedItem) isPinned;

  const _MilestoneSection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.onAdd,
    this.emptyCtaLabel,
    this.onEmptyTap,
    required this.onRemove,
    required this.onPin,
    required this.onEdit,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(Icons.add, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Text(
                      emptyText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.subtext,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (emptyCtaLabel != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onEmptyTap,
                          child: Text(emptyCtaLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              )
          else
            Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => onPin(items[i]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            isPinned(items[i])
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 18,
                            color: AppColors.subtext,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onEdit(items[i]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.muted),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onEdit(items[i]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i].text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (items[i].date != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${items[i].date!.month}/${items[i].date!.day}/${items[i].date!.year}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.subtext,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (items[i].notes != null &&
                                    items[i].notes!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    items[i].notes!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.subtext,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onRemove(items[i]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _AiSuggestionType { highlight, exam, assignment }

class _AiSuggestion {
  final _AiSuggestionType type;
  final String text;
  final DateTime? date;

  const _AiSuggestion({
    required this.type,
    required this.text,
    this.date,
  });
}

List<_AiSuggestion> _collectAiSuggestions(List<Session> sessions) {
  final suggestions = <_AiSuggestion>[];
  for (final s in sessions) {
    final insights = s.insights;
    if (insights == null || insights.isEmpty) continue;
    suggestions.addAll(
      _parseSuggestionList(
        insights['highlights'] ?? insights['subjectHighlights'],
        _AiSuggestionType.highlight,
      ),
    );
    suggestions.addAll(
      _parseSuggestionList(
        insights['exams'] ?? insights['upcomingExams'],
        _AiSuggestionType.exam,
      ),
    );
    suggestions.addAll(
      _parseSuggestionList(
        insights['assignments'],
        _AiSuggestionType.assignment,
      ),
    );
    suggestions.addAll(
      _parseTextForDatedItems(
        _collectInsightText(insights),
      ),
    );
  }
  final seen = <String>{};
  final unique = <_AiSuggestion>[];
  for (final s in suggestions) {
    final key = _suggestionKey(s);
    if (seen.add(key)) unique.add(s);
  }
  return unique;
}

String _collectInsightText(Map<String, dynamic> insights) {
  final buffer = StringBuffer();
  final summary = insights['summary'];
  if (summary is String) buffer.write('$summary ');
  final actionItems = insights['actionItems'];
  if (actionItems is List) {
    for (final a in actionItems) {
      if (a is String) buffer.write('$a ');
      if (a is Map<String, dynamic> && a['text'] is String) {
        buffer.write('${a['text']} ');
      }
    }
  }
  return buffer.toString();
}

List<_AiSuggestion> _parseTextForDatedItems(String text) {
  if (text.trim().isEmpty) return const [];
  final lower = text.toLowerCase();
  final isExam = lower.contains('exam') || lower.contains('midterm');
  final isAssignment =
      lower.contains('assignment') || lower.contains('homework') || lower.contains('due');

  final dates = _extractDates(text);
  if (dates.isEmpty) return const [];

  final items = <_AiSuggestion>[];
  for (final d in dates) {
    if (isExam) {
      items.add(
        _AiSuggestion(
          type: _AiSuggestionType.exam,
          text: 'Exam',
          date: d,
        ),
      );
    }
    if (isAssignment) {
      items.add(
        _AiSuggestion(
          type: _AiSuggestionType.assignment,
          text: 'Assignment due',
          date: d,
        ),
      );
    }
  }
  return items;
}

List<DateTime> _extractDates(String text) {
  final matches = RegExp(r'(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?')
      .allMatches(text);
  final dates = <DateTime>[];
  for (final m in matches) {
    final month = int.tryParse(m.group(1) ?? '');
    final day = int.tryParse(m.group(2) ?? '');
    var year = int.tryParse(m.group(3) ?? '');
    if (month == null || day == null) continue;
    if (year == null) {
      year = DateTime.now().year;
    } else if (year < 100) {
      year += 2000;
    }
    final dt = DateTime.tryParse('$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
    if (dt != null) dates.add(dt);
  }
  return dates;
}

List<_AiSuggestion> _parseSuggestionList(
  dynamic value,
  _AiSuggestionType type,
) {
  if (value is! List) return const [];
  return value
      .map((e) {
        if (e is String) {
          return _AiSuggestion(type: type, text: e.trim());
        }
        if (e is Map<String, dynamic>) {
          final rawText = e['text'] ?? e['title'] ?? e['name'];
          final rawDate = e['date'] ?? e['dueDate'];
          return _AiSuggestion(
            type: type,
            text: (rawText ?? '').toString().trim(),
            date: _parseDate(rawDate),
          );
        }
        return null;
      })
      .whereType<_AiSuggestion>()
      .where((s) => s.text.isNotEmpty)
      .toList();
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _suggestionKey(_AiSuggestion s) =>
    '${s.type.name}::${s.text}::${s.date?.toIso8601String() ?? ''}';

bool _isDismissed(Set<String> dismissed, _AiSuggestion s) =>
    dismissed.contains(_suggestionKey(s));

bool _containsDated(List<DatedItem> items, _AiSuggestion s) {
  return items.any((e) => e.text == s.text && e.date == s.date);
}

List<DatedItem> _sortDated(List<DatedItem> items, Set<String> pinnedKeys) {
  final list = [...items];
  list.sort((a, b) {
    final ap = pinnedKeys.contains(UnitNotesPinsController.datedKey(a));
    final bp = pinnedKeys.contains(UnitNotesPinsController.datedKey(b));
    if (ap != bp) return bp ? 1 : -1;
    final da = a.date ?? DateTime(2100);
    final db = b.date ?? DateTime(2100);
    return da.compareTo(db);
  });
  return list;
}

class _AiSuggestionSection extends StatelessWidget {
  final String title;
  final List<_AiSuggestion> items;
  final ValueChanged<_AiSuggestion> onApprove;
  final ValueChanged<_AiSuggestion> onDismiss;

  const _AiSuggestionSection({
    required this.title,
    required this.items,
    required this.onApprove,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          for (final s in items)
            GestureDetector(
              onTap: () => _showGeneratedItemModal(
                context: context,
                title: _suggestionTitle(s),
                text: s.text,
                date: s.date,
                onApprove: () => onApprove(s),
                onDecline: () => onDismiss(s),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => onApprove(s),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDismiss(s),
                      icon: const Icon(
                        Icons.not_interested,
                        color: AppColors.muted,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (s.date != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${s.date!.month}/${s.date!.day}/${s.date!.year}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.subtext,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CapturesTab extends StatelessWidget {
  final List<Session> sessions;

  const _CapturesTab({required this.sessions});

  @override
    Widget build(BuildContext context) {
      if (sessions.isEmpty) {
        return Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No sessions yet.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.subtext,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start recording in this course to see sessions here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecordingScreen(),
                        ),
                      );
                    },
                    child: const Text('Start recording'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionRow(session: session);
      },
    );
  }
}

class _UnitSyntraTab extends ConsumerStatefulWidget {
  final String unitId;
  final List<Session> sessions;

  const _UnitSyntraTab({
    required this.unitId,
    required this.sessions,
  });

  @override
  ConsumerState<_UnitSyntraTab> createState() => _UnitSyntraTabState();
}

class _UnitSyntraTabState extends ConsumerState<_UnitSyntraTab> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatItem> _messages = [];
  bool _useSessionsContext = false;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset + 12),
      children: [
        const Text(
          'Ask Syntra',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (_messages.isEmpty)
          const Text(
            'Summarize this unit or ask questions about your materials.',
            style: TextStyle(color: AppColors.subtext),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Include session transcripts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtext,
                ),
              ),
            ),
            Switch(
              value: _useSessionsContext,
              onChanged: (v) => setState(() => _useSessionsContext = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primarySoft,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final m = _messages[i];
            return Align(
              alignment:
                  m.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: m.isUser ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  m.text,
                  style: TextStyle(
                    color: m.isUser ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask Syntra...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _messages.add(_ChatItem(text: text, isUser: true));
      _messages.add(_ChatItem(text: 'Typing...', isUser: false));
    });
    _controller.clear();

    if (_isGreetingMessage(text)) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(
          _ChatItem(text: _greetingReply(), isUser: false),
        );
        _sending = false;
      });
      return;
    }

    final List<String> sessionIds = _useSessionsContext
        ? widget.sessions.map((s) => s.id).toList(growable: false)
        : const <String>[];
      final unitNotes =
          ref.read(unitNotesProvider)[widget.unitId] ?? const UnitNotes();
      final pending =
          ref.read(outlinePendingProvider)[widget.unitId] ?? const OutlinePending();
      final materials =
          ref.read(courseFilesProvider)[widget.unitId] ?? const <CourseFile>[];
      final context =
          await _buildCourseContext(unitNotes, pending, materials);
      try {
        final api = ref.read(apiServiceProvider);
        final reply = await api.syntraChat(
          message: _composeSyntraMessage(text, context),
          sessionIds: sessionIds,
        );
        if (!mounted) return;
        setState(() {
          _messages.removeLast();
          _messages.add(
            _ChatItem(
              text: reply.trim().isEmpty ? _greetingReply() : reply,
              isUser: false,
            ),
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _messages.removeLast();
          _messages.add(
            const _ChatItem(
              text: 'Sorry, something went wrong. Please try again.',
              isUser: false,
            ),
          );
        });
      } finally {
        if (mounted) {
          setState(() => _sending = false);
        }
      }
    }
  }

  String _composeSyntraMessage(String userMessage, String context) {
    const policy =
        'You are Syntra, an academic assistant. Focus on coursework, studying, exams, assignments, and the provided academic context. If the question is not academic or not related to the provided context, respond briefly and steer the user toward what you can help with (course materials, exams, assignments, study planning).';
    if (context.trim().isEmpty) {
      return '''
$policy

User question:
$userMessage
'''.trim();
    }
    return '''
  $policy

  Course context:
  $context
  
  User question:
  $userMessage
  '''.trim();
  }

  Future<String> _buildCourseContext(
    UnitNotes notes,
    OutlinePending pending,
    List<CourseFile> materials,
  ) async {
    final buffer = StringBuffer();
    if (notes.highlights.isNotEmpty) {
      buffer.writeln('Highlights:');
      for (final h in notes.highlights.take(10)) {
        buffer.writeln('- $h');
      }
    }
  if (notes.exams.isNotEmpty) {
    buffer.writeln('Exams:');
    for (final e in notes.exams.take(10)) {
      buffer.writeln('- ${e.text}${_formatDateForContext(e.date)}');
    }
  }
  if (notes.assignments.isNotEmpty) {
    buffer.writeln('Assignments:');
    for (final a in notes.assignments.take(10)) {
      buffer.writeln('- ${a.text}${_formatDateForContext(a.date)}');
    }
  }
    if (pending.exams.isNotEmpty || pending.assignments.isNotEmpty) {
      buffer.writeln('Pending approval:');
      for (final e in pending.exams.take(10)) {
        buffer.writeln('- Exam: ${e.text}${_formatDateForContext(e.date)}');
      }
      for (final a in pending.assignments.take(10)) {
        buffer.writeln('- Assignment: ${a.text}${_formatDateForContext(a.date)}');
      }
    }
    if (materials.isNotEmpty) {
      buffer.writeln('Course materials files:');
      for (final f in materials) {
        buffer.writeln('- ${f.name}');
        final excerpt = await _extractCourseFileExcerpt(f);
        if (excerpt != null && excerpt.trim().isNotEmpty) {
          buffer.writeln('  Excerpt: ${_clipText(excerpt, 800)}');
        } else {
          buffer.writeln('  (File contents not available on device)');
        }
      }
    }
    return buffer.toString().trim();
  }

Future<String?> _extractCourseFileExcerpt(
  CourseFile file, {
  void Function(String message)? onError,
}) async {
  final path = await _resolveCourseFilePath(
    file,
    onError: onError,
  );
  if (path == null || path.isEmpty) return null;
  try {
    final lower = path.toLowerCase();
    if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return File(path).readAsString();
    }
    final bytes = await File(path).readAsBytes();
    if (lower.endsWith('.pdf')) {
      return _extractPdfText(bytes);
    }
    if (lower.endsWith('.docx')) {
      return _extractDocxText(bytes);
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool _isGreetingMessage(String message) {
  final t = message.trim().toLowerCase();
  return t == 'hi' ||
      t == 'hello' ||
      t == 'hey' ||
      t == 'yo' ||
      t == 'sup' ||
      t.startsWith('hi ') ||
      t.startsWith('hello ') ||
      t.startsWith('hey ');
}

String _greetingReply() {
  return 'Hi! I can help summarize your unit materials, explain concepts '
      'from your uploads, and answer questions about exams or assignments. '
      'What do you want to work on?';
}

Future<String?> _resolveCourseFilePath(
  CourseFile file, {
  void Function(String message)? onError,
}) async {
  if (kIsWeb) {
    if (file.path.isNotEmpty) return file.path;
    onError?.call('File preview is not available for web-only uploads yet.');
    return null;
  }
  if (file.path.isNotEmpty) return file.path;
  if (file.storagePath.isEmpty) return null;
  try {
    final tempDir = await getTemporaryDirectory();
    final safeName =
        file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final tempPath = '${tempDir.path}/${file.id}_$safeName';
    final tempFile = File(tempPath);
    if (await tempFile.exists()) return tempPath;
    await FirebaseStorage.instance
        .ref(file.storagePath)
        .writeToFile(tempFile);
    return tempPath;
  } catch (_) {
    onError?.call('Failed to download file. Check your connection.');
    return null;
  }
}

String _extractPdfText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final text = extractor.extractText();
  document.dispose();
  return text;
}

String _extractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final docXml = archive.files
      .where((f) => f.name == 'word/document.xml')
      .map((f) => f.content as List<int>)
      .cast<List<int>>()
      .toList();
  if (docXml.isEmpty) return '';
  final xmlStr = utf8.decode(docXml.first);
  final document = XmlDocument.parse(xmlStr);
  final buffer = StringBuffer();

  for (final p in document.findAllElements('w:p')) {
    final runs = p.findAllElements('w:t');
    for (final t in runs) {
      buffer.write(t.innerText);
    }
    buffer.write('\n');
  }

  return buffer.toString();
}

String _clipText(String value, int maxChars) {
  final trimmed = value.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return '${trimmed.substring(0, maxChars)}...';
}

String _formatDateForContext(DateTime? date) {
  if (date == null) return ' (date missing)';
  return ' (${date.month}/${date.day}/${date.year})';
}

String _priorityForDate(DateTime? date) {
  if (date == null) return 'tbd';
  final days = date.difference(DateTime.now()).inDays;
  if (days <= 7) return 'high';
  if (days <= 21) return 'med';
  return 'low';
}

class _PriorityPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PriorityPicker({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['high', 'med', 'low', 'tbd'];
    const labels = {
      'high': 'High',
      'med': 'Medium',
      'low': 'Low',
      'tbd': 'TBD',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.subtext,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(labels[option] ?? option),
                selected: value == option,
                onSelected: (_) => onChanged(option),
                selectedColor: AppColors.primarySoft,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: value == option
                      ? AppColors.primary
                      : AppColors.text,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color:
                        value == option ? AppColors.primary : AppColors.line,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CourseMaterialsSection extends ConsumerWidget {
  final List<CourseFile> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String unitId;

  const _CourseMaterialsSection({
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.unitId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Add course materials like notes, slides, or pamphlets.',
                style: TextStyle(
                  color: AppColors.subtext,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onAdd,
              child: const Text('Upload File'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Materials',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
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
                  child: Icon(
                    _fileIcon(item.name),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileDate(item.addedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final statusMap =
                        ref.watch(courseFileUploadStatusProvider);
                    final status = statusMap[item.id];
                    if (status == null) return const SizedBox.shrink();
                    if (status.isUploading) {
                      final percent =
                          (status.progress.clamp(0, 1) * 100).round();
                      return SizedBox(
                        width: 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LinearProgressIndicator(
                              value: status.progress,
                              backgroundColor: AppColors.surface,
                              color: AppColors.primary,
                              minHeight: 6,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.subtext,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (status.error != null && status.error!.isNotEmpty) {
                      return Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(courseFilesProvider.notifier)
                                  .addFile(
                                    unitId,
                                    CourseFile(
                                      id: item.id,
                                      name: item.name,
                                      path: item.path,
                                      storagePath: item.storagePath,
                                      sizeBytes: item.sizeBytes,
                                      addedAt: item.addedAt,
                                    ),
                                  );
                            },
                            child: const Text(
                              'Retry',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                IconButton(
                  onPressed: () => onRemove(item.id),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onAdd,
            child: const Text('Upload another file'),
          ),
        ),
      ],
    );
  }
}

IconData _fileIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
    return Icons.slideshow_outlined;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  if (lower.endsWith('.txt') || lower.endsWith('.md')) {
    return Icons.notes_outlined;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    return Icons.image_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String _formatFileDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

Future<void> _pickCourseFile({
  required BuildContext context,
  required WidgetRef ref,
  required String unitId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.any,
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  final path = file.path ?? '';
  final candidateName = file.name.isNotEmpty
      ? file.name
      : (path.isNotEmpty ? _fileNameFromPath(path) : 'File');
  final ext = p.extension(candidateName).toLowerCase();
  final supported =
      CourseFilesController.allowedExtensions.contains(ext);
  if (!supported) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported file type.')),
      );
    }
    return;
  }
  if (file.size > CourseFilesController.maxFileSizeBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large. Max 15 MB.')),
      );
    }
    return;
  }
  final name = file.name.isNotEmpty ? file.name : _fileNameFromPath(path);
  final now = DateTime.now();
  final id = 'file-${now.microsecondsSinceEpoch}';
  if (kIsWeb && path.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Web upload saved in this session only. Refresh will clear it.',
          ),
        ),
      );
    }
  }
  await ref.read(courseFilesProvider.notifier).addFile(
        unitId,
        CourseFile(
          id: id,
          name: name,
          path: path,
          storagePath: '',
          sizeBytes: file.size,
          addedAt: now,
        ),
      );
  final status = ref.read(courseFileUploadStatusProvider)[id];
  if (status?.error != null && status!.error!.isNotEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.error!)),
      );
    }
  }
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isNotEmpty ? parts.last : 'File';
}

Future<void> _confirmRemoveCourseFile({
  required BuildContext context,
  required WidgetRef ref,
  required String unitId,
  required String fileId,
}) async {
  await showDeleteConfirm(
    context: context,
    title: 'Remove file?',
    message: 'This will remove the file from this course.',
    onConfirm: () {
      ref.read(courseFilesProvider.notifier).removeFile(unitId, fileId);
    },
  );
}

class _ChatItem {
  final String text;
  final bool isUser;

  const _ChatItem({
    required this.text,
    required this.isUser,
  });
}

class _SessionRow extends ConsumerWidget {
  final Session session;

  const _SessionRow({
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = session.status.toLowerCase();
    final isReady = status == 'ready';

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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isReady ? Icons.check_circle : Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displaySessionTitle(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isReady ? 'READY' : 'PROCESSING',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtext,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showEdit(context, ref),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                ),
                IconButton(
                  onPressed: () {
                    showDeleteConfirm(
                      context: context,
                      title: 'Delete Session?',
                      message: 'This action is permanent and cannot be undone.',
                      onConfirm: () {
                        ref
                            .read(sessionsProvider.notifier)
                            .removeSession(session.id);
                      },
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref) {
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


