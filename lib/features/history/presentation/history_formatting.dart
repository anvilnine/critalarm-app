import 'package:critalarm/core/format/number_format.dart';
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

  if (minutes <= 0) {
    return LocaleKeys.dart_format_seconds.tr(
      namedArgs: {'seconds': formatInt(seconds)},
    );
  }
  return LocaleKeys.dart_format_minutes_seconds.tr(
    namedArgs: {
      'minutes': formatInt(minutes),
      'seconds': formatInt(seconds, minimumDigits: 2),
    },
  );
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

/// A ring time short enough for a big numeral: "11 s", "6 min" or
/// "1 h 5 min". Seconds are dropped from a minute on.
String formatCompactDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes <= 0) {
    return LocaleKeys.dart_format_seconds.tr(
      namedArgs: {'seconds': formatInt(duration.inSeconds)},
    );
  }
  if (totalMinutes < 60) {
    return LocaleKeys.dart_format_minutes.tr(
      namedArgs: {'minutes': formatInt(totalMinutes)},
    );
  }
  final hours = duration.inHours;
  final minutes = totalMinutes % 60;
  return minutes == 0
      ? LocaleKeys.dart_format_hours.tr(namedArgs: {'hours': formatInt(hours)})
      : LocaleKeys.dart_format_hours_minutes.tr(
          namedArgs: {'hours': formatInt(hours), 'minutes': formatInt(minutes)},
        );
}
