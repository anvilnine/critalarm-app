import 'package:critalarm/core/format/number_format.dart';
import 'package:intl/intl.dart';

/// The time of day, the way the phone is set to show it.
///
/// With [is24Hour] the text is the padded 24-hour clock in every language
/// ("07:05", "19:05:09"). Without it the language writes its own 12-hour
/// form ("7:05 PM"). A language whose own short time is a 24-hour one
/// (German, Japanese in this intl version) gets a 12-hour form of its
/// own order, because the phone asked for 12 hours: "7:05 PM", "午後7:05".
///
/// Where a widget has a context, pass `MediaQuery.alwaysUse24HourFormatOf`.
/// Anywhere else, pass the platform's own setting in. Callers own time-zone
/// conversion; this formats the supplied moment as it is.
///
/// An explicit [locale] supports pure formatter tests.
String formatClock(
  DateTime at, {
  required bool is24Hour,
  bool withSeconds = false,
  String? locale,
}) {
  final resolved = currentFormatLocale(locale);
  if (is24Hour) {
    return DateFormat(withSeconds ? 'HH:mm:ss' : 'HH:mm', resolved).format(at);
  }
  final own = withSeconds ? DateFormat.jms(resolved) : DateFormat.jm(resolved);
  // `H` and `k` are 24-hour fields. A language that has none is already 12.
  final pattern = own.pattern ?? '';
  if (!pattern.contains(RegExp('[Hk]'))) return own.format(at);
  // Japanese and Chinese write the marker first and close up to the hour.
  // Japanese counts the hour from 0, so just past midnight is 午前0:05 and
  // just past noon is 午後0:05. Chinese counts from 12, as CLDR has it.
  final String fallback;
  if (resolved.startsWith('ja')) {
    fallback = withSeconds ? 'aK:mm:ss' : 'aK:mm';
  } else if (resolved.startsWith('zh')) {
    fallback = withSeconds ? 'ah:mm:ss' : 'ah:mm';
  } else {
    fallback = withSeconds ? 'h:mm:ss a' : 'h:mm a';
  }
  return DateFormat(fallback, resolved).format(at);
}

/// A time given as minutes from local midnight (07:00 is 420), shown with
/// [formatClock]. Values past a day wrap, so 1500 reads as 01:00.
String formatMinuteOfDay(
  int minutes, {
  required bool is24Hour,
  String? locale,
}) => formatClock(
  DateTime(2000, 1, 1, 0, minutes),
  is24Hour: is24Hour,
  locale: locale,
);
