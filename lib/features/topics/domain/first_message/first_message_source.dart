import 'package:flutter/foundation.dart';

/// Where the watch for a first message starts when setup sent a test alarm.
@immutable
class FirstMessageBaseline {
  /// Setup sent no test to the server, so there is no message to skip.
  const FirstMessageBaseline.noTest() : messageId = null;

  /// The newest message of setup's own test. Only messages after it count.
  const FirstMessageBaseline.after(String this.messageId);

  final String? messageId;

  @override
  bool operator ==(Object other) =>
      other is FirstMessageBaseline && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() => 'FirstMessageBaseline($messageId)';
}

/// What the first-message watch asks the server. It learns that a message
/// arrived and nothing about it: ids come back, never a title or a body.
abstract interface class FirstMessageSource {
  /// The ids of the messages on [topic] newer than [since], oldest first.
  /// Throws when the server cannot be asked.
  Future<List<String>> newerThan(String topic, String since);

  /// The newest message of the test alarms setup sent. Throws when a test
  /// was sent and its message cannot be read right now.
  Future<FirstMessageBaseline> testBaseline();
}
