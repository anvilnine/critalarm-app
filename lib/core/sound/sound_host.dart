import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:flutter/services.dart';

/// What this platform can do with a sound the user brought in themselves.
class SoundCapabilities {
  const SoundCapabilities({
    required this.userSoundsRingAlarm,
    required this.bundledSoundsRingAlarm,
  });

  factory SoundCapabilities.fromMap(Map<Object?, Object?>? raw) =>
      SoundCapabilities(
        userSoundsRingAlarm: raw?['user_sounds_ring_alarm'] as bool? ?? true,
        bundledSoundsRingAlarm:
            raw?['bundled_sounds_ring_alarm'] as bool? ?? true,
      );

  /// False on iOS when the alarm API only reads sounds compiled into the app.
  /// The picker says "notifications only" next to user sounds when this is
  /// false. `docs/specs/remote-alarm-ios-spike.md` has the measurement.
  final bool userSoundsRingAlarm;

  /// False when even the bundled eight cannot reach the alarm API, which is
  /// the same question for the same reason.
  final bool bundledSoundsRingAlarm;

  /// Android does everything. So does anything with no handler on the
  /// channel, since nothing there restricts a sound file.
  static const permissive = SoundCapabilities(
    userSoundsRingAlarm: true,
    bundledSoundsRingAlarm: true,
  );
}

/// One file the platform copied into the app's own sound folder.
class ImportedSound {
  const ImportedSound({required this.path, required this.duration});

  final String path;
  final Duration duration;

  static ImportedSound? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final ms = raw['duration_ms'];
    if (path is! String || path.isEmpty) return null;
    if (ms is! int || ms <= 0) return null;
    return ImportedSound(
      path: path,
      duration: Duration(milliseconds: ms),
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
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.critalarm/sound';

  final MethodChannel _channel;

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

  Future<bool> stopPreview() async =>
      await _invoke<bool>('stopPreview') ?? false;

  /// How long a file the user picked runs for. Zero when nothing could read
  /// it, which the import check turns into "unreadable".
  Future<Duration> probeDuration(String path) async {
    final ms = await _invoke<int>('probeDuration', {'path': path});
    return Duration(milliseconds: ms == null || ms < 0 ? 0 : ms);
  }

  /// Copies [sourcePath] into the app's sound folder under [id], converting
  /// it to the platform's format if it is not already usable. On iOS it also
  /// lands in `Library/Sounds` so `UNNotificationSound(named:)` can find it.
  Future<ImportedSound?> importSound({
    required String sourcePath,
    required String id,
  }) async => ImportedSound.fromMap(
    await _invoke<Map<Object?, Object?>>('importSound', {
      'source_path': sourcePath,
      'id': id,
    }),
  );

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
