import 'package:flutter/foundation.dart';

/// What setup knows about the topic it just made, for the steps after it.
///
/// [token] is the publish token. It is shown once by the server and cannot be
/// fetched again, so it lives in memory only.
@immutable
class FirstTopicHandoffEntry {
  const FirstTopicHandoffEntry({
    required this.topicName,
    required this.serverUrl,
    required this.token,
    this.templateId,
  });

  final String topicName;
  final String serverUrl;
  final String token;

  /// The `ToolTemplate.id` the user picked, or null when no chip was picked.
  final String? templateId;

  /// Never prints the token, so a log line or a crash report cannot leak it.
  @override
  String toString() =>
      'FirstTopicHandoffEntry(topicName: $topicName, token: <hidden>)';
}

/// Holds the first topic between the create step and the steps after it.
///
/// The entry stays in memory. Only the topic name is written to the phone, so
/// a resume after the app was killed still knows which topic setup made. The
/// token, the server URL and the template id never reach preferences, a log,
/// analytics or a crash report from here.
abstract interface class FirstTopicHandoff {
  /// The topic setup just made, or null before one is made, after [clear],
  /// and after the app restarted.
  FirstTopicHandoffEntry? get entry;

  /// The name of the topic setup made, read from the phone. Survives a
  /// restart, unlike [entry].
  String? get savedTopicName;

  /// The id of the token the last setup step made when the first one was
  /// gone, or null when it made none. An id, never the secret. Saved on the
  /// phone so the token can be taken back before another is made.
  String? get mintedTokenId;

  Future<void> saveMintedTokenId(String tokenId);

  /// Keeps [entry] in memory and saves its topic name.
  Future<void> hold(FirstTopicHandoffEntry entry);

  /// Forgets all of it. Called when setup completes.
  Future<void> clear();
}
