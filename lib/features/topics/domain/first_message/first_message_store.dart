/// Whether this phone has ever received a message from the user's own
/// tool, and where each topic's watch for it starts from.
///
/// The flag is set once and never cleared. It is a fact about the user, not
/// about a topic, so deleting the topic does not take it back.
abstract interface class FirstMessageStore {
  /// True once a first message has landed.
  bool get isReceived;

  /// Sets the flag. Safe to call again.
  Future<void> markReceived();

  /// The point the watch on [topic] looks for newer messages from: a
  /// message id or a unix second, as the poll route takes them. Null before
  /// a watch on that topic has begun.
  String? cursorFor(String topic);

  Future<void> saveCursor(String topic, String cursor);

  /// Drops the cursor of a topic that is gone. The flag stays.
  Future<void> forgetTopic(String topic);
}
