import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The part of a sound file the cropper keeps.
///
/// Pure numbers, so every rule (never shorter than [minLength], never longer
/// than [maxLength], never past either end of the file) is tested without a
/// screen. Every change rounds to a tenth of a second. The end of the file is
/// the one exception: it stays exact, so a clip can run to the very end.
@immutable
class CropWindow {
  const CropWindow({
    required this.start,
    required this.length,
    required this.fileLength,
    required this.maxLength,
    this.minLength = defaultMinLength,
  });

  /// The window the cropper opens with. A file that fits is selected whole.
  /// A longer one gets a window of [maxLength] over its loudest part, found
  /// from [peaks] (loudness in even slices across the whole file).
  factory CropWindow.initial({
    required Duration fileLength,
    required Duration maxLength,
    List<double> peaks = const [],
    Duration minLength = defaultMinLength,
  }) {
    if (fileLength <= maxLength) {
      return CropWindow(
        start: Duration.zero,
        length: fileLength,
        fileLength: fileLength,
        maxLength: maxLength,
        minLength: minLength,
      );
    }
    return CropWindow(
      start: loudestStart(peaks, fileLength: fileLength, length: maxLength),
      length: maxLength,
      fileLength: fileLength,
      maxLength: maxLength,
      minLength: minLength,
    ).clamp();
  }

  static const defaultMinLength = Duration(seconds: 1);

  final Duration start;
  final Duration length;
  final Duration fileLength;
  final Duration maxLength;
  final Duration minLength;

  Duration get end => start + length;

  /// True when the window is as long as it is allowed to be.
  bool get isAtMax => length >= _longest;

  /// A file shorter than [minLength] can only be kept whole.
  Duration get _shortest => minLength < fileLength ? minLength : fileLength;
  Duration get _longest => maxLength < fileLength ? maxLength : fileLength;

  /// Slides the whole window by [delta], keeping its length.
  CropWindow move(Duration delta) => _with(
    start: _clampDuration(
      _round(start + delta),
      Duration.zero,
      fileLength - length,
    ),
  );

  /// Slides the window so it is centred on [at], as far as the file allows.
  CropWindow centerOn(Duration at) =>
      move(at - Duration(microseconds: length.inMicroseconds ~/ 2) - start);

  /// Moves the start handle to [to]. The end stays where it is.
  CropWindow dragStart(Duration to) {
    final fixedEnd = end;
    final earliest = fixedEnd - _longest;
    final newStart = _clampDuration(
      _round(to),
      earliest > Duration.zero ? earliest : Duration.zero,
      fixedEnd - _shortest,
    );
    return _with(start: newStart, length: fixedEnd - newStart);
  }

  /// Moves the end handle to [to]. The start stays where it is.
  CropWindow dragEnd(Duration to) {
    final latest = start + _longest;
    final newEnd = _clampDuration(
      _round(to),
      start + _shortest,
      latest < fileLength ? latest : fileLength,
    );
    return _with(length: newEnd - start);
  }

  /// Pulls a window that breaks any rule back inside all of them.
  CropWindow clamp() {
    final newLength = _clampDuration(length, _shortest, _longest);
    final newStart = _clampDuration(
      start,
      Duration.zero,
      fileLength - newLength,
    );
    return _with(start: newStart, length: newLength);
  }

  /// Where a window of [length] starts to cover the loudest stretch of
  /// [peaks], which are spread evenly over [fileLength]. The earliest wins a
  /// tie. With no peaks it is the start of the file.
  static Duration loudestStart(
    List<double> peaks, {
    required Duration fileLength,
    required Duration length,
  }) {
    final count = peaks.length;
    if (count == 0 || fileLength <= Duration.zero) return Duration.zero;
    final span = math.max(
      1,
      math.min(
        count,
        (length.inMicroseconds / fileLength.inMicroseconds * count).round(),
      ),
    );
    var sum = 0.0;
    for (var i = 0; i < span; i++) {
      sum += peaks[i];
    }
    var best = sum;
    var bestIndex = 0;
    for (var i = 1; i + span <= count; i++) {
      sum += peaks[i + span - 1] - peaks[i - 1];
      if (sum > best + 1e-9) {
        best = sum;
        bestIndex = i;
      }
    }
    final at = Duration(
      microseconds: fileLength.inMicroseconds * bestIndex ~/ count,
    );
    final latest = fileLength - length;
    return _clampDuration(
      _round(at),
      Duration.zero,
      latest > Duration.zero ? latest : Duration.zero,
    );
  }

  CropWindow _with({Duration? start, Duration? length}) => CropWindow(
    start: start ?? this.start,
    length: length ?? this.length,
    fileLength: fileLength,
    maxLength: maxLength,
    minLength: minLength,
  );

  static Duration _round(Duration value) =>
      Duration(milliseconds: (value.inMicroseconds / 100000).round() * 100);

  static Duration _clampDuration(Duration value, Duration low, Duration high) {
    if (value < low) return low;
    if (value > high) return high;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is CropWindow &&
      other.start == start &&
      other.length == length &&
      other.fileLength == fileLength &&
      other.maxLength == maxLength &&
      other.minLength == minLength;

  @override
  int get hashCode =>
      Object.hash(start, length, fileLength, maxLength, minLength);
}

/// [count] bars for the stretch [from] to [to] of a sound, where 0 is the
/// start of the file and 1 the end. Each bar is the loudest of the [peaks]
/// it covers. Parts of the stretch outside the file are 0, which is how the
/// zoomed editor shows the edge of the file.
List<double> slicePeaks(
  List<double> peaks, {
  required double from,
  required double to,
  required int count,
}) {
  final total = peaks.length;
  if (total == 0 || count <= 0 || to <= from) return const [];
  final width = (to - from) / count;
  return [
    for (var k = 0; k < count; k++)
      _loudestIn(
        peaks,
        (from + k * width) * total,
        (from + (k + 1) * width) * total,
      ),
  ];
}

double _loudestIn(List<double> peaks, double a, double b) {
  const nudge = 1e-9;
  final total = peaks.length;
  if (b <= nudge || a >= total - nudge) return 0;
  final low = math.max(0, (a + nudge).floor());
  var high = math.min(total, (b - nudge).ceil());
  if (high <= low) high = math.min(total, low + 1);
  var loudest = 0.0;
  for (var i = low; i < high; i++) {
    if (peaks[i] > loudest) loudest = peaks[i];
  }
  return loudest;
}
