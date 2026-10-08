import 'package:critalarm/core/models/message.dart';

/// The rules that make the Topics list read like an inbox: what the preview
/// line says and how many messages count as unread. The order of the rows is
/// `orderInbox`.

/// One line for the row under the topic name. The title leads when there is
/// one, and line breaks fold into spaces so the row stays one line.
String topicPreview(Message message) {
  final body = message.message.replaceAll(RegExp(r'\s+'), ' ').trim();
  final title = message.title?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (title.isEmpty) return body;
  if (body.isEmpty) return title;
  return '$title: $body';
}

/// How many of [messageTimes] (epoch seconds) came in after [lastReadAt].
/// A topic this phone has never marked counts nothing as unread, so an update
/// does not greet the user with a badge on every topic.
int unreadCount(Iterable<int> messageTimes, DateTime? lastReadAt) {
  if (lastReadAt == null) return 0;
  final cutoff = lastReadAt.millisecondsSinceEpoch ~/ 1000;
  return messageTimes.where((t) => t > cutoff).length;
}
