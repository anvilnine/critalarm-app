import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:intl/intl.dart';

String formatDebugPushEventDetails(
  DebugPushEvent event, {
  DateTime? now,
}) {
  final time = _dateText(event.at, now ?? DateTime.now());
  final parameters = Map<String, Object?>.of(event.values)
    ..removeWhere(
      (key, _) =>
          key == 'name' ||
          key == 'at' ||
          key == 'time' ||
          key == 'timestamp' ||
          key == 'at_ms',
    );
  if (parameters.isEmpty) return time;
  return '$time · ${const JsonEncoder().convert(parameters)}';
}

String _dateText(DateTime? time, DateTime now) {
  if (time == null) return '—';
  final local = time.toLocal();
  final difference = local.difference(now.toLocal());
  final absolute = DateFormat.yMMMd().add_jm().format(local);
  final duration = difference.abs();
  final relative = duration.inDays > 0
      ? '${duration.inDays}d'
      : duration.inHours > 0
      ? '${duration.inHours}h'
      : '${duration.inMinutes}m';
  final when = difference.isNegative ? '$relative ago' : 'in $relative';
  return '$absolute · $when';
}
