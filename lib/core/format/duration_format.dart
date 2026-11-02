import 'package:critalarm/core/format/number_format.dart';
import 'package:intl/intl.dart';

/// A length of time as minutes and padded seconds ("0:07", "3:07"). The
/// minutes count on past an hour ("61:05"), and a negative length reads as
/// "0:00". Digits follow the active language.
///
/// Used for a sound's length, the recorder's timer and the card countdown.
/// "6 min 02 s" style text for a ring duration lives in `formatRingDuration`.
String formatMinutesSeconds(Duration d, {String? locale}) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final resolved = currentFormatLocale(locale);
  final minutes = NumberFormat('0', resolved).format(total ~/ 60);
  final seconds = NumberFormat('00', resolved).format(total % 60);
  return '$minutes:$seconds';
}
