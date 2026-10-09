import 'dart:async';
import 'dart:ui';

import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// What a shared message says: the title when it has its own, the body, and
/// a last line naming the topic and when it came in. A message with no title
/// carries the topic name as its title on screen, so that one is not repeated.
String messageShareText(TopicDetailMessageItem message, String topic) {
  final lines = <String>[
    if (message.title.isNotEmpty && message.title != topic) message.title,
    if (message.body.isNotEmpty) message.body,
  ];
  // A shared message is read later, so it carries the full date and not
  // "Yesterday".
  final sentAt = message.sentAt;
  final when = sentAt == null
      ? message.timestamp
      : DateFormat('d MMM y HH:mm').format(sentAt.toLocal());
  return '${lines.join('\n')}\n\n$topic · $when';
}

/// Opens the system share sheet for [message]. [origin] is where the tap
/// landed, which an iPad needs to point its popover at.
void shareMessage(TopicDetailMessageItem message, String topic, Rect origin) {
  unawaited(
    SharePlus.instance.share(
      ShareParams(
        text: messageShareText(message, topic),
        sharePositionOrigin: origin,
      ),
    ),
  );
}
