import 'dart:async';
import 'dart:ui';

import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:share_plus/share_plus.dart';

/// What a shared message says: the title when it has its own, the body, and
/// a last line naming the topic and when it came in. A message with no title
/// carries the topic name as its title on screen, so that one is not repeated.
String messageShareText(TopicDetailMessageItem message, String topic) {
  final lines = <String>[
    if (message.title.isNotEmpty && message.title != topic) message.title,
    if (message.body.isNotEmpty) message.body,
  ];
  return '${lines.join('\n')}\n\n$topic · ${message.timestamp}';
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
