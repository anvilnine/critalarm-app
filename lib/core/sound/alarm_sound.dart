import 'package:freezed_annotation/freezed_annotation.dart';

part 'alarm_sound.freezed.dart';
part 'alarm_sound.g.dart';

/// Where a sound came from.
enum AlarmSoundSource {
  /// Ships inside the app. On every install, and cannot be deleted.
  bundled,

  /// The user picked an audio file off their own device.
  user,
}

/// A `Duration` is milliseconds on disk and a `Duration` in Dart.
class DurationMsConverter implements JsonConverter<Duration, int> {
  const DurationMsConverter();

  @override
  Duration fromJson(int json) => Duration(milliseconds: json);

  @override
  int toJson(Duration object) => object.inMilliseconds;
}

/// One alarm sound the user can pick.
///
/// The mapping from topic to sound stays on the device. It is never sent to
/// the server and it is not part of the contract in `docs/api.md`.
@freezed
abstract class AlarmSound with _$AlarmSound {
  const factory AlarmSound({
    /// Stable key. It is what gets stored against a topic, so renaming a
    /// sound must never change it.
    required String id,
    required String name,
    required AlarmSoundSource source,

    /// Bundled: the asset key, for example `assets/sounds/pager_beep.mp3`.
    /// User: an absolute path inside the app's own sound folder.
    required String path,
    @DurationMsConverter() required Duration duration,

    /// Loudness of the sound in even slices, 0 to 1, for the waveform on its
    /// row. Null on sounds saved before waveforms existed, until the picker
    /// fills them in.
    List<double>? peaks,
  }) = _AlarmSound;

  factory AlarmSound.fromJson(Map<String, dynamic> json) =>
      _$AlarmSoundFromJson(json);
}
