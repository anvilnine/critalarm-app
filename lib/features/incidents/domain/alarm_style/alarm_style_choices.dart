import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';

/// The looks picked for the alarm screen, kept on this phone only. Nothing
/// here is sent to a server, and no native code reads it: the system
/// surfaces (the AlarmKit card, the Live Activity, notifications) have one
/// look.
///
/// Three things are kept:
///
/// - `alarm_style_default`: the look for the phone. No key means the
///   standard look.
/// - `alarm_style_topic.<topic>`: a topic's own look. No key means the
///   topic follows the phone.
/// - `alarm_style_open_when_last_sure`: see [wasOpenWhenLastSure].
///
/// A lock never changes what is saved here. What is drawn is
/// `alarmStyleFor`'s answer.
abstract interface class AlarmStyleChoices {
  static const String defaultKey = 'alarm_style_default';
  static const String topicKeyPrefix = 'alarm_style_topic.';
  static const String openWhenLastSureKey = 'alarm_style_open_when_last_sure';

  /// What is saved, as it was saved.
  AlarmStyleAssignments get assignments;

  /// Saves the look for the phone. Null takes it away.
  Future<void> setDefault(String? styleId);

  /// Saves [topic]'s own look. Null puts it back on the phone's.
  Future<void> setTopicStyle(String topic, String? styleId);

  /// The topic was deleted on this phone: its choice goes.
  Future<void> forgetTopic(String topic);

  /// Whether the last sure answer of the access layer for alarm screen
  /// styles was "open". While the plan cannot be read, a paid look keeps
  /// drawing only then. Only `AlarmStyleGate` writes it, and only on a
  /// sure answer.
  bool get wasOpenWhenLastSure;

  Future<void> writeOpenWhenLastSure({required bool isOpen});

  /// Fires after a choice changed.
  Stream<void> get changes;
}
