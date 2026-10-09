import 'dart:math' as math;

import 'package:critalarm/gen/locale_keys.g.dart';

// What the Sound page's wave and header say, with nothing drawn. Pure, so it
// is unit tested and the widgets only draw what they are handed.

/// How far apart the wave's bars sit, bar and gap together.
const double kSoundHeroBarPitch = 18;

/// The fewest and the most bars the wave draws.
const int kSoundHeroMinBars = 14;
const int kSoundHeroMaxBars = 40;

/// How tall the wave is on a phone, and on a display too short for that.
const double kSoundHeroHeight = 150;
const double kSoundHeroShortHeight = 96;

/// The wave's height for a display that is [isShort] or not.
double soundHeroHeightFor({required bool isShort}) =>
    isShort ? kSoundHeroShortHeight : kSoundHeroHeight;

/// How many bars fit a wave [width] points wide: one per
/// [kSoundHeroBarPitch], never fewer than 14 or more than 40.
int soundHeroBarCount(double width) => (width / kSoundHeroBarPitch)
    .floor()
    .clamp(kSoundHeroMinBars, kSoundHeroMaxBars);

/// The sound's peaks (0 to 1) as [count] bars.
///
/// With more peaks than bars each bar takes the loudest peak of its share, so
/// a sharp hit is not averaged away. With fewer, each bar takes the peak
/// under its middle, so a single peak makes a wave of one level. No peaks
/// give an empty list: the wave then draws flat bars and no playhead.
List<double> soundHeroBars(List<double>? peaks, int count) {
  if (peaks == null || peaks.isEmpty || count <= 0) return const [];
  final length = peaks.length;
  return [
    for (var i = 0; i < count; i++)
      () {
        final from = i * length / count;
        final to = (i + 1) * length / count;
        if (to - from <= 1) {
          final middle = ((from + to) / 2).floor().clamp(0, length - 1);
          return peaks[middle].clamp(0.0, 1.0);
        }
        var loudest = 0.0;
        final last = math.min(length, to.ceil());
        for (var p = from.floor(); p < last; p++) {
          loudest = math.max(loudest, peaks[p]);
        }
        return loudest.clamp(0.0, 1.0);
      }(),
  ];
}

/// How much of the wave the playhead has filled, 0 to 1, or null when no
/// preview plays and the wave is at rest.
double? soundHeroFill(double? progress) => progress?.clamp(0.0, 1.0);

/// Whether bar [index] of [count] is filled at [fill]. A bar fills once the
/// playhead has passed its middle, so 0 fills none and 1 fills all. With no
/// [fill] the wave is at rest and every bar is full.
bool soundHeroBarFilled(int index, int count, double? fill) {
  if (fill == null) return true;
  if (count <= 0) return false;
  return (index + 0.5) / count <= fill;
}

/// The key of the word after the dot in the header label while [isPlaying],
/// or null when nothing plays. The header shows "SOUND · PLAYING".
String? soundHeaderStateKey({required bool isPlaying}) =>
    isPlaying ? LocaleKeys.personalize_passes_sound_playing : null;
