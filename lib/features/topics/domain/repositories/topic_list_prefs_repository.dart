/// How the user has arranged the Topics list on this phone.
///
/// None of this reaches the server. The contract has no mute, pin or read
/// state for a topic, so each phone keeps its own, and a second phone on the
/// same account starts with nothing pinned, nothing muted and nothing read.
abstract interface class TopicListPrefsRepository {
  /// Topics the user pinned to the top of the list.
  Set<String> pinned();

  /// Topics the user muted. Muting only changes how the row looks and where
  /// it sits: it does not stop a push, and it never touches an alarm.
  Set<String> muted();

  /// When the user last read [topic], or null if this phone has never
  /// marked it.
  DateTime? lastReadAt(String topic);

  Future<void> setPinned(String topic, {required bool pinned});

  Future<void> setMuted(String topic, {required bool muted});

  /// Everything on [topic] up to [at] counts as read.
  Future<void> markRead(String topic, DateTime at);
}
