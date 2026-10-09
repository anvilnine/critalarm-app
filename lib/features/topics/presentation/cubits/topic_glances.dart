import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:flutter/foundation.dart';

/// What the app already knows about a topic's messages, kept so the Topic
/// screen can draw them on its first frame.
@immutable
class TopicGlance {
  const TopicGlance({
    required this.topicCreatedAt,
    required this.messageTimes,
    required this.hasHighMessage,
    this.messages,
  });

  /// When the topic was created. A glance is used only for the topic it was
  /// taken from, so a topic deleted and made again under the same name starts
  /// from nothing.
  final DateTime? topicCreatedAt;

  /// When each message arrived.
  final List<DateTime> messageTimes;

  /// A message of priority 4 is held, which makes the topic a warning even
  /// when no open incident says so.
  final bool hasHighMessage;

  /// The rows the Topic screen showed last. Null when only the list has seen
  /// the topic, which leaves the rows to load.
  final List<TopicDetailMessageItem>? messages;
}

/// The glances taken so far, one per topic, in memory only.
///
/// Home fills it as it reads every topic's messages for its list, and the
/// Topic screen fills it when it loads one. The Topic screen reads it before
/// its own read finishes, so the summary under the name, the warning colour
/// of the canvas and the message rows are right when the screen opens.
class TopicGlances {
  final Map<String, TopicGlance> _byTopic = {};

  /// The glance for [name], or null when the topic was never read or was made
  /// again since.
  TopicGlance? of(String name, {required DateTime? createdAt}) {
    final glance = _byTopic[name];
    if (glance == null || glance.topicCreatedAt != createdAt) return null;
    return glance;
  }

  /// Keeps [glance] for [name], whole.
  void remember(String name, TopicGlance glance) => _byTopic[name] = glance;

  /// Keeps what the list read for [name]. The rows a Topic screen remembered
  /// stay when the list saw the same messages, because they are still right.
  void rememberFromList(
    String name, {
    required DateTime? createdAt,
    required List<DateTime> messageTimes,
    required bool hasHighMessage,
  }) {
    final held = of(name, createdAt: createdAt);
    if (held != null &&
        held.hasHighMessage == hasHighMessage &&
        listEquals(held.messageTimes, messageTimes)) {
      return;
    }
    _byTopic[name] = TopicGlance(
      topicCreatedAt: createdAt,
      messageTimes: messageTimes,
      hasHighMessage: hasHighMessage,
    );
  }
}
