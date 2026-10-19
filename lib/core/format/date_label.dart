import 'package:critalarm/core/format/number_format.dart';
import 'package:intl/intl.dart';

/// Calendar labels preserve the shipped English patterns. Other languages use
/// intl skeletons for their own order and punctuation. Callers own time-zone
/// conversion; this helper formats the supplied moment without converting it.
///
/// Resolve the locale on every call, including the safe English fallback before
/// date symbols load. An explicit locale is useful for pure formatter tests.
abstract final class DateLabel {
  static String dayMonth(
    DateTime at, {
    String? locale,
    bool withTime = false,
  }) => _format(
    at,
    withTime ? 'd MMM HH:mm' : 'd MMM',
    DateFormat.MMMd,
    locale: locale,
    withTime: withTime,
  );

  /// Search retains its existing month-first English label.
  static String monthDay(DateTime at, {String? locale}) =>
      _format(at, 'MMM d', DateFormat.MMMd, locale: locale);

  static String dayMonthYear(
    DateTime at, {
    String? locale,
    bool withTime = false,
  }) => _format(
    at,
    withTime ? 'd MMM y HH:mm' : 'd MMM y',
    DateFormat.yMMMd,
    locale: locale,
    withTime: withTime,
  );

  static String weekdayDayMonth(DateTime at, {String? locale}) =>
      _format(at, 'EEEE d MMMM', DateFormat.MMMMEEEEd, locale: locale);

  static String weekdayDayMonthYear(DateTime at, {String? locale}) =>
      _format(at, 'EEEE d MMMM y', DateFormat.yMMMMEEEEd, locale: locale);

  static String shortWeekdayDayMonth(
    DateTime at, {
    String? locale,
    bool withTime = false,
  }) => _format(
    at,
    withTime ? 'EEE d MMM, HH:mm' : 'EEE, d MMM',
    DateFormat.MMMEd,
    locale: locale,
    withTime: withTime,
  );

  static String _format(
    DateTime at,
    String englishPattern,
    DateFormat Function(String) skeleton, {
    String? locale,
    bool withTime = false,
  }) {
    final resolved = currentFormatLocale(locale);
    final isEnglish = resolved == 'en' || resolved.startsWith('en_');
    if (isEnglish) return DateFormat(englishPattern, resolved).format(at);
    final format = skeleton(resolved);
    if (withTime) format.add_Hm();
    return format.format(at);
  }
}
