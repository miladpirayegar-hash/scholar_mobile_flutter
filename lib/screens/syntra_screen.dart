import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/session.dart';
import '../providers/sessions_provider.dart';
import '../providers/syntra_chat_provider.dart';
import '../providers/tasks_providers.dart';
import '../providers/task_meta_provider.dart';
import '../features/tasks/models/manual_task.dart';
import '../providers/units_provider.dart';
import '../providers/course_files_provider.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/outline_pending_provider.dart';

class SyntraScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  final String? initialSessionId;

  const SyntraScreen({
    super.key,
    this.initialMessage,
    this.initialSessionId,
  });

  @override
  ConsumerState<SyntraScreen> createState() => _SyntraScreenState();
}

class _SyntraScreenState extends ConsumerState<SyntraScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _useLatestSession = false;
  String? _overrideSessionId;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _controller.text = widget.initialMessage!;
    }
    if (widget.initialSessionId != null) {
      _overrideSessionId = widget.initialSessionId!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _sendCurrentMessage();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final chatState = ref.watch(syntraChatProvider);
    final rawChat =
        chatState.currentThread?.messages ?? const <SyntraMessage>[];
    final hasUserMessage = rawChat.any((m) => m.isUser);
    final hasEverChatted = chatState.threads
        .any((t) => t.messages.any((m) => m.isUser));
    final chat = hasUserMessage ? rawChat : const <SyntraMessage>[];
    final isSending = rawChat.isNotEmpty && rawChat.last.isStreaming;

    final scope = FocusScope.of(context);
    return PopScope(
      canPop: !scope.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final currentScope = FocusScope.of(context);
        if (currentScope.hasFocus) {
          currentScope.unfocus();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SyntraHeader(
                  onNewChat: () {
                    ref.read(syntraChatProvider.notifier).newThread();
                  },
                  onHistory: () {
                    _showHistorySheet(context, chatState.threads);
                  },
                ),
                const SizedBox(height: 18),
                _ContextToggle(
                  enabled: _useLatestSession,
                  onChanged: (v) => setState(() => _useLatestSession = v),
                  hasSessions: sessions.isNotEmpty,
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'SYNTRA CHAT',
                  trailing: 'Ready',
                ),
                const SizedBox(height: 12),
                if (!hasEverChatted)
                  const _SyntraEmptyState()
                else
                  for (final msg in chat) ...[
                    _ChatBubble(
                      isUser: msg.isUser,
                      text: msg.text,
                      isStreaming: msg.isStreaming,
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 16),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canSend =
                        value.text.trim().isNotEmpty && !isSending;
                    return _ChatComposer(
                      controller: _controller,
                      onSend: canSend
                          ? () async {
                              await _sendCurrentMessage();
                            }
                          : null,
                      isSending: isSending,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendCurrentMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final sessionIds = <String>[];
    if (_overrideSessionId != null) {
      sessionIds.add(_overrideSessionId!);
      _overrideSessionId = null;
    } else if (_useLatestSession) {
      final latest = _latestSessionId(ref.read(sessionsProvider));
      if (latest != null) sessionIds.add(latest);
    }

    final tasks = ref.read(tasksProvider);
    final completed = ref.read(completedTasksProvider);
    final metaMap = ref.read(taskMetaProvider);
    final sessions = ref.read(sessionsProvider);
    final units = ref.read(unitsProvider);
    final courseFiles = ref.read(courseFilesProvider);
    final unitNotes = ref.read(unitNotesProvider);
    final pendingByUnit = ref.read(outlinePendingProvider);
    final context = _buildTasksContext(
      tasks: tasks,
      completed: completed,
      metaMap: metaMap,
      sessions: sessions,
      units: units,
      courseFiles: courseFiles,
      unitNotes: unitNotes,
      pendingByUnit: pendingByUnit,
    );

    await ref.read(syntraChatProvider.notifier).send(
          message: text,
          context: context,
          sessionIds: sessionIds,
        );
  }

  String _buildTasksContext({
    required List<dynamic> tasks,
    required Set<String> completed,
    required Map<String, TaskMeta> metaMap,
    required List<Session> sessions,
    required List<dynamic> units,
    required Map<String, List<CourseFile>> courseFiles,
    required Map<String, UnitNotes> unitNotes,
    required Map<String, OutlinePending> pendingByUnit,
  }) {
    final incomplete =
        tasks.where((t) => !completed.contains(t.id)).toList();

    final sessionById = {for (final s in sessions) s.id: s};
    final unitTitleById = {
      for (final u in units) u.id as String: u.title as String,
    };

    final buffer = StringBuffer();
    if (incomplete.isNotEmpty) {
      buffer.writeln('Open tasks:');
      for (final task in incomplete.take(8)) {
        final id = task.id as String;
        final meta = metaMap[id];
        final sessionId = task is ManualTask
            ? task.sessionId
            : task is StudyTask
                ? task.sessionId
                : null;
        final session = sessionId != null ? sessionById[sessionId] : null;
        final unitId = (session == null ||
                session.eventId == null ||
                session.eventId!.isEmpty)
            ? 'general'
            : session.eventId!;
        final unitTitle = unitTitleById[unitId] ?? 'Unassigned';

        final due = meta?.dueDate;
        final dueLabel = due == null
            ? ''
            : ' (due ${due.month}/${due.day}/${due.year})';
        final priority = meta != null && meta.priority.isNotEmpty
            ? ' (${meta.priority} priority)'
            : '';

        buffer.writeln('- [$unitTitle] ${task.text}$dueLabel$priority');
      }
    }

    if (courseFiles.isNotEmpty) {
      buffer.writeln('Course materials available:');
      for (final entry in courseFiles.entries) {
        final unitTitle = unitTitleById[entry.key] ?? 'Course';
        final names = entry.value.map((f) => f.name).toList();
        if (names.isEmpty) continue;
        buffer.writeln('- $unitTitle: ${names.join(", ")}');
      }
    }

    final exams = <String>[];
    final assignments = <String>[];
    for (final entry in unitNotes.entries) {
      final unitTitle = unitTitleById[entry.key] ?? 'Course';
      for (final e in entry.value.exams.take(8)) {
        final date = e.date == null
            ? 'date missing'
            : '${e.date!.month}/${e.date!.day}/${e.date!.year}';
        exams.add('[$unitTitle] ${e.text} ($date)');
      }
      for (final a in entry.value.assignments.take(8)) {
        final date = a.date == null
            ? 'date missing'
            : '${a.date!.month}/${a.date!.day}/${a.date!.year}';
        assignments.add('[$unitTitle] ${a.text} ($date)');
      }
    }
    if (exams.isNotEmpty) {
      buffer.writeln('Known exams:');
      for (final e in exams.take(10)) {
        buffer.writeln('- $e');
      }
    }
    if (assignments.isNotEmpty) {
      buffer.writeln('Known assignments:');
      for (final a in assignments.take(10)) {
        buffer.writeln('- $a');
      }
    }

    final pendingExams = <String>[];
    final pendingAssignments = <String>[];
    for (final entry in pendingByUnit.entries) {
      final unitTitle = unitTitleById[entry.key] ?? 'Course';
      for (final e in entry.value.exams.take(8)) {
        final date = e.date == null
            ? 'date missing'
            : '${e.date!.month}/${e.date!.day}/${e.date!.year}';
        pendingExams.add('[$unitTitle] ${e.text} ($date)');
      }
      for (final a in entry.value.assignments.take(8)) {
        final date = a.date == null
            ? 'date missing'
            : '${a.date!.month}/${a.date!.day}/${a.date!.year}';
        pendingAssignments.add('[$unitTitle] ${a.text} ($date)');
      }
    }
    if (pendingExams.isNotEmpty || pendingAssignments.isNotEmpty) {
      buffer.writeln('Pending approval items from outline import:');
      for (final e in pendingExams.take(10)) {
        buffer.writeln('- Exam: $e');
      }
      for (final a in pendingAssignments.take(10)) {
        buffer.writeln('- Assignment: $a');
      }
    }

    if (buffer.isEmpty) return '';
    return buffer.toString().trim();
  }

  String? _latestSessionId(List<Session> sessions) {
    if (sessions.isEmpty) return null;
    final sorted = [...sessions]
      ..sort((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    return sorted.first.id;
  }

  void _showHistorySheet(BuildContext context, List<SyntraThread> threads) {
    AppModal.show(
      context: context,
      builder: (_) {
        return _HistorySheet(
          threads: threads,
          onSelect: (id) {
            Navigator.of(context).pop();
            ref.read(syntraChatProvider.notifier).selectThread(id);
          },
          onRename: (id, title) =>
              ref.read(syntraChatProvider.notifier).renameThread(id, title),
          onDelete: (id) =>
              ref.read(syntraChatProvider.notifier).deleteThread(id),
        );
      },
    );
  }
}

class _SyntraHeader extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onHistory;

  const _SyntraHeader({
    required this.onNewChat,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Syntra',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            TextButton(
              onPressed: onHistory,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('History'),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: onNewChat,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('New chat'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your study copilot for insights and focus',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.subtext,
          ),
        ),
      ],
    );
  }
}


class _ContextToggle extends StatelessWidget {
  final bool enabled;
  final bool hasSessions;
  final ValueChanged<bool> onChanged;

  const _ContextToggle({
    required this.enabled,
    required this.onChanged,
    required this.hasSessions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.library_books_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use latest session as context',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: enabled && hasSessions,
            onChanged: hasSessions ? onChanged : null,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
          ),
        ],
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
        Text(
          trailing,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.subtext,
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final bool isStreaming;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isUser ? AppColors.primary : AppColors.surface;
    final fg = isUser ? Colors.white : AppColors.text;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final body = text.isEmpty && isStreaming ? 'Typing...' : text;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final bool isSending;

  const _ChatComposer({
    required this.controller,
    required this.onSend,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onSend != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ask Syntra anything...',
                hintStyle: GoogleFonts.manrope(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
              ),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled ? AppColors.text : AppColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyntraEmptyState extends StatelessWidget {
  const _SyntraEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, size: 26, color: AppColors.primary),
          SizedBox(height: 10),
          Text(
            'Start your first chat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
            Text(
              'Ask Syntra about your coursework, assignments, or study plan.',
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

class _EmptyState extends StatelessWidget {
  final String label;
  final IconData icon;

  const _EmptyState({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
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

class _HistorySheet extends StatelessWidget {
  final List<SyntraThread> threads;
  final ValueChanged<String> onSelect;
  final void Function(String id, String title) onRename;
  final ValueChanged<String> onDelete;

  const _HistorySheet({
    required this.threads,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...threads]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                'Chat history',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (sorted.isEmpty)
                const _EmptyState(
                  label: 'No chats yet.',
                  icon: Icons.chat_bubble_outline,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final thread = sorted[index];
                      return _HistoryTile(
                        thread: thread,
                        onTap: () => onSelect(thread.id),
                        onRename: (title) => onRename(thread.id, title),
                        onDelete: () => onDelete(thread.id),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
    final SyntraThread thread;
    final VoidCallback onTap;
    final ValueChanged<String> onRename;
    final VoidCallback onDelete;

  const _HistoryTile({
    required this.thread,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final preview = _threadPreview(thread);
    final count = thread.messages.length;
    final label = count == 1 ? 'message' : 'messages';
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary),
              ),
              child: Center(
                child: Text(
                  thread.title.isNotEmpty
                      ? thread.title.characters.first.toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          '$count $label',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtext,
                          ),
                        ),
                      ),
                      Text(
                        _formatThreadDate(thread.updatedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _showRenameDialog(
                      context: context,
                      initial: thread.title,
                      onSave: onRename,
                    );
                    break;
                  case 'delete':
                    _showDeleteDialog(
                      context: context,
                      title: thread.title,
                      onConfirm: onDelete,
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename'),
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
  }
}

void _showRenameDialog({
  required BuildContext context,
  required String initial,
  required ValueChanged<String> onSave,
}) {
  final controller = TextEditingController(text: initial);
  AppModal.show(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rename chat',
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
              hintText: 'Enter a chat title',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onSave(controller.text);
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

void _showDeleteDialog({
  required BuildContext context,
  required String title,
  required VoidCallback onConfirm,
}) {
  AppModal.show(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Delete chat?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '"$title" will be deleted from this device.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
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

String _threadPreview(SyntraThread thread) {
  if (thread.messages.isEmpty) return 'New chat';
  final last = thread.messages.lastWhere(
    (m) => m.text.trim().isNotEmpty,
    orElse: () => thread.messages.last,
  );
  final prefix = last.isUser ? 'You: ' : 'Syntra: ';
  return '$prefix${last.text.trim()}';
}

String _formatThreadDate(DateTime date) {
  final now = DateTime.now();
  final sameDay =
      now.year == date.year && now.month == date.month && now.day == date.day;
  if (sameDay) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${date.month}/${date.day}/${date.year}';
}


