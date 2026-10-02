import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// How a past alarm reads in a list. Shared so a search result for an alarm
/// says exactly what the History row for the same alarm says.

/// "6 min 02 s", or just "44 s" under a minute.
String formatRingDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;

  if (minutes <= 0) return '$seconds s';
  return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
}

/// "Rang 6 min 02 s. Acknowledged."
String historyMetaText(HistoryEntry entry) {
  final duration = formatRingDuration(entry.ringDuration ?? Duration.zero);
  final key = switch (entry.state) {
    IncidentState.acked => LocaleKeys.history_meta_acknowledged,
    IncidentState.closed => LocaleKeys.history_meta_resolved,
    IncidentState.expired => LocaleKeys.history_meta_expired,
    IncidentState.open => LocaleKeys.history_meta_open,
  };
  return key.tr(namedArgs: {'duration': duration});
}
