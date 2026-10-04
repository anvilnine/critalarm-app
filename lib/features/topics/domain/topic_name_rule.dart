/// What the server accepts as a topic name: 1 to 64 letters, digits, hyphens
/// and underscores.
final RegExp topicNamePattern = RegExp(r'^[-_A-Za-z0-9]{1,64}$');

/// Whether [name], already trimmed, is a name the server accepts.
bool isValidTopicName(String name) => topicNamePattern.hasMatch(name);
