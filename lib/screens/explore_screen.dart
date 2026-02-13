import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessions_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/tasks_providers.dart';
import '../providers/task_meta_provider.dart';
import '../providers/units_provider.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/unit_notes_ai_provider.dart';
import '../providers/outline_pending_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../providers/user_prefs_provider.dart';
import '../models/session.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/auth_modal.dart';
import '../providers/auth_provider.dart';
import '../screens/notifications_screen.dart';
import '../core/utils/session_format.dart';
import '../core/utils/approval_counts.dart';
import 'session_detail_screen.dart';
import 'outline_upload_flow.dart';
import 'recording_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final GlobalKey? profileKey;
  final GlobalKey? uploadKey;
  final GlobalKey? notificationsKey;
  final bool showStartHighlights;
  final VoidCallback? onUploadTap;

  const ExploreScreen({
    super.key,
    this.profileKey,
    this.uploadKey,
    this.notificationsKey,
    this.showStartHighlights = false,
    this.onUploadTap,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _promptedUpload = false;
  bool _hasUploadedOutline = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final prefs = ref.read(userPrefsProvider);
      final shouldPrompt = prefs.needsOutlineUpload;
      final hasUploaded = prefs.hasUploadedOutline;
      if (mounted) {
        setState(() => _hasUploadedOutline = hasUploaded);
      }
      if (!mounted || !shouldPrompt || _promptedUpload) return;
      _promptedUpload = true;
      // ignore: use_build_context_synchronously
      await _showOutlineUploadInfo(context, ref, fromSignup: true);
      if (!mounted) return;
      await ref
          .read(userPrefsProvider.notifier)
          .setNeedsOutlineUpload(false);
    });
  }

  Future<void> _refreshUploadFlag() async {
    final hasUploaded = ref.read(userPrefsProvider).hasUploadedOutline;
    if (!mounted) return;
    setState(() => _hasUploadedOutline = hasUploaded);
  }

  void _openMenu(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final parentContext = context;
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
                    auth.userName?.isNotEmpty == true
                        ? 'Hi, ${auth.userName}'
                        : 'Menu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MenuTile(
              title: 'Settings',
              subtitle: 'Notifications, devices, consent',
              icon: Icons.settings_outlined,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(parentContext).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            _MenuTile(
              title: 'Academic Profile',
              subtitle: 'Manage your academic profile',
              icon: Icons.person_outline,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(parentContext).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
            if (auth.isSignedIn)
              _MenuTile(
                title: 'Log Out',
                subtitle: 'Sign out of this device',
                icon: Icons.logout,
                isDestructive: true,
                onTap: () {
                  ref.read(authProvider.notifier).signOut();
                  Navigator.of(context).pop();
                },
              )
            else
              _MenuTile(
                title: 'Sign In / Sign Up',
                subtitle: 'Access sync and backup',
                icon: Icons.login,
                onTap: () {
                  Navigator.of(context).pop();
                  AppModal.show(
                    context: context,
                    builder: (_) => const AuthModal(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final tasks = ref.watch(tasksProvider);
    final completed = ref.watch(completedTasksProvider);
    final metaMap = ref.watch(taskMetaProvider);
    final units = ref.watch(unitsProvider);
    final unitNotes = ref.watch(unitNotesProvider);
    final dismissed = ref.watch(unitNotesAiProvider);
    final pendingByUnit = ref.watch(outlinePendingProvider);
    final hideContent = ref.watch(contentVisibilityProvider);

    final sourceSessions = hideContent ? const <Session>[] : sessions;
    final sourceTasks = hideContent ? const <dynamic>[] : tasks;
    final sourceCompleted = hideContent ? const <String>{} : completed;
    final sourceUnitNotes =
        hideContent ? const <String, UnitNotes>{} : unitNotes;
    final sourcePending =
        hideContent ? const <String, OutlinePending>{} : pendingByUnit;

    final pendingTasks =
        sourceTasks.where((t) => !sourceCompleted.contains(t.id)).toList();
    final pendingTasksCount = pendingTasks.length;
    final coursesCount = units.length;
    final approvalCounts = computeApprovalCounts(
      sessions: sourceSessions,
      unitNotes: sourceUnitNotes,
      dismissedByUnit: dismissed,
      pendingByUnit: sourcePending,
    );
    final upcoming = _collectUpcomingItems(
      tasks: sourceTasks,
      completed: sourceCompleted,
      metaMap: metaMap,
      unitNotes: sourceUnitNotes,
      units: units,
    );
    final recentSessions = [...sourceSessions]
      ..sort((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    final recent = recentSessions.take(3).toList();
    final readyCount = sourceSessions
        .where((s) => s.status.toLowerCase() == 'ready')
        .length;
    final alertCount =
        readyCount > 0 ? readyCount : approvalCounts.total;
    final hasAlert = alertCount > 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'WELCOME',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  key: widget.profileKey,
                  onTap: () => _openMenu(context, ref),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(
                      Icons.menu,
                      size: 22,
                      color: AppColors.subtext,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: widget.uploadKey,
                  onTap: () async {
                    widget.onUploadTap?.call();
                    // ignore: use_build_context_synchronously
                    await _showOutlineUploadInfo(context, ref);
                    await _refreshUploadFlag();
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (widget.showStartHighlights || !_hasUploadedOutline)
                          ? AppColors.primarySoft
                          : Colors.white,
                      border: Border.all(
                        color: (widget.showStartHighlights || !_hasUploadedOutline)
                            ? AppColors.primary
                            : AppColors.line,
                      ),
                      boxShadow: (widget.showStartHighlights || !_hasUploadedOutline)
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : const [],
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      size: 22,
                      color: AppColors.subtext,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: widget.notificationsKey,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAlert ? AppColors.primarySoft : Colors.white,
                      border: Border.all(
                        color: hasAlert ? AppColors.primary : AppColors.line,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            hasAlert
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            size: 22,
                            color: hasAlert
                                ? AppColors.primary
                                : AppColors.subtext,
                          ),
                        ),
                        if (hasAlert)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                alertCount > 9
                                    ? '9+'
                                    : alertCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Knowledge / Tasks cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'KNOWLEDGE',
                    value: coursesCount.toString(),
                    subtitle: 'Courses in Notebook',
                    background: AppColors.primarySoft,
                    titleColor: AppColors.primary,
                    onTap: () =>
                        ref.read(navIndexProvider.notifier).state = 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'STUDY TASKS',
                    value: pendingTasksCount.toString(),
                    subtitle: 'Action Required',
                    background: AppColors.surface,
                    titleColor: AppColors.text,
                    onTap: () =>
                        ref.read(navIndexProvider.notifier).state = 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // To-Do (empty state)
            const Text(
              'To-Do',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            pendingTasks.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'No tasks yet.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtext,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start recording or upload a course outline to add content.',
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
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        for (final task in pendingTasks.take(3))
                          _TodoRow(
                            text: _taskLabel(
                              task,
                              metaMap[task.id as String],
                            ),
                            done: sourceCompleted.contains(task.id),
                            onToggle: () => ref
                                .read(completedTasksProvider.notifier)
                                .toggle(task.id as String),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                ref.read(navIndexProvider.notifier).state = 2,
                            child: const Text('Review tasks'),
                          ),
                        ),
                      ],
                    ),
                  ),

            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Due Soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              _UpcomingSection(items: upcoming),
            ],

            const SizedBox(height: 28),

            // Recommend Syntra
              GestureDetector(
                onTap: () =>
                    ref.read(navIndexProvider.notifier).state = 4,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.primary),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ask Syntra',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Get quick summaries or study help',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.text,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Recent Activity (empty state)
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            recent.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'No recent activity yet.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtext,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start recording or upload a course outline to add content.',
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
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        for (final session in recent) ...[
                          _RecentSessionRow(
                            session: session,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SessionDetailScreen(session: session),
                                ),
                              );
                            },
                          ),
                          if (session != recent.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color background;
  final Color titleColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.background,
    required this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 156,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.subtext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showOutlineUploadInfo(
  BuildContext context,
  WidgetRef ref, {
  bool fromSignup = false,
}) async {
  await AppModal.show(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Upload Course Outline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fromSignup
                ? 'Add your course outlines now to auto-fill highlights, exams, and assignments.'
                : 'Upload a PDF/DOCX syllabus so Syntra can auto-fill highlights, exams, and assignments for your courses.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await showOutlineUploadFlow(context, ref);
              },
              child: Text(fromSignup ? 'Upload Outline' : 'Upload Now'),
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

class _TodoRow extends StatelessWidget {
  final String text;
  final bool done;
  final VoidCallback onToggle;

  const _TodoRow({
    required this.text,
    required this.done,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          InkResponse(
            onTap: onToggle,
            radius: 16,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.primary : AppColors.subtext,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.subtext : AppColors.text,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _taskLabel(dynamic task, TaskMeta? meta) {
  final raw = task.text?.toString() ?? '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Untitled task';
  final due = meta?.dueDate;
  if (due == null) return trimmed;
  return '$trimmed (due ${due.month}/${due.day})';
}

class _RecentSessionRow extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _RecentSessionRow({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _sessionStatusLabel(session.status);
    final date = session.createdAt;
    final dateLabel = date == null ? '' : formatSessionDate(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mic, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displaySessionTitle(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.subtext,
                    ),
                  ),
                ],
              ),
            ),
            if (dateLabel.isNotEmpty)
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.subtext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _sessionStatusLabel(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return 'Processing';
  if (value == 'ready') return 'Ready';
  if (value == 'recording') return 'Recording';
  if (value == 'processing') return 'Processing';
  return value[0].toUpperCase() + value.substring(1);
}


class _UpcomingItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color accent;

  const _UpcomingItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.accent,
  });
}

List<_UpcomingItem> _collectUpcomingItems({
  required List<dynamic> tasks,
  required Set<String> completed,
  required Map<String, TaskMeta> metaMap,
  required Map<String, UnitNotes> unitNotes,
  required List<dynamic> units,
  int limit = 6,
}) {
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));

  final unitTitleById = {
    for (final u in units) u.id as String: u.title as String,
  };

  final items = <_UpcomingItem>[];

  for (final t in tasks) {
    if (completed.contains(t.id)) continue;
    final meta = metaMap[t.id as String];
    final due = meta?.dueDate;
    if (due == null) continue;
    if (due.isBefore(now) || due.isAfter(cutoff)) continue;
    items.add(
      _UpcomingItem(
        title: t.text as String,
        subtitle: 'Task due',
        date: due,
        icon: Icons.task_alt,
        accent: AppColors.text,
      ),
    );
  }

  for (final entry in unitNotes.entries) {
    final unitId = entry.key;
    final notes = entry.value;
    final unitTitle = unitTitleById[unitId] ?? 'Unassigned';
    for (final e in notes.exams) {
      final date = e.date;
      if (date == null) continue;
      if (date.isBefore(now) || date.isAfter(cutoff)) continue;
      items.add(
        _UpcomingItem(
          title: e.text,
          subtitle: 'Exam - $unitTitle',
          date: date,
          icon: Icons.event_available,
          accent: AppColors.primary,
        ),
      );
    }
    for (final a in notes.assignments) {
      final date = a.date;
      if (date == null) continue;
      if (date.isBefore(now) || date.isAfter(cutoff)) continue;
      items.add(
        _UpcomingItem(
          title: a.text,
          subtitle: 'Assignment - $unitTitle',
          date: date,
          icon: Icons.assignment_outlined,
          accent: AppColors.primary,
        ),
      );
    }
  }

  items.sort((a, b) => a.date.compareTo(b.date));
  if (limit <= 0) return items;
  return items.take(limit).toList();
}

class _UpcomingSection extends StatelessWidget {
  final List<_UpcomingItem> items;

  const _UpcomingSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.date.month}/${item.date.day}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
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


class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
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
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.subtext,
                      fontSize: 12,
                    ),
                  ),
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


