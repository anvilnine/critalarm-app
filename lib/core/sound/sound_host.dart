import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:flutter/services.dart';

/// What this platform can do with a sound the user brought in themselves.
class SoundCapabilities {
  const SoundCapabilities({
    required this.userSoundsRingAlarm,
    required this.bundledSoundsRingAlarm,
    this.canImportSounds = false,
  });

  factory SoundCapabilities.fromMap(Map<Object?, Object?>? raw) =>
      SoundCapabilities(
        userSoundsRingAlarm: raw?['user_sounds_ring_alarm'] as bool? ?? true,
        bundledSoundsRingAlarm:
            raw?['bundled_sounds_ring_alarm'] as bool? ?? true,
        canImportSounds: raw?['can_import_sounds'] as bool? ?? false,
      );

  /// False on iOS when the alarm API only reads sounds compiled into the app.
  /// The picker says "notifications only" next to user sounds when this is
  /// false. `docs/specs/remote-alarm-ios-spike.md` has the measurement.
  final bool userSoundsRingAlarm;

  /// False when even the bundled eight cannot reach the alarm API, which is
  /// the same question for the same reason.
  final bool bundledSoundsRingAlarm;

  /// True when the platform can copy a file the user picked into the app.
  /// iOS and Android say so. Anything with no handler, the web included,
  /// cannot, so "Pick a file" is hidden there.
  final bool canImportSounds;

  /// Android does everything. So does anything with no handler on the
  /// channel, since nothing there restricts a sound file.
  static const permissive = SoundCapabilities(
    userSoundsRingAlarm: true,
    bundledSoundsRingAlarm: true,
  );
}

/// One file the platform copied into the app's own sound folder.
class ImportedSound {
  const ImportedSound({
    required this.path,
    required this.duration,
    this.sizeBytes,
  });

  final String path;
  final Duration duration;

  /// Size of the saved file. Null when the platform did not say.
  final int? sizeBytes;

  static ImportedSound? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final ms = raw['duration_ms'];
    if (path is! String || path.isEmpty) return null;
    if (ms is! int || ms <= 0) return null;
    final size = raw['size_bytes'];
    return ImportedSound(
      path: path,
      duration: Duration(milliseconds: ms),
      sizeBytes: size is int ? size : null,
    );
  }
}

/// The native half of the sound library.
///
/// Android plays previews on the alarm stream (`USAGE_ALARM`) at whatever the
/// alarm volume is set to, so what the picker plays is what the alarm will
/// sound like. iOS plays through an `AVAudioSession` on the same category the
/// alarm uses.
///
/// Every call is safe off a real device: with no handler on the channel the
/// platform answers [MissingPluginException] and this hands back a default.
final class SoundHost {
  SoundHost([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'app.critalarm/sound';

  final MethodChannel _channel;
  final _previewEnded = StreamController<String>.broadcast();

  /// The path of a preview that stopped on its own: it played to the end, or
  /// a call or another app took the audio. Not fired for [stopPreview]. The
  /// path is the one [startPreview] was given, so a late event for an older
  /// preview can be told apart from the one playing now.
  Stream<String> get previewEnded => _previewEnded.stream;

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'previewEnded') {
      final args = call.arguments;
      final path = args is Map ? args['path'] : null;
      _previewEnded.add(path is String ? path : '');
    }
    return null;
  }

  /// Copies the eight bundled sounds where the OS alarm and notification APIs
  /// can find them by name. Safe to call on every launch.
  Future<bool> prepareBundledSounds(List<AlarmSound> sounds) async =>
      await _invoke<bool>('prepareBundledSounds', {
        'assets': [for (final s in sounds) s.path],
      }) ??
      false;

  Future<SoundCapabilities> capabilities() async => SoundCapabilities.fromMap(
    await _invoke<Map<Object?, Object?>>('capabilities'),
  );

  /// Starts the preview, replacing anything already playing. One loop only,
  /// so the picker does not ring forever if the user walks away.
  Future<bool> startPreview(AlarmSound sound) async =>
      await _invoke<bool>('startPreview', {
        'path': sound.path,
        'is_asset': sound.source == AlarmSoundSource.bundled,
      }) ??
      false;

  /// Plays [start] to [end] of a file that is not saved yet, such as the one
  /// open in the cropper. Stops by itself at [end].
  Future<bool> startClipPreview({
    required String path,
    required Duration start,
    required Duration end,
  }) async =>
      await _invoke<bool>('startPreview', {
        'path': path,
        'is_asset': false,
        'start_ms': start.inMilliseconds,
        'end_ms': end.inMilliseconds,
      }) ??
      false;

  Future<bool> stopPreview() async =>
      await _invoke<bool>('stopPreview') ?? false;

  /// How long a file the user picked runs for. Zero when nothing could read
  /// it, which the import check turns into "unreadable".
  Future<Duration> probeDuration(String path) async {
    final ms = await _invoke<int>('probeDuration', {'path': path});
    return Duration(milliseconds: ms == null || ms < 0 ? 0 : ms);
  }

  /// Cuts [start] to [end] out of [sourcePath] and saves it in the app's
  /// sound folder under [id], with a short fade at each end. iOS writes a caf
  /// into `Library/Sounds` so `UNNotificationSound(named:)` can find it.
  /// Android writes a mono wav.
  Future<ImportedSound?> importSound({
    required String sourcePath,
    required String id,
    required Duration start,
    required Duration end,
  }) async => ImportedSound.fromMap(
    await _invoke<Map<Object?, Object?>>('importSound', {
      'source_path': sourcePath,
      'id': id,
      'start_ms': start.inMilliseconds,
      'end_ms': end.inMilliseconds,
    }),
  );

  /// How loud [path] is across [count] even slices, each 0 to 1 with the
  /// loudest slice at 1. Empty when nothing could read the file.
  ///
  /// A read given a [cancelToken] stops early, with an empty answer, once
  /// [cancelPeaks] is called with the same token.
  Future<List<double>> readPeaks({
    required String path,
    required bool isAsset,
    required int count,
    String? cancelToken,
  }) async {
    final raw = await _invoke<Object?>('readPeaks', {
      'path': path,
      'is_asset': isAsset,
      'count': count,
      'token': ?cancelToken,
    });
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is num) value.toDouble().clamp(0.0, 1.0),
    ];
  }

  /// Stops a [readPeaks] started with [token], if it is still running.
  Future<void> cancelPeaks(String token) =>
      _invoke<Object?>('cancelPeaks', {'token': token});

  Future<bool> deleteSound(String path) async =>
      await _invoke<bool>('deleteSound', {'path': path}) ?? false;

  /// Hands the current default and per-topic choices to whatever plays the
  /// sound when a push arrives. On iOS that is the notification service
  /// extension, which runs in its own process and cannot read the app's
  /// preferences. Call it after every change to the choices or the files.
  Future<bool> publishSoundAssignments() async =>
      await _invoke<bool>('publishSoundAssignments') ?? false;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
