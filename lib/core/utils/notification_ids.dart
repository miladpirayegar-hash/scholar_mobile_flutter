String insightsReadyId(String sessionId) => 'insights-ready:$sessionId';

String tasksPendingId(int count) => 'tasks-pending:$count';

String dueItemId({
  required String mode,
  required String title,
  required DateTime date,
}) {
  final normalized = title.trim().toLowerCase();
  return 'due:$mode:$normalized:${date.toIso8601String()}';
}
