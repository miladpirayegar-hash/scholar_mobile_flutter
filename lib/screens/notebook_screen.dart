// lib/screens/notebook_screen.dart
// FIXED ALL REPORTED ERRORS IN ONE PASS
// - Safe DateTime sorting with null handling
// - No invalid Unit constructor usage
// - No missing required arguments
// - No nullable compareTo
// - No unnecessary underscore warnings
// - Architecture untouched

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessions_provider.dart';
import '../providers/upload_queue_provider.dart';
import '../providers/units_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../models/session.dart';
import '../models/unit.dart';
import 'unit_detail_screen.dart';
import 'session_detail_screen.dart';
import 'assign_session_to_unit_sheet.dart';
import '../core/utils/session_format.dart';
import '../providers/user_prefs_provider.dart';
import 'recording_screen.dart';

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final hideContent = ref.watch(contentVisibilityProvider);
    final visibleSessions = hideContent ? const <Session>[] : sessions;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notebook',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Archived academic sessions',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openCreateUnit(context, ref),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _TabButton(
                  label: 'Courses',
                  active: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 24),
                _TabButton(
                  label: 'Sessions',
                  active: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _tabIndex == 0
                  ? _UnitsTab(
                      sessions: visibleSessions,
                      onAddCourse: () => _openCreateUnit(context, ref),
                    )
                  : _CapturesTab(sessions: visibleSessions),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateUnit(BuildContext context, WidgetRef ref) {
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
                    'Create New Course',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Course name',
              ),
            ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = controller.text.trim();
                    if (title.isEmpty) return;
                    ref.read(unitsProvider.notifier).createUnit(title);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Create'),
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

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : AppColors.text,
            ),
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

class _UnitsTab extends ConsumerWidget {
  final List<Session> sessions;
  final VoidCallback onAddCourse;

  const _UnitsTab({
    required this.sessions,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);

    final Map<String, int> counts = {};
    for (final s in sessions) {
      final key =
          (s.eventId == null || s.eventId!.isEmpty) ? 'general' : s.eventId!;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (units.isEmpty) {
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
                'No courses yet.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add your first course to start recording sessions.',
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
                  onPressed: onAddCourse,
                  child: const Text('Add Course'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
      itemCount: units.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final unit = units[index];
        final count = counts[unit.id] ?? 0;

        return _UnitCard(unit: unit, sessionCount: count);
      },
    );
  }
}

class _UnitCard extends ConsumerWidget {
  final Unit unit;
  final int sessionCount;

  const _UnitCard({
    required this.unit,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial =
        unit.title.trim().isEmpty ? 'U' : unit.title.characters.first.toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UnitDetailScreen(
              unitTitle: unit.title,
              unitId: unit.id,
            ),
          ),
        );
      },
      onLongPress: () {
        showEditModal(
          context: context,
          title: 'Rename Course',
          initialValue: unit.title,
          hintText: 'Course name',
          saveLabel: 'Save',
          onSave: (value) {
            ref.read(unitsProvider.notifier).updateUnitTitle(
                  unitId: unit.id,
                  title: value,
                );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$sessionCount Sessions archived',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showEdit(context, ref, unit),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                    ),
                    IconButton(
                      onPressed: () => _confirmRemoveUnit(context, ref, unit),
                      icon:
                          const Icon(Icons.delete_outline, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'OPEN SUBJECT DASHBOARD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showEdit(BuildContext context, WidgetRef ref, Unit unit) {
  showEditModal(
    context: context,
    title: 'Rename Course',
    initialValue: unit.title,
    hintText: 'Course name',
    saveLabel: 'Save',
    onSave: (value) {
      ref.read(unitsProvider.notifier).updateUnitTitle(
            unitId: unit.id,
            title: value,
          );
    },
  );
}

void _confirmRemoveUnit(BuildContext context, WidgetRef ref, Unit unit) {
  showDeleteConfirm(
    context: context,
    title: 'Delete Course?',
    message: 'This action is permanent and cannot be undone.',
    onConfirm: () {
      ref.read(sessionsProvider.notifier).unassignUnit(unit.id);
      ref.read(unitsProvider.notifier).removeUnit(unit.id);
    },
  );
}

class _CapturesTab extends ConsumerStatefulWidget {
  final List<Session> sessions;

  const _CapturesTab({required this.sessions});

  @override
  ConsumerState<_CapturesTab> createState() => _CapturesTabState();
}

class _CapturesTabState extends ConsumerState<_CapturesTab> {
  String _sort = 'newest'; // newest | oldest | az

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final stored = ref.read(userPrefsProvider).sessionsSort;
      if (!mounted) return;
      setState(() {
        _sort = stored.isNotEmpty ? stored : 'newest';
      });
    });
  }

  Future<void> _setSort(String value) async {
    setState(() => _sort = value);
    await ref.read(userPrefsProvider.notifier).setSessionsSort(value);
  }

  @override
  Widget build(BuildContext context) {
    final uploadQueue = ref.watch(uploadQueueProvider);
    final units = ref.watch(unitsProvider);

    if (widget.sessions.isEmpty) {
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
                'Add a course and start recording to see sessions here.',
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

    final list = [...widget.sessions]..sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (_sort == 'oldest') return da.compareTo(db);
      if (_sort == 'az') {
        return displaySessionTitle(a)
            .toLowerCase()
            .compareTo(displaySessionTitle(b).toLowerCase());
      }
      return db.compareTo(da);
    });

    return Column(
      children: [
        Row(
          children: [
            _FilterPill(
              label: 'Newest',
              active: _sort == 'newest',
              onTap: () => _setSort('newest'),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Oldest',
              active: _sort == 'oldest',
              onTap: () => _setSort('oldest'),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'A-Z',
              active: _sort == 'az',
              onTap: () => _setSort('az'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = list[index];

              final isPendingUpload = uploadQueue.any((u) {
                final p = u.filePath.toLowerCase();
                return p.contains(session.id.toLowerCase());
              });

              final unitTitle = units
                      .where((u) => u.id == session.eventId)
                      .map((u) => u.title)
                      .firstWhere(
                        (_) => true,
                        orElse: () => 'Unassigned',
                      );

              return _CaptureRow(
                session: session,
                unitTitle: unitTitle,
                isPendingUpload: isPendingUpload,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CaptureRow extends ConsumerWidget {
  final Session session;
  final String unitTitle;
  final bool isPendingUpload;

  const _CaptureRow({
    required this.session,
    required this.unitTitle,
    required this.isPendingUpload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = session.status.toLowerCase();

    final Widget statusPill;
    if (status == 'recording') {
      statusPill = const _MetaPill(
        text: 'Recording',
        bg: Color(0xFFFFF7ED),
        fg: Color(0xFF9A3412),
        icon: Icons.mic,
      );
    } else if (isPendingUpload) {
      statusPill = const _MetaPill(
        text: 'Pending upload',
        bg: AppColors.surface,
        fg: AppColors.subtext,
        icon: Icons.cloud_upload,
      );
    } else if (status != 'ready') {
      statusPill = const _MetaPill(
        text: 'Analyzing',
        bg: Color(0xFFFFF7ED),
        fg: Color(0xFF9A3412),
        icon: Icons.auto_awesome,
      );
    } else {
      statusPill = const _MetaPill(
        text: 'Ready',
        bg: Color(0xFFECFDF5),
        fg: Color(0xFF065F46),
        icon: Icons.check_circle,
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        );
      },
      onLongPress: () {
        AppModal.show(
          context: context,
          builder: (_) => AssignSessionToUnitSheet(session: session),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.mic,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displaySessionTitle(session),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaPill(
                        text: unitTitle,
                        bg: AppColors.surface,
                        fg: AppColors.text,
                        icon: Icons.book_rounded,
                      ),
                      statusPill,
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showEditCapture(context, ref, session),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 6),
                IconButton(
                  onPressed: () => _confirmRemoveCapture(context, ref, session),
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showEditCapture(BuildContext context, WidgetRef ref, Session session) {
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

void _confirmRemoveCapture(
  BuildContext context,
  WidgetRef ref,
  Session session,
) {
  showDeleteConfirm(
    context: context,
    title: 'Delete Session?',
    message: 'This action is permanent and cannot be undone.',
    onConfirm: () {
      ref.read(sessionsProvider.notifier).removeSession(session.id);
    },
  );
}

class _MetaPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData icon;

  const _MetaPill({
    required this.text,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.text : AppColors.subtext,
          ),
        ),
      ),
    );
  }
}



