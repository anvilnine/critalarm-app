import 'package:flutter/foundation.dart';

/// Which look the alarm screen draws for which topic, plus the one used
/// when a topic has no choice of its own. The same shape as the sound
/// choices (`SoundAssignments`).
///
/// It holds ids as they were saved, known to this build or not, so a
/// choice made on a newer build is kept as it is. A plain value with no
/// storage behind it. What is really drawn is `alarmStyleFor`'s answer.
@immutable
class AlarmStyleAssignments {
  const AlarmStyleAssignments({this.defaultStyleId, this.perTopic = const {}});

  /// Drawn for any topic that has not picked its own look. Null when the
  /// phone has no default saved, which draws the standard look.
  final String? defaultStyleId;

  /// Topic name to look id. A topic missing from here uses the default.
  final Map<String, String> perTopic;

  /// The id saved for [topicName], or the default when it has none or
  /// when [topicName] is null.
  String? styleIdFor(String? topicName) =>
      (topicName == null ? null : perTopic[topicName]) ?? defaultStyleId;

  /// Passing null takes the default away.
  AlarmStyleAssignments withDefault(String? styleId) =>
      AlarmStyleAssignments(defaultStyleId: styleId, perTopic: perTopic);

  /// Passing null for [styleId] puts the topic back on the default.
  AlarmStyleAssignments withTopicStyle(String topicName, String? styleId) {
    final next = Map<String, String>.from(perTopic);
    if (styleId == null) {
      next.remove(topicName);
    } else {
      next[topicName] = styleId;
    }
    return AlarmStyleAssignments(
      defaultStyleId: defaultStyleId,
      perTopic: next,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmStyleAssignments &&
      other.defaultStyleId == defaultStyleId &&
      mapEquals(other.perTopic, perTopic);

  @override
  int get hashCode => Object.hash(
    defaultStyleId,
    Object.hashAllUnordered(
      perTopic.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'AlarmStyleAssignments(default: $defaultStyleId, perTopic: $perTopic)';
}
