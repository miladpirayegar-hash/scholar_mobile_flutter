import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../../../providers/sessions_provider.dart';

/// ----------------------------------------------------
/// Tasks provider (derived from session.insights map)
/// ----------------------------------------------------
final tasksProvider = Provider<List<StudyTask>>((ref) {
  final sessions = ref.watch(sessionsProvider);

  final List<StudyTask> tasks = [];

  for (final session in sessions) {
    final insights = session.insights;
    if (insights is! Map<String, dynamic>) continue;

    final rawItems = insights['actionItems'];
    final actionItems =
        (rawItems as List?)?.cast<String>() ?? const <String>[];

    for (var i = 0; i < actionItems.length; i++) {
      final text = actionItems[i].trim();
      if (text.isEmpty) continue;

      tasks.add(
        StudyTask(
          id: StudyTask.buildId(
            sessionId: session.id,
            index: i,
            text: text,
          ),
          sessionId: session.id,
          text: text,
          createdAt: session.createdAt ?? DateTime.now(),
        ),
      );
    }
  }

  // Newest sessions first
  tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return tasks;
});

/// ----------------------------------------------------
/// Local completion state (v1 only)
/// ----------------------------------------------------
final completedTasksProvider =
    StateNotifierProvider<CompletedTasksController, Set<String>>(
  (ref) => CompletedTasksController(),
);

class CompletedTasksController extends StateNotifier<Set<String>> {
  CompletedTasksController() : super(const {});

  bool isCompleted(String taskId) => state.contains(taskId);

  void toggle(String taskId) {
    final next = Set<String>.from(state);

    if (next.contains(taskId)) {
      next.remove(taskId);
    } else {
      next.add(taskId);
    }

    state = next;
  }
}
