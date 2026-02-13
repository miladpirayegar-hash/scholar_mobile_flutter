import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tasks_providers.dart';
import '../providers/task_meta_provider.dart';
import '../features/tasks/models/manual_task.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/units_provider.dart';
import '../providers/outline_pending_provider.dart';
import '../providers/sessions_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../providers/nav_provider.dart';
import 'unit_detail_screen.dart';

class TasksTabScreen extends ConsumerStatefulWidget {
  final String initialMode; // tasks | exams

  const TasksTabScreen({
    super.key,
    this.initialMode = 'tasks',
  });

  @override
  ConsumerState<TasksTabScreen> createState() => _TasksTabScreenState();
}

class _TasksTabScreenState extends ConsumerState<TasksTabScreen> {
  String _query = '';
  String _sort = 'date'; // date | priority | az
  String _selectedUnitId = 'all';
  final Set<String> _localCompleted = {};
  final Map<String, bool> _completedOverrides = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tasksModeProvider.notifier).state = widget.initialMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(tasksModeProvider);
    final tasks = ref.watch(tasksProvider);
    final completed = {
      ...ref.watch(completedTasksProvider),
      ..._localCompleted,
    };
    final metaMap = ref.watch(taskMetaProvider);
    final units = ref.watch(unitsProvider);
    final sessions = ref.watch(sessionsProvider);
    final unitNotes = ref.watch(unitNotesProvider);
    final pending = ref.watch(outlinePendingProvider);
    final hideContent = ref.watch(contentVisibilityProvider);
    final pendingCount = pending.values.fold<int>(
      0,
      (sum, entry) => sum + entry.exams.length + entry.assignments.length,
    );
    final unitTitleById = {
      for (final u in units) u.id: u.title,
    };
    final pendingUnitId = _pendingUnitId(
      pending: pending,
      selectedUnitId: _selectedUnitId,
    );

    final sessionUnitById = {
      for (final s in sessions)
        s.id: (s.eventId == null || s.eventId!.isEmpty)
            ? 'general'
            : s.eventId!,
    };

    final sourceTasks = hideContent ? const <dynamic>[] : tasks;
    final sourceCompleted = hideContent ? const <String>{} : completed;
    final sourceUnitNotes = unitNotes;

    final visible = sourceTasks.where((t) {
      final text = _displayText(t, metaMap);
      if (_selectedUnitId != 'all') {
        final unitId = t is ManualTask
            ? (t.sessionId ?? 'general')
            : sessionUnitById[t.sessionId as String] ?? 'general';
        if (unitId != _selectedUnitId) return false;
      }
      return _query.isEmpty ||
          text.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final qLower = _query.toLowerCase();
    final exams = _collectExams(sourceUnitNotes, units)
        .where((e) {
          final matchesUnit =
              _selectedUnitId == 'all' || e.unitId == _selectedUnitId;
          if (!matchesUnit) return false;
          if (_query.isEmpty) return true;
          return e.text.toLowerCase().contains(qLower) ||
              e.unitTitle.toLowerCase().contains(qLower);
        })
        .toList();

    visible.sort((a, b) {
      final aDone = sourceCompleted.contains(a.id as String);
      final bDone = sourceCompleted.contains(b.id as String);
      if (aDone != bDone) {
        return aDone ? 1 : -1;
      }
      final aMeta = metaMap[a.id as String] ?? const TaskMeta();
      final bMeta = metaMap[b.id as String] ?? const TaskMeta();
      if (aMeta.pinned != bMeta.pinned) {
        return bMeta.pinned ? 1 : -1;
      }
      if (_sort == 'date') {
        final da = aMeta.dueDate ?? DateTime(2100);
        final db = bMeta.dueDate ?? DateTime(2100);
        return da.compareTo(db);
      }
      if (_sort == 'priority') {
        final pa = _priorityRank(aMeta.priority);
        final pb = _priorityRank(bMeta.priority);
        if (pa != pb) return pa.compareTo(pb);
      }
      if (_sort == 'az') {
        final ta = _displayText(a, metaMap).toLowerCase();
        final tb = _displayText(b, metaMap).toLowerCase();
        return ta.compareTo(tb);
      }
      return 0;
    });

    exams.sort((a, b) {
      if (_sort == 'az') {
        return a.text.toLowerCase().compareTo(b.text.toLowerCase());
      }
      final da = a.date ?? DateTime(2100);
      final db = b.date ?? DateTime(2100);
      return da.compareTo(db);
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tasks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                _TopAddButton(onTap: () => _openAddChooser(units)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Outcome management',
              style: TextStyle(
                color: AppColors.subtext,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 14, horizontal: 0),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Tasks',
                    active: mode == 'tasks',
                    onTap: () =>
                        ref.read(tasksModeProvider.notifier).state = 'tasks',
                    icon: Icons.task_alt,
                    dense: true,
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Exams',
                    active: mode == 'exams',
                    onTap: () =>
                        ref.read(tasksModeProvider.notifier).state = 'exams',
                    icon: Icons.event_available,
                    badgeCount: pendingCount,
                    dense: true,
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: _unitLabel(units, _selectedUnitId),
                    active: _selectedUnitId != 'all',
                    onTap: () => _openUnitFilter(context, units),
                    icon: Icons.school,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            mode == 'tasks'
                ? _SortBar(
                    value: _sort,
                    onChange: (v) => setState(() => _sort = v),
                  )
                : _ExamSortBar(
                    value: _sort,
                    onChange: (v) => setState(() => _sort = v),
                  ),
            const SizedBox(height: 12),
            Expanded(
              child: mode == 'tasks'
                  ? (visible.isEmpty
                      ? _EmptyState(
                          title: 'No tasks yet.',
                          subtitle:
                              'Start recording or add a task to see items here.',
                          ctaLabel: 'Add Task',
                          onTap: () => _openTaskModal(isEdit: false),
                        )
                      : ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = visible[index];
                            final id = task.id as String;
                            final meta = metaMap[id] ?? const TaskMeta();
                            final done =
                                _completedOverrides[id] ??
                                sourceCompleted.contains(id);
                            return _TaskCard(
                              text: _displayText(task, metaMap),
                              done: done,
                              meta: meta,
                              onToggle: () => _toggleCompleted(id, done),
                              onEdit: () => _openEdit(task, meta),
                              onTap: () => _openEdit(task, meta),
                              onDelete: () => _deleteTask(task),
                              onPin: () => ref
                                  .read(taskMetaProvider.notifier)
                                  .togglePin(id),
                            );
                          },
                        ))
                  : (exams.isEmpty
                      ? ListView(
                          children: [
                            if (pendingCount > 0 && pendingUnitId != null)
                              _PendingApprovalsCard(
                                count: pendingCount,
                                onTap: () {
                                  final unitTitle =
                                      unitTitleById[pendingUnitId] ??
                                          'Course';
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UnitDetailScreen(
                                        unitTitle: unitTitle,
                                        unitId: pendingUnitId,
                                        initialTabIndex: 1,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 12),
                            _EmptyState(
                              title: 'No exams or assignments yet.',
                              subtitle:
                                  'Upload an outline or add items to see them here.',
                              ctaLabel: 'Add Exam',
                              onTap: () => _openAddExamModal(units),
                            ),
                          ],
                        )
                      : _ExamsList(
                          items: exams,
                          pending: pending,
                          unitTitleById: unitTitleById,
                        )),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _displayText(dynamic task, Map<String, TaskMeta> metaMap) {
    final id = task.id as String;
    final meta = metaMap[id];
    if (meta?.overrideText != null && meta!.overrideText!.isNotEmpty) {
      return meta.overrideText!;
    }
    return task.text as String;
  }

  int _priorityRank(String? value) {
    switch (value) {
      case 'high':
        return 0;
      case 'med':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  String _unitLabel(List<dynamic> units, String unitId) {
    if (unitId == 'all') return 'All Courses';
    final match = units
        .where((u) => u.id == unitId)
        .map((u) => u.title)
        .firstWhere((_) => true, orElse: () => 'Course');
    return match.toString();
  }

  String? _pendingUnitId({
    required Map<String, OutlinePending> pending,
    required String selectedUnitId,
  }) {
    if (pending.isEmpty) return null;
    if (selectedUnitId != 'all' && pending.containsKey(selectedUnitId)) {
      return selectedUnitId;
    }
    return pending.keys.first;
  }

  void _openUnitFilter(BuildContext context, List<dynamic> units) {
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
            _UnitOption(
              label: 'All Courses',
              active: _selectedUnitId == 'all',
              onTap: () {
                setState(() => _selectedUnitId = 'all');
                Navigator.of(context).pop();
              },
            ),
            for (final u in units)
              _UnitOption(
                label: u.title.toString(),
                active: _selectedUnitId == u.id,
                onTap: () {
                  setState(() => _selectedUnitId = u.id as String);
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  void _openAddChooser(List<dynamic> units) {
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openTaskModal(isEdit: false);
                },
                child: const Text('Task'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openAddExamModal(units);
                },
                child: const Text('Exam'),
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

  void _openAddExamModal(List<dynamic> units) {
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
                  'Add Exam',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please add a course first, then you can add exams.',
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
                  child: const Text('Go to Courses'),
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
    String selectedUnitId = (units.first).id as String;
    final text = TextEditingController();
    DateTime? due;
    String selectedPriority = _priorityForDate(due);
    final notes = TextEditingController();
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
                    'Add Exam',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedUnitId,
                  items: [
                    for (final u in units)
                      DropdownMenuItem(
                        value: u.id as String,
                        child: Text(u.title.toString()),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setModalState(() => selectedUnitId = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Course',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Exam details...',
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  date: due,
                  onPick: (d) => setModalState(() => due = d),
                ),
                const SizedBox(height: 12),
                _PriorityPicker(
                  value: selectedPriority,
                  onChanged: (v) => setModalState(() => selectedPriority = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(unitNotesProvider.notifier).addExamWithDate(
                        selectedUnitId,
                        text.text.trim(),
                        due,
                        note: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        priority: selectedPriority,
                      );
                      ref
                          .read(contentVisibilityProvider.notifier)
                          .markContentStarted();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save Exam'),
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

  void _openEdit(dynamic task, TaskMeta meta) {
    _openTaskModal(isEdit: true, task: task, meta: meta);
  }

  void _toggleCompleted(String id, bool currentDone) {
    setState(() {
      _completedOverrides[id] = !currentDone;
      if (_localCompleted.contains(id)) {
        _localCompleted.remove(id);
      } else {
        _localCompleted.add(id);
      }
    });
    ref.read(completedTasksProvider.notifier).toggle(id);
  }

  void _deleteTask(dynamic task) {
    showDeleteConfirm(
      context: context,
      title: 'Delete task?',
      message: 'This action is permanent and cannot be undone.',
      onConfirm: () {
        if (task is ManualTask) {
          ref.read(manualTasksProvider.notifier).remove(task.id);
        } else {
          ref.read(completedTasksProvider.notifier).toggle(task.id);
        }
      },
    );
  }

  void _openTaskModal({
    required bool isEdit,
    dynamic task,
    TaskMeta? meta,
  }) {
    final text = TextEditingController(text: isEdit ? task.text : '');
    String priority = meta?.priority ?? 'med';
    DateTime? due = meta?.dueDate;
    final notes = TextEditingController(text: meta?.notes ?? '');

    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEdit ? 'Edit Goal' : 'New Goal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DropdownField(
                    value: priority,
                    onChanged: (v) => priority = v,
                    items: const ['low', 'med', 'high'],
                    labelFor: (v) =>
                        v == 'high' ? 'High Priority' : v == 'low'
                            ? 'Low Priority'
                            : 'Med Priority',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    date: due,
                    onPick: (d) => due = d,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (isEdit) {
                        ref.read(taskMetaProvider.notifier).setMeta(
                              task.id,
                              TaskMeta(
                                pinned: meta?.pinned ?? false,
                                priority: priority,
                                dueDate: due,
                                overrideText: text.text.trim(),
                                notes: notes.text.trim().isEmpty
                                    ? null
                                    : notes.text.trim(),
                              ),
                            );
                        } else {
                          final manual = ref
                              .read(manualTasksProvider.notifier)
                              .addWithReturn(text: text.text.trim());
                          ref.read(taskMetaProvider.notifier).setMeta(
                                manual.id,
                                TaskMeta(
                                  pinned: false,
                                  priority: priority,
                                  dueDate: due,
                                  notes: notes.text.trim().isEmpty
                                      ? null
                                      : notes.text.trim(),
                                ),
                              );
                        }
                        ref
                            .read(contentVisibilityProvider.notifier)
                            .markContentStarted();
                        Navigator.of(context).pop();
                      },
                    child: Text(isEdit ? 'Save Changes' : 'Add Task'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtext,
              ),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  child: Text(ctaLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingApprovalsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingApprovalsCard({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'item' : 'items';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_turned_in,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count pending $label',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review and approve items from the course profile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _ExamItem {
  final String unitId;
  final String unitTitle;
  final DatedItem item;
  final bool isExam;
  final bool isPending;

  const _ExamItem({
    required this.unitId,
    required this.unitTitle,
    required this.item,
    required this.isExam,
    this.isPending = false,
  });

  String get text => item.text;
  DateTime? get date => item.date;
  String? get notes => item.notes;
}

List<_ExamItem> _collectExams(
  Map<String, UnitNotes> unitNotes,
  List<dynamic> units,
) {
  final items = <_ExamItem>[];
  for (final entry in unitNotes.entries) {
    final unitId = entry.key;
    final notes = entry.value;
    final unitTitle = units
        .where((u) => u.id == unitId)
        .map((u) => u.title)
        .firstWhere((_) => true, orElse: () => 'Unassigned');
    for (final e in notes.exams) {
      items.add(
        _ExamItem(
          unitId: unitId,
          unitTitle: unitTitle,
          item: e,
          isExam: true,
        ),
      );
    }
    for (final a in notes.assignments) {
      items.add(
        _ExamItem(
          unitId: unitId,
          unitTitle: unitTitle,
          item: a,
          isExam: false,
        ),
      );
    }
  }
  return items;
}

class _ExamsList extends ConsumerWidget {
  final List<_ExamItem> items;
  final Map<String, OutlinePending> pending;
  final Map<String, String> unitTitleById;

  const _ExamsList({
    required this.items,
    required this.pending,
    required this.unitTitleById,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingItems = <_ExamItem>[];
    for (final entry in pending.entries) {
      final unitId = entry.key;
      final unitTitle =
          unitTitleById[unitId] ?? _unitTitleFor(items, unitId);
      for (final e in entry.value.exams) {
        pendingItems.add(
          _ExamItem(
            unitId: unitId,
            unitTitle: unitTitle,
            item: e,
            isExam: true,
            isPending: true,
          ),
        );
      }
      for (final a in entry.value.assignments) {
        pendingItems.add(
          _ExamItem(
            unitId: unitId,
            unitTitle: unitTitle,
            item: a,
            isExam: false,
            isPending: true,
          ),
        );
      }
    }

    if (items.isEmpty && pendingItems.isEmpty) {
      return const Center(
        child: Text(
          'No exams or assignments yet.',
          style: TextStyle(
            color: AppColors.subtext,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length + (pendingItems.isEmpty ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (pendingItems.isNotEmpty && index == 0) {
          return _PendingApprovalSection(
            items: pendingItems,
                onApprove: (item) {
                  if (item.isExam) {
                    ref.read(unitNotesProvider.notifier).addExamWithDate(
                      item.unitId,
                      item.text,
                      item.date,
                      note: item.item.notes,
                      priority: item.item.priority,
                    );
                  ref
                      .read(outlinePendingProvider.notifier)
                      .removePendingExam(
                        item.unitId,
                        DatedItem(text: item.text, date: item.date),
                      );
                  } else {
                    ref.read(unitNotesProvider.notifier).addAssignmentWithDate(
                      item.unitId,
                      item.text,
                      item.date,
                      note: item.item.notes,
                      priority: item.item.priority,
                    );
                  ref
                      .read(outlinePendingProvider.notifier)
                      .removePendingAssignment(
                        item.unitId,
                        DatedItem(text: item.text, date: item.date),
                      );
                }
                ref
                    .read(contentVisibilityProvider.notifier)
                    .markContentStarted();
            },
            onDecline: (item) {
              if (item.isExam) {
                ref
                    .read(outlinePendingProvider.notifier)
                    .removePendingExam(
                      item.unitId,
                      DatedItem(text: item.text, date: item.date),
                    );
              } else {
                ref
                    .read(outlinePendingProvider.notifier)
                    .removePendingAssignment(
                      item.unitId,
                      DatedItem(text: item.text, date: item.date),
                    );
              }
            },
            onEdit: (item) => _openDatedItemEditModal(
              context: context,
              item: item,
              onSave: (next) {
                if (item.isExam) {
                  ref.read(outlinePendingProvider.notifier).updatePendingExam(
                        item.unitId,
                        item.item,
                        next,
                      );
                } else {
                  ref
                      .read(outlinePendingProvider.notifier)
                      .updatePendingAssignment(
                        item.unitId,
                        item.item,
                        next,
                      );
                }
              },
            ),
          );
        }
        final actualIndex = pendingItems.isNotEmpty ? index - 1 : index;
        final item = items[actualIndex];
          final priority = _priorityForItem(item);
          final priorityStyle = _priorityStyle(priority);
          return GestureDetector(
            onTap: () => _openDatedItemEditModal(
              context: context,
              item: item,
              onSave: (next) {
                if (item.isExam) {
                  ref.read(unitNotesProvider.notifier).updateExamByValue(
                        item.unitId,
                        item.item,
                        next,
                      );
                } else {
                  ref
                      .read(unitNotesProvider.notifier)
                      .updateAssignmentByValue(
                        item.unitId,
                        item.item,
                        next,
                      );
                }
              },
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                      item.isExam
                          ? Icons.event_available
                          : Icons.assignment_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.isExam
                              ? 'EXAM - ${item.text}'
                              : 'ASSIGNMENT - ${item.text}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.unitTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtext,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: priorityStyle.background,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${priority.toUpperCase()} PRIORITY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: priorityStyle.foreground,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(item.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.subtext,
                          ),
                        ),
                        if (item.notes != null &&
                            item.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.notes!,
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          _openDatedItemEditModal(
                            context: context,
                            item: item,
                            onSave: (next) {
                              if (item.isExam) {
                                ref
                                    .read(unitNotesProvider.notifier)
                                    .updateExamByValue(
                                      item.unitId,
                                      item.item,
                                      next,
                                    );
                              } else {
                                ref
                                    .read(unitNotesProvider.notifier)
                                    .updateAssignmentByValue(
                                      item.unitId,
                                      item.item,
                                      next,
                                    );
                              }
                            },
                          );
                          break;
                        case 'delete':
                          await _confirmRemoveDatedItem(context, ref, item);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
      },
    );
  }
}

Future<void> _confirmRemoveDatedItem(
  BuildContext context,
  WidgetRef ref,
  _ExamItem item,
) async {
  final isExam = item.isExam;
  final label = isExam ? 'exam' : 'assignment';
  await showDeleteConfirm(
    context: context,
    title: 'Remove $label?',
    message: 'This will remove the $label from this course.',
    onConfirm: () {
      if (isExam) {
        ref
            .read(unitNotesProvider.notifier)
            .removeExamByValue(item.unitId, item.item);
      } else {
        ref
            .read(unitNotesProvider.notifier)
            .removeAssignmentByValue(item.unitId, item.item);
      }
    },
  );
}

String _unitTitleFor(List<_ExamItem> items, String unitId) {
  return items
      .where((e) => e.unitId == unitId)
      .map((e) => e.unitTitle)
      .firstWhere((_) => true, orElse: () => 'Unassigned');
}

class _PendingApprovalSection extends StatelessWidget {
  final List<_ExamItem> items;
  final ValueChanged<_ExamItem> onApprove;
  final ValueChanged<_ExamItem> onDecline;
  final ValueChanged<_ExamItem> onEdit;

  const _PendingApprovalSection({
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showPendingDetail(
                                  context: context,
                                  item: item,
                                  onApprove: onApprove,
                                  onDecline: onDecline,
                                  onEdit: onEdit,
                                ),
                                child: Text(
                                  item.isExam
                                      ? 'EXAM - ${item.text}'
                                      : 'ASSIGNMENT - ${item.text}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.unitTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.subtext,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) {
                                    final priority = _priorityForItem(item);
                                      final style = _priorityStyle(priority);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: style.background,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${priority.toUpperCase()} PRIORITY',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: style.foreground,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(item.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.subtext,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.notes != null &&
                                  item.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  item.notes!,
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => onApprove(item),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => onDecline(item),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Decline'),
                          ),
                        ],
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

class _TaskCard extends StatelessWidget {
  final String text;
  final bool done;
  final TaskMeta meta;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const _TaskCard({
    required this.text,
    required this.done,
    required this.meta,
    required this.onToggle,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AppColors.primary : AppColors.muted,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontWeight: done ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 15,
                          color: done ? AppColors.subtext : AppColors.text,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationThickness: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 10),
                            decoration: BoxDecoration(
                              color: done
                                  ? AppColors.surface
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                              border: done
                                  ? Border.all(color: AppColors.line)
                                  : null,
                            ),
                            child: Text(
                              '${meta.priority.toUpperCase()} PRIORITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: done
                                    ? AppColors.subtext
                                    : AppColors.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (meta.dueDate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${meta.dueDate!.month}/${meta.dueDate!.day}/${meta.dueDate!.year}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.subtext,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (meta.notes != null && meta.notes!.trim().isNotEmpty)
                        Text(
                          meta.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                done ? AppColors.subtext : AppColors.subtext,
                            height: 1.4,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          ),
                        )
                      else
                        Text(
                          'Add notes',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                done ? AppColors.subtext : AppColors.subtext,
                            fontWeight: FontWeight.w700,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                switch (value) {
                  case 'pin':
                    onPin();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Text(meta.pinned ? 'Unpin' : 'Pin'),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showPendingDetail({
  required BuildContext context,
  required _ExamItem item,
  required ValueChanged<_ExamItem> onApprove,
  required ValueChanged<_ExamItem> onDecline,
  required ValueChanged<_ExamItem> onEdit,
}) {
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
                  item.isExam ? 'Exam Approval' : 'Assignment Approval',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              item.text,
              style: const TextStyle(height: 1.4),
            ),
          ),
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                item.notes!,
                style: const TextStyle(
                  height: 1.4,
                  color: AppColors.subtext,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.unitTitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtext,
              ),
            ),
          ),
          if (item.date != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatDate(item.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatDate(item.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    onEdit(item);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Edit'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    onDecline(item);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Decline'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onApprove(item);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

  void _openDatedItemEditModal({
    required BuildContext context,
    required _ExamItem item,
    required ValueChanged<DatedItem> onSave,
  }) {
    final controller = TextEditingController(text: item.text);
    DateTime? selectedDate = item.date;
    final notes = TextEditingController(text: item.notes ?? '');
    String selectedPriority =
        item.item.priority ?? _priorityForDate(selectedDate);
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
                  item.isExam ? 'Edit Exam' : 'Edit Assignment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Update details...',
                ),
              ),
                const SizedBox(height: 12),
                _DateField(
                  date: selectedDate,
                  onPick: (d) => setModalState(() => selectedDate = d),
                ),
                const SizedBox(height: 12),
                _PriorityPicker(
                  value: selectedPriority,
                  onChanged: (v) => setModalState(() => selectedPriority = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                      final next = DatedItem(
                        text: controller.text.trim(),
                        date: selectedDate,
                        notes: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        priority: selectedPriority,
                      );
                    onSave(next);
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

String _formatDate(DateTime? date) {
  if (date == null) return 'Missing date';
  return '${date.month}/${date.day}/${date.year}';
}

String _priorityForDate(DateTime? date) {
  if (date == null) return 'tbd';
  final days = date.difference(DateTime.now()).inDays;
  if (days <= 7) return 'high';
  if (days <= 21) return 'med';
  return 'low';
}

String _priorityForItem(_ExamItem item) {
  final raw = item.item.priority;
  if (raw == null || raw.isEmpty) {
    return _priorityForDate(item.date);
  }
  return raw;
}

_PriorityStyle _priorityStyle(String priority) {
  switch (priority) {
    case 'high':
      return const _PriorityStyle(
        background: Color(0xFFFFE4E6),
        foreground: AppColors.danger,
      );
    case 'med':
      return const _PriorityStyle(
        background: Color(0xFFFFF7ED),
        foreground: AppColors.warning,
      );
    case 'low':
      return const _PriorityStyle(
        background: Color(0xFFECFDF3),
        foreground: AppColors.success,
      );
    default:
      return const _PriorityStyle(
        background: AppColors.surface,
        foreground: AppColors.subtext,
      );
  }
}

class _PriorityStyle {
  final Color background;
  final Color foreground;

  const _PriorityStyle({
    required this.background,
    required this.foreground,
  });
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final int badgeCount;
  final bool dense;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.badgeCount = 0,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 12,
          vertical: dense ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 13 : 14),
              SizedBox(width: dense ? 4 : 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badgeCount > 0) ...[
              SizedBox(width: dense ? 4 : 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount',
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
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;

  const _SortBar({
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _SortOption(
            label: 'Date',
            icon: Icons.sort,
            active: value == 'date',
            onTap: () => onChange('date'),
          ),
          _SortOption(
            label: 'Priority',
            icon: Icons.flag_outlined,
            active: value == 'priority',
            onTap: () => onChange('priority'),
          ),
          _SortOption(
            label: 'A to Z',
            icon: Icons.sort_by_alpha,
            active: value == 'az',
            onTap: () => onChange('az'),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: active ? Border.all(color: AppColors.line) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.primary : AppColors.text,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TopAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ExamSortBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;

  const _ExamSortBar({
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _SortOption(
            label: 'Date',
            icon: Icons.sort,
            active: value != 'az',
            onTap: () => onChange('date'),
          ),
          _SortOption(
            label: 'A to Z',
            icon: Icons.sort_by_alpha,
            active: value == 'az',
            onTap: () => onChange('az'),
          ),
        ],
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UnitOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (active)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> items;
  final String Function(String) labelFor;

  const _DropdownField({
    required this.value,
    required this.onChanged,
    required this.items,
    required this.labelFor,
  });

  @override
  State<_DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<_DropdownField> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _value,
          isExpanded: true,
          items: widget.items
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(widget.labelFor(v)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _value = v);
            widget.onChanged(v);
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;

  const _DateField({
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'mm/dd/yyyy'
        : '${date!.month}/${date!.day}/${date!.year}';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
          builder: (context, child) {
            return Theme(
              data: AppTheme.datePickerTheme(context),
              child: child!,
            );
          },
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
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


