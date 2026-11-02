import 'package:critalarm/core/format/number_format.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// "Rings for 30 min, every 30 s, until you're up."
///
/// Built from the topic's `max_ring_s` and `repeat_interval_s`. Null when
/// either is unknown or not above zero, so the screen draws nothing rather
/// than a wrong number.
String? topicRingLengthLine({
  required int? maxRingS,
  required int? repeatIntervalS,
}) {
  if (maxRingS == null || repeatIntervalS == null) return null;
  if (maxRingS <= 0 || repeatIntervalS <= 0) return null;
  return LocaleKeys.topic_hero_ring_length.tr(
    namedArgs: {
      'total': ringSpanText(maxRingS),
      'every': ringSpanText(repeatIntervalS),
    },
  );
}

/// A whole number of seconds as "45 s", "1 min 30 s", "30 min", "2 h" or
/// "1 h 30 min". Seconds are shown up to an hour and dropped from then on.
String ringSpanText(int seconds) {
  if (seconds < 60) {
    return LocaleKeys.dart_format_seconds.tr(
      namedArgs: {'seconds': formatInt(seconds)},
    );
  }
  final minutes = (seconds % 3600) ~/ 60;
  if (seconds < 3600) {
    final rest = seconds % 60;
    return rest == 0
        ? LocaleKeys.dart_format_minutes.tr(
            namedArgs: {'minutes': formatInt(minutes)},
          )
        : LocaleKeys.dart_format_minutes_seconds.tr(
            namedArgs: {
              'minutes': formatInt(minutes),
              'seconds': formatInt(rest),
            },
          );
  }
  final hours = seconds ~/ 3600;
  return minutes == 0
      ? LocaleKeys.dart_format_hours.tr(namedArgs: {'hours': formatInt(hours)})
      : LocaleKeys.dart_format_hours_minutes.tr(
          namedArgs: {'hours': formatInt(hours), 'minutes': formatInt(minutes)},
        );
}
