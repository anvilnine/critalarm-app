import 'package:critalarm/core/models/message.dart';

/// The rules that make the Topics list read like an inbox: what the preview
/// line says, how many messages count as unread, and what order rows go in.

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

/// Orders the list.
///
/// Pinned topics first, then the rest, then muted ones. A topic that is live
/// (ringing or warning) never sinks, muted or not: muting is how the list
/// looks, and a live alarm must stay where the user will see it. Inside each
/// group the newest message wins, and topics with no messages keep the order
/// they came in.
List<String> orderTopics(
  List<String> names, {
  required Set<String> pinned,
  required Set<String> muted,
  required Set<String> live,
  required Map<String, int> latestAt,
}) {
  int group(String name) {
    if (pinned.contains(name)) return 0;
    if (muted.contains(name) && !live.contains(name)) return 2;
    return 1;
  }

  final position = {for (var i = 0; i < names.length; i++) names[i]: i};
  return [...names]..sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final byTime = (latestAt[b] ?? -1).compareTo(latestAt[a] ?? -1);
    if (byTime != 0) return byTime;
    return position[a]!.compareTo(position[b]!);
  });
}
