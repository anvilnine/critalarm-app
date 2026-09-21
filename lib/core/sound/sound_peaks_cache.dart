import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';

/// Waveform peaks for the sounds that ship with the app, read once per launch.
///
/// The picker is created fresh every time it opens, so it cannot hold these
/// itself. User sounds keep their peaks on [AlarmSound.peaks] instead, since
/// those are saved to disk with the sound.
class SoundPeaksCache {
  SoundPeaksCache(this._host);

  /// How many bars a sound row draws.
  static const barCount = 48;

  final SoundHost _host;
  final _peaks = <String, List<double>>{};
  final _reading = <String, Future<List<double>>>{};

  /// What is already known for [soundId], or null.
  List<double>? cached(String soundId) => _peaks[soundId];

  /// Peaks for a bundled [sound]. Two callers asking at once share one read.
  /// An empty answer is not kept, so the next open tries again.
  Future<List<double>> load(AlarmSound sound) {
    final known = _peaks[sound.id];
    if (known != null) return Future.value(known);
    return _reading[sound.id] ??= _read(sound);
  }

  Future<List<double>> _read(AlarmSound sound) async {
    try {
      final peaks = await _host.readPeaks(
        path: sound.path,
        isAsset: sound.source == AlarmSoundSource.bundled,
        count: barCount,
      );
      if (peaks.isNotEmpty) _peaks[sound.id] = peaks;
      return peaks;
    } finally {
      // Dropped after the answer is stored, so a caller in between finds
      // one or the other. The future itself is already done here.
      unawaited(_reading.remove(sound.id));
    }
  }
}
