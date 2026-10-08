import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How bright a person's own photo is, on a coarse grid.
///
/// It is measured once, when the photo is imported, and kept beside the
/// file. The alarm screen never measures anything: it reads these numbers
/// and nothing else about the photo.
///
/// Each cell holds two values, 0 to 255:
///
/// - [peaks]: the largest value red, green or blue takes in any pixel of
///   the cell.
/// - [lows]: the smallest.
///
/// These are per pixel, never an average, so a cell of fine noise is as
/// bright as its brightest dot. Every pixel of the cell is then no
/// brighter than a grey of the peak and no darker than a grey of the low,
/// which is what lets the scrim be chosen for certain
/// ([ownLookScrimFor]).
@immutable
class OwnPhotoMeasure {
  const OwnPhotoMeasure({
    required this.columns,
    required this.rows,
    required this.peaks,
    required this.lows,
  });

  /// The grid every photo is measured on. A cell is about the height of a
  /// line of text on a phone.
  static const int gridColumns = 8;
  static const int gridRows = 16;

  final int columns;
  final int rows;
  final List<int> peaks;
  final List<int> lows;

  /// The brightest value anywhere in the photo.
  int get brightest => peaks.reduce(math.max);

  /// The darkest value anywhere in the photo.
  int get darkest => lows.reduce(math.min);

  /// As text, for the preferences.
  String encode() => jsonEncode({
    'v': 1,
    'c': columns,
    'r': rows,
    'p': peaks,
    'l': lows,
  });

  /// Null for anything that is not a whole, sane measure: a missing list,
  /// a wrong length, a value out of range. A photo with no measure is not
  /// drawn.
  static OwnPhotoMeasure? decode(Object? saved) {
    try {
      final map = saved is String ? jsonDecode(saved) : saved;
      if (map is! Map<String, dynamic> || map['v'] != 1) return null;
      final columns = map['c'];
      final rows = map['r'];
      final peaks = map['p'];
      final lows = map['l'];
      if (columns is! int || rows is! int) return null;
      if (columns < 1 || rows < 1 || columns * rows > 4096) return null;
      if (peaks is! List || lows is! List) return null;
      if (peaks.length != columns * rows || lows.length != peaks.length) {
        return null;
      }
      final cells = <int>[];
      for (final value in [...peaks, ...lows]) {
        if (value is! int || value < 0 || value > 255) return null;
        cells.add(value);
      }
      for (var i = 0; i < peaks.length; i++) {
        if (cells[i] < cells[i + peaks.length]) return null;
      }
      return OwnPhotoMeasure(
        columns: columns,
        rows: rows,
        peaks: List<int>.unmodifiable(cells.sublist(0, peaks.length)),
        lows: List<int>.unmodifiable(cells.sublist(peaks.length)),
      );
    } on Object catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OwnPhotoMeasure &&
      other.columns == columns &&
      other.rows == rows &&
      listEquals(other.peaks, peaks) &&
      listEquals(other.lows, lows);

  @override
  int get hashCode =>
      Object.hash(columns, rows, Object.hashAll(peaks), Object.hashAll(lows));
}

/// Measures [rgba], the pixels of a photo [width] by [height], four bytes
/// a pixel with nothing see-through, on the standard grid.
///
/// Pure and linear in the number of pixels: one pass, no allocation per
/// pixel. A photo smaller than the grid in either direction gets a cell
/// per pixel there.
OwnPhotoMeasure measureOwnPhoto(Uint8List rgba, int width, int height) {
  if (width < 1 || height < 1 || rgba.length < width * height * 4) {
    throw ArgumentError('not a whole picture');
  }
  final columns = math.min(OwnPhotoMeasure.gridColumns, width);
  final rows = math.min(OwnPhotoMeasure.gridRows, height);
  final peaks = List<int>.filled(columns * rows, 0);
  final lows = List<int>.filled(columns * rows, 255);
  var at = 0;
  for (var y = 0; y < height; y++) {
    final rowStart = (y * rows ~/ height) * columns;
    for (var x = 0; x < width; x++) {
      final cell = rowStart + x * columns ~/ width;
      final r = rgba[at];
      final g = rgba[at + 1];
      final b = rgba[at + 2];
      at += 4;
      final high = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final low = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (high > peaks[cell]) peaks[cell] = high;
      if (low < lows[cell]) lows[cell] = low;
    }
  }
  return OwnPhotoMeasure(
    columns: columns,
    rows: rows,
    peaks: List<int>.unmodifiable(peaks),
    lows: List<int>.unmodifiable(lows),
  );
}

/// The contrast the scrim is built to give the words on the photo. Above
/// the 4.5 to 1 the alarm screen's contrast rule asks for, so rounding in
/// the drawing never brings a word under the rule.
const double ownLookScrimTarget = 5;

/// The lightest the scrim ever is, 0 to 255: 30 percent. A dark photo
/// needs none for the words to read, and still gets this much so the face
/// and the buttons stand off it.
const int ownLookMinScrim = 77;

/// What the drawing may add to a value through rounding, 0 to 255.
const int _roundingSlack = 1;

/// The scrim for one photo: how much of the photo is taken away, and the
/// range of greys that can then be behind a word.
@immutable
class OwnLookScrim {
  const OwnLookScrim({
    required this.alpha,
    required this.brightestBehind,
    required this.darkestBehind,
  });

  /// How strong the black over the photo is, 0 (none) to 255 (the photo
  /// is gone).
  final int alpha;

  /// No pixel of the photo under the scrim is brighter than a grey of
  /// this value, 0 to 255.
  final int brightestBehind;

  /// No pixel under the scrim is darker than a grey of this value.
  final int darkestBehind;

  /// What each value of the photo is multiplied by, 0 to 255, to draw it
  /// under the scrim: the same picture as black at [alpha] over it.
  int get keep => 255 - alpha;

  @override
  bool operator ==(Object other) =>
      other is OwnLookScrim &&
      other.alpha == alpha &&
      other.brightestBehind == brightestBehind &&
      other.darkestBehind == darkestBehind;

  @override
  int get hashCode => Object.hash(alpha, brightestBehind, darkestBehind);

  @override
  String toString() =>
      'scrim ${(alpha * 100 / 255).round()}% '
      '(behind the words: $darkestBehind to $brightestBehind of 255)';
}

/// The relative luminance of a grey of [value], 0 to 255 (WCAG 2).
double greyLuminance(int value) {
  final c = value / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// The contrast between two relative luminances (WCAG 2).
double luminanceContrast(double a, double b) {
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// The scrim for a photo measured as [measure], under words whose
/// relative luminance is [wordsLuminance] (light words: the own look's
/// are near white).
///
/// The rule, in full:
///
/// 1. Any cell of the photo can be behind a word: the list scrolls, a
///    tablet lays the screen out sideways, and the previews draw it at
///    other shapes. So the brightest cell of the whole photo decides.
/// 2. Under black at alpha `a`, a value `v` of the photo becomes at most
///    `ceil(v * (255 - a) / 255)`, plus one for rounding. Every pixel of
///    a cell is at most a grey of the cell's peak, so the whole photo
///    under the scrim is at most a grey of that number for the brightest
///    peak.
/// 3. The scrim is the lightest `a`, never under [ownLookMinScrim], for
///    which the words on that grey reach [target]. Light words on
///    anything darker read better still, so every pixel passes.
///
/// It never fails: at alpha 255 the photo is black and the words are at
/// their best.
OwnLookScrim ownLookScrimFor(
  OwnPhotoMeasure measure, {
  required double wordsLuminance,
  double target = ownLookScrimTarget,
}) {
  final peak = measure.brightest;
  final low = measure.darkest;
  int under(int value, int alpha) => (value * (255 - alpha) / 255).ceil();
  var alpha = ownLookMinScrim;
  while (alpha < 255) {
    final behind = math.min(255, under(peak, alpha) + _roundingSlack);
    if (luminanceContrast(wordsLuminance, greyLuminance(behind)) >= target) {
      break;
    }
    alpha++;
  }
  return OwnLookScrim(
    alpha: alpha,
    brightestBehind: math.min(255, under(peak, alpha) + _roundingSlack),
    darkestBehind: math.max(
      0,
      (low * (255 - alpha) / 255).floor() - _roundingSlack,
    ),
  );
}
