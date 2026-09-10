/// Motion duration tokens (named AppDurations — material already exports
/// a `Durations` class).
///
/// Motion is mechanical and snappy: micro-interactions stay in the
/// 100–250ms band, nothing decorative runs past [slow]. Enter ease-out, exit
/// ease-in, no bounce/elastic.
abstract final class AppDurations {
  /// Pressed-state dip on plates/buttons — near-instant mechanical response.
  static const Duration tap = Duration(milliseconds: 120);

  static const Duration fast = Duration(milliseconds: 150);

  /// Elements entering the frame (fades, appear, count-swaps): ease-out.
  static const Duration enter = Duration(milliseconds: 200);

  static const Duration medium = Duration(milliseconds: 250);

  /// Elements leaving the frame: ease-in, a touch quicker than [enter].
  static const Duration exit = Duration(milliseconds: 150);

  static const Duration slow = Duration(milliseconds: 400);
}
