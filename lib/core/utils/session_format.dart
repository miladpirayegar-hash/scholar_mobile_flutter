import '../../models/session.dart';

String formatSessionDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String displaySessionTitle(Session session) {
  final base = session.title.isNotEmpty ? session.title : 'Session';
  final date = session.createdAt;
  if (date == null) return base;

  final local = date.toLocal();
  final suffix = formatSessionDate(local);
  if (session.title.isEmpty) {
    final time = _formatTime(local);
    return '$base $suffix $time';
  }
  if (base.contains(suffix)) return base;
  return '$base $suffix';
}

String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
