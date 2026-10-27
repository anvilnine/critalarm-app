/// Whether [typed] is the topic name.
///
/// Capitals do not matter and neither do spaces before or after: a phone
/// keyboard adds both on its own. Everything else has to be there, hyphens
/// and dots included. An empty name never matches, so nothing passes by
/// typing nothing.
///
/// The two strings are both on the same screen. Nothing here reads a
/// message.
bool topicNameMatches({required String typed, required String topic}) {
  final want = topic.trim().toLowerCase();
  if (want.isEmpty) return false;
  return typed.trim().toLowerCase() == want;
}
