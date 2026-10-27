import 'package:critalarm/core/models/message.dart';

/// [messages] newest first, by the time each arrived.
///
/// The server and the phone's own copy do not promise an order, so the Topic
/// screen sorts instead of reading the list backwards. Two messages with the
/// same time keep the later one in the list first, which is what reading the
/// list backwards gave. The list passed in is left as it was.
List<Message> newestFirst(Iterable<Message> messages) {
  final indexed = messages.toList().asMap().entries.toList()
    ..sort((a, b) {
      final byTime = b.value.time.compareTo(a.value.time);
      return byTime != 0 ? byTime : b.key.compareTo(a.key);
    });
  return [for (final entry in indexed) entry.value];
}
