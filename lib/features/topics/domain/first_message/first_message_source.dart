import 'package:flutter/foundation.dart';

/// One read of a topic, as the first-message watch sees it: ids and
/// nothing else. No title and no body gets past the source.
@immutable
class FirstMessagePage {
  const FirstMessagePage({required this.candidates, required this.newestId});

  /// Nothing came back.
  const FirstMessagePage.empty() : candidates = const [], newestId = null;

  /// The ids of the messages that could be the user's own, oldest first.
  /// A test alarm, whoever asked for it, is never one of them.
  final List<String> candidates;

  /// The id of the newest message of any kind, tests included, or null
  /// when the read returned none. The next read starts after it.
  final String? newestId;
}

/// What the first-message watch asks the server.
abstract interface class FirstMessageSource {
  /// The messages on [topic] after [since]: a message id, or
  /// [FirstMessageSource.everything] for all the server still holds.
  /// Throws when the server cannot be asked.
  Future<FirstMessagePage> read(String topic, String since);

  /// The `since` value that asks for everything (api.md 2).
  static const everything = 'all';
}
