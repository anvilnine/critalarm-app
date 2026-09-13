import 'package:flutter/foundation.dart';

/// Which sound rings for which topic, plus the one used when a topic has no
/// choice of its own.
///
/// This is a plain value with no storage and no plugins behind it, so the
/// fallback rule can be tested on its own.
@immutable
class SoundAssignments {
  const SoundAssignments({
    required this.defaultSoundId,
    this.perTopic = const {},
  });

  /// Rings for any topic that has not picked its own sound.
  final String defaultSoundId;

  /// Topic name to sound id. A topic missing from here uses the default.
  final Map<String, String> perTopic;

  String soundIdFor(String topicName) => perTopic[topicName] ?? defaultSoundId;

  SoundAssignments withDefault(String soundId) => SoundAssignments(
    defaultSoundId: soundId,
    perTopic: perTopic,
  );

  /// Passing null for [soundId] puts the topic back on the default.
  SoundAssignments withTopicSound(String topicName, String? soundId) {
    final next = Map<String, String>.from(perTopic);
    if (soundId == null) {
      next.remove(topicName);
    } else {
      next[topicName] = soundId;
    }
    return SoundAssignments(defaultSoundId: defaultSoundId, perTopic: next);
  }

  /// A sound was deleted. Everything still pointing at it falls back.
  ///
  /// A topic falls back to the default. If the deleted sound *was* the
  /// default, the default falls back to [fallbackSoundId], which is the first
  /// bundled sound and can never be deleted.
  SoundAssignments withSoundDeleted(
    String soundId, {
    required String fallbackSoundId,
  }) {
    final nextDefault = defaultSoundId == soundId
        ? fallbackSoundId
        : defaultSoundId;
    final next = <String, String>{
      for (final entry in perTopic.entries)
        if (entry.value != soundId) entry.key: entry.value,
    };
    return SoundAssignments(defaultSoundId: nextDefault, perTopic: next);
  }

  @override
  bool operator ==(Object other) =>
      other is SoundAssignments &&
      other.defaultSoundId == defaultSoundId &&
      _sameMap(other.perTopic, perTopic);

  @override
  int get hashCode => Object.hash(
    defaultSoundId,
    Object.hashAllUnordered(
      perTopic.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'SoundAssignments(default: $defaultSoundId, perTopic: $perTopic)';

  static bool _sameMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
