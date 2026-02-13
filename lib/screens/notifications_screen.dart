import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/sessions_provider.dart';
import '../providers/tasks_providers.dart';
import '../providers/task_meta_provider.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/unit_notes_ai_provider.dart';
import '../providers/outline_pending_provider.dart';
import '../providers/units_provider.dart';
import '../providers/notification_read_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../providers/nav_provider.dart';
import '../models/session.dart';
import 'session_detail_screen.dart';
import 'unit_detail_screen.dart';
import '../core/utils/approval_counts.dart';
import '../core/utils/notification_ids.dart';
import '../providers/user_prefs_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPrefsProvider);
    return _buildNotifications(
      context,
      ref,
      notificationsEnabled: prefs.notificationsEnabled,
    );
  }

  Widget _buildNotifications(
    BuildContext context,
    WidgetRef ref, {
    required bool notificationsEnabled,
  }) {
    if (!notificationsEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: const [
            _InfoCard(
              title: 'Notifications are turned off',
              subtitle: 'Enable notifications in Settings to see updates here.',
              icon: Icons.notifications_off_outlined,
            ),
          ],
        ),
      );
    }

    final sessions = ref.watch(sessionsProvider);
    final tasks = ref.watch(tasksProvider);
    final completed = ref.watch(completedTasksProvider);
    final metaMap = ref.watch(taskMetaProvider);
    final unitNotes = ref.watch(unitNotesProvider);
    final dismissed = ref.watch(unitNotesAiProvider);
    final pendingByUnit = ref.watch(outlinePendingProvider);
    final units = ref.watch(unitsProvider);
    final readIds = ref.watch(notificationReadProvider);
    final readController = ref.read(notificationReadProvider.notifier);
    final hideContent = ref.watch(contentVisibilityProvider);

    final List<Session> visibleSessions =
        hideContent ? const <Session>[] : sessions;
    final visibleTasks = hideContent ? const <dynamic>[] : tasks;
    final visibleCompleted = hideContent ? const <String>{} : completed;

    final approvalCounts = computeApprovalCounts(
      sessions: visibleSessions,
      unitNotes: unitNotes,
      dismissedByUnit: dismissed,
      pendingByUnit: pendingByUnit,
    );
    final unitTitleById = {
      for (final u in units) u.id: u.title,
    };

    final items = <_Notification>[];

    final ready = visibleSessions
        .where((s) => s.status.toLowerCase() == 'ready');
    _Notification? latestReadyNotification;
    if (ready.isNotEmpty) {
      final latest = ready.reduce((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.isAfter(db) ? a : b;
      });
      latestReadyNotification = _Notification(
        id: insightsReadyId(latest.id),
        title: 'Recording ready',
        subtitle: 'Processing complete for ${latest.title}.',
        icon: Icons.auto_awesome,
        time: _timeAgo(latest.createdAt),
        onTap: () {
          readController.markRead(insightsReadyId(latest.id));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(session: latest),
            ),
          );
        },
      );
      // If we show the ready banner, avoid duplicating it in the list items.
    }

    final pendingTasks = visibleTasks
        .where((t) => !visibleCompleted.contains(t.id))
        .toList();
    if (pendingTasks.isNotEmpty) {
      items.add(
        _Notification(
          id: tasksPendingId(pendingTasks.length),
          title: '${pendingTasks.length} tasks pending',
          subtitle: 'Stay on track with today\'s priorities.',
          icon: Icons.task_alt,
          time: 'Today',
          onTap: () {
            readController.markRead(tasksPendingId(pendingTasks.length));
            ref.read(tasksModeProvider.notifier).state = 'tasks';
            ref.read(navIndexProvider.notifier).state = 2;
            Navigator.of(context).pop();
          },
        ),
      );
    }

    final upcoming = _collectUpcomingAlerts(
      tasks: visibleTasks,
      completed: visibleCompleted,
      metaMap: metaMap,
      unitNotes: unitNotes,
      units: units,
    );
    for (final alert in upcoming.take(3)) {
      items.add(
        _Notification(
          id: alert.id,
          title: alert.title,
          subtitle: alert.subtitle,
          icon: alert.icon,
          time: _dateLabel(alert.date),
          onTap: () {
            readController.markRead(alert.id);
            if (alert.mode == 'exams' && alert.unitId != null) {
              final unitTitle =
                  unitTitleById[alert.unitId] ?? 'Course';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UnitDetailScreen(
                    unitTitle: unitTitle,
                    unitId: alert.unitId!,
                    initialTabIndex: 1,
                  ),
                ),
              );
              return;
            }
            ref.read(tasksModeProvider.notifier).state = alert.mode;
            ref.read(navIndexProvider.notifier).state = 2;
            Navigator.of(context).pop();
          },
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _Notification(
          id: 'empty',
          title: 'No notifications yet',
          subtitle: 'We\'ll surface updates as they arrive.',
          icon: Icons.notifications_none,
          time: '',
        ),
      );
    }

      final showApprovalSummary = approvalCounts.total > 0;
      final showUpcomingSummary = upcoming.isNotEmpty;
      final readyNotification = latestReadyNotification;
      final showReadyBanner = readyNotification != null;

      return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        itemCount: items.length +
            (showApprovalSummary ? 1 : 0) +
            (showUpcomingSummary ? 1 : 0) +
            (showReadyBanner ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          var headerCount = 0;
          if (showReadyBanner) {
            if (index == headerCount) {
              final ready = readyNotification;
              return _ReadyBannerCard(
                title: ready.title,
                subtitle: ready.subtitle,
                time: ready.time,
                onTap: ready.onTap ?? () {},
              );
            }
            headerCount++;
          }
          if (showApprovalSummary) {
            if (index == headerCount) {
              return _ApprovalSummaryCard(
                counts: approvalCounts,
                onTap: () {
                  final pendingUnitId = pendingByUnit.keys.isNotEmpty
                      ? pendingByUnit.keys.first
                      : null;
                  if (pendingUnitId != null) {
                    final unitTitle =
                        unitTitleById[pendingUnitId] ?? 'Course';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UnitDetailScreen(
                        unitTitle: unitTitle,
                        unitId: pendingUnitId,
                        initialTabIndex: 1,
                      ),
                    ),
                  );
                  return;
                }
                ref.read(tasksModeProvider.notifier).state = 'exams';
                ref.read(navIndexProvider.notifier).state = 2;
                Navigator.of(context).pop();
              },
            );
            }
            headerCount++;
          }
          if (showUpcomingSummary) {
            if (index == headerCount) {
              return _UpcomingSummaryCard(
                count: upcoming.length,
                nextThree: upcoming.take(3).toList(),
                onTap: () {
                  ref.read(tasksModeProvider.notifier).state = 'exams';
                  ref.read(navIndexProvider.notifier).state = 2;
                  Navigator.of(context).pop();
                },
              );
            }
            headerCount++;
          }

      final n = items[index - headerCount];
          final isRead = readIds.contains(n.id);
          return InkWell(
            onTap: n.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isRead ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      n.icon,
                      color: isRead ? AppColors.subtext : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isRead ? AppColors.subtext : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (n.time.isNotEmpty)
                    Text(
                      n.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtext,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReadyBannerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback onTap;

  const _ReadyBannerCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
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

class _UpcomingSummaryCard extends StatelessWidget {
  final int count;
  final List<_UpcomingAlert> nextThree;
  final VoidCallback onTap;

  const _UpcomingSummaryCard({
    required this.count,
    required this.nextThree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Upcoming items ($count)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in nextThree)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${item.title} • ${_dateLabel(item.date)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalSummaryCard extends StatelessWidget {
  final ApprovalCounts counts;
  final VoidCallback onTap;

  const _ApprovalSummaryCard({
    required this.counts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Needs Approval',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ApprovalChip(
                  label: 'Exams',
                  count: counts.exams,
                ),
                _ApprovalChip(
                  label: 'Assignments',
                  count: counts.assignments,
                ),
                _ApprovalChip(
                  label: 'Highlights',
                  count: counts.highlights,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.subtext),
          ),
          const SizedBox(width: 12),
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

class _ApprovalChip extends StatelessWidget {
  final String label;
  final int count;

  const _ApprovalChip({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final muted = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted ? AppColors.line : AppColors.primary,
        ),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: muted ? AppColors.subtext : Colors.white,
        ),
      ),
    );
  }
}

class _UpcomingAlert {
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final String mode; // tasks | exams
  final String? unitId;

  const _UpcomingAlert({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.mode,
    this.unitId,
  });
}

List<_UpcomingAlert> _collectUpcomingAlerts({
  required List<dynamic> tasks,
  required Set<String> completed,
  required Map<String, TaskMeta> metaMap,
  required Map<String, UnitNotes> unitNotes,
  required List<dynamic> units,
}) {
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));
  final unitTitleById = {
    for (final u in units) u.id as String: u.title as String,
  };

  final items = <_UpcomingAlert>[];

  for (final t in tasks) {
    if (completed.contains(t.id)) continue;
    final meta = metaMap[t.id as String];
    final due = meta?.dueDate;
    if (due == null || due.isBefore(now) || due.isAfter(cutoff)) continue;
        items.add(
          _UpcomingAlert(
            id: dueItemId(
              mode: 'tasks',
              title: t.text as String,
              date: due,
            ),
            title: t.text as String,
            subtitle: 'Task due',
            date: due,
            icon: Icons.task_alt,
            mode: 'tasks',
          ),
        );
  }

  for (final entry in unitNotes.entries) {
    final unitId = entry.key;
    final notes = entry.value;
    final unitTitle = unitTitleById[unitId] ?? 'Unassigned';
    for (final e in notes.exams) {
      final date = e.date;
      if (date == null || date.isBefore(now) || date.isAfter(cutoff)) continue;
        items.add(
          _UpcomingAlert(
            id: dueItemId(
              mode: 'exams',
              title: e.text,
              date: date,
            ),
            title: e.text,
            subtitle: 'Exam - $unitTitle',
            date: date,
            icon: Icons.event_available,
            mode: 'exams',
            unitId: unitId,
          ),
        );
      }
      for (final a in notes.assignments) {
        final date = a.date;
        if (date == null || date.isBefore(now) || date.isAfter(cutoff)) continue;
        items.add(
          _UpcomingAlert(
            id: dueItemId(
              mode: 'exams',
              title: a.text,
              date: date,
            ),
            title: a.text,
            subtitle: 'Assignment - $unitTitle',
            date: date,
            icon: Icons.assignment_outlined,
            mode: 'exams',
            unitId: unitId,
          ),
        );
      }
  }

  items.sort((a, b) => a.date.compareTo(b.date));
  return items;
}

String _timeAgo(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _dateLabel(DateTime? date) {
  if (date == null) return '';
  return '${date.month}/${date.day}/${date.year}';
}

class _Notification {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String time;
  final VoidCallback? onTap;

  const _Notification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.time,
    this.onTap,
  });
}


