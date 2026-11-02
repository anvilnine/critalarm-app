import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:flutter/foundation.dart' show immutable, setEquals;

/// Which topics add a camera flash or a strong vibration to their ring.
///
/// Both are extras on top of the sound. Neither one replaces it, lowers it or
/// shortens the ring, and neither depends on a plan. They stay on this phone:
/// `docs/api.md` has no field for them and nothing here is sent to the server.
@immutable
class AlarmSignals {
  const AlarmSignals({
    this.flashTopics = const <String>{},
    this.vibrationTopics = const <String>{},
  });

  /// Topics whose ring also blinks the camera flash.
  final Set<String> flashTopics;

  /// Topics whose ring also runs the strong vibration pattern.
  final Set<String> vibrationTopics;

  /// Off unless the user turned it on for [topic].
  bool flashFor(String topic) => flashTopics.contains(topic);

  /// Off unless the user turned it on for [topic].
  bool vibrationFor(String topic) => vibrationTopics.contains(topic);

  AlarmSignals withFlash(String topic, {required bool on}) => AlarmSignals(
    flashTopics: _with(flashTopics, topic, on: on),
    vibrationTopics: vibrationTopics,
  );

  AlarmSignals withVibration(String topic, {required bool on}) => AlarmSignals(
    flashTopics: flashTopics,
    vibrationTopics: _with(vibrationTopics, topic, on: on),
  );

  static Set<String> _with(
    Set<String> topics,
    String topic, {
    required bool on,
  }) {
    if (topic.isEmpty) return topics;
    if (on) return {...topics, topic};
    return {
      for (final name in topics)
        if (name != topic) name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSignals &&
          setEquals(flashTopics, other.flashTopics) &&
          setEquals(vibrationTopics, other.vibrationTopics);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(flashTopics),
    Object.hashAllUnordered(vibrationTopics),
  );

  @override
  String toString() =>
      'AlarmSignals(flash: $flashTopics, vibration: $vibrationTopics)';
}

/// What should be running right now, on top of the sound.
@immutable
class RingSignals {
  const RingSignals({required this.flash, required this.vibration});

  static const none = RingSignals(flash: false, vibration: false);

  final bool flash;
  final bool vibration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RingSignals &&
          flash == other.flash &&
          vibration == other.vibration;

  @override
  int get hashCode => Object.hash(flash, vibration);

  @override
  String toString() => 'RingSignals(flash: $flash, vibration: $vibration)';
}

/// Whether to flash or vibrate now, given the topic of every alarm that is
/// ringing.
///
/// Each one runs while any ringing topic has it on, so a second alarm on a
/// topic with both off never takes the flash away from the first. Nothing
/// ringing means nothing runs.
RingSignals ringSignalsFor({
  required Iterable<String> ringingTopics,
  required AlarmSignals signals,
}) {
  var flash = false;
  var vibration = false;
  for (final topic in ringingTopics) {
    flash = flash || signals.flashFor(topic);
    vibration = vibration || signals.vibrationFor(topic);
  }
  return RingSignals(flash: flash, vibration: vibration);
}

/// The ringing topics that have the flash on, in the order given and with no
/// repeats. Empty means the alarm screen does not flash.
///
/// The iPhone uses this: its flash follows the alarm screen, so the screen
/// hands these names to the native side when it starts the flash.
List<String> flashingTopicsFor({
  required Iterable<String> ringingTopics,
  required AlarmSignals signals,
}) => <String>{
  for (final topic in ringingTopics)
    if (signals.flashFor(topic)) topic,
}.toList();

/// Which of the two rows the topic page shows.
@immutable
class AlarmSignalRows {
  const AlarmSignalRows({
    required this.flash,
    required this.strongVibration,
    required this.flashNeedsAlarmScreen,
  });

  static const none = AlarmSignalRows(
    flash: false,
    strongVibration: false,
    flashNeedsAlarmScreen: false,
  );

  final bool flash;
  final bool strongVibration;

  /// True on iPhone, where the app can only flash while its own alarm screen
  /// is open. The flash row says so in its explanation.
  final bool flashNeedsAlarmScreen;

  bool get any => flash || strongVibration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSignalRows &&
          flash == other.flash &&
          strongVibration == other.strongVibration &&
          flashNeedsAlarmScreen == other.flashNeedsAlarmScreen;

  @override
  int get hashCode =>
      Object.hash(flash, strongVibration, flashNeedsAlarmScreen);

  @override
  String toString() =>
      'AlarmSignalRows(flash: $flash, strongVibration: $strongVibration, '
      'flashNeedsAlarmScreen: $flashNeedsAlarmScreen)';
}

/// The rows for one topic on one phone.
///
/// Only a critical topic rings, so only a critical topic shows either row.
/// The flash row needs a flash unit on the phone ([hasTorch], asked of the
/// native side). The strong vibration row is Android only: an iPhone alarm is
/// rung by the system and the app cannot add a vibration to it. The web build
/// shows neither.
AlarmSignalRows alarmSignalRowsFor({
  required PlatformCapabilities capabilities,
  required bool hasTorch,
  required bool critical,
}) {
  if (!critical || !capabilities.canRunAlarm) return AlarmSignalRows.none;
  return AlarmSignalRows(
    flash: hasTorch,
    strongVibration: capabilities.hasStrongAlarmVibration,
    flashNeedsAlarmScreen: capabilities.flashNeedsAlarmScreen,
  );
}
