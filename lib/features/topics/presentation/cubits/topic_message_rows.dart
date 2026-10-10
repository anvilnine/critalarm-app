import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/format/when_label.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/topic_message_order.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// How far back this phone may show a topic's messages. The Topic screen and
/// the Topics list read it from here, so the rows the list notes for a topic
/// are the rows the screen then draws.
class TopicMessageWindow {
  const TopicMessageWindow({
    this.identityStore,
    this.featureAccess,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Holds the caps the registration sent. Null in tests, and then nothing is
  /// hidden.
  final DeviceIdentityStore? identityStore;

  /// Says who is past those caps. Null in tests, and then the caps apply.
  final FeatureAccess? featureAccess;

  final DateTime Function() _now;

  /// The oldest message this tier may show, or null for everything held.
  /// Same rule as History (api.md §4.2), read from one place.
  Future<DateTime?> lowerBound() async {
    final identity = await identityStore?.readOrCreate();
    if (identity == null) return null;
    return HistoryWindow.lowerBound(
      hasLongHistory:
          await featureAccess?.usableOnceReady(AppFeature.longHistory) ?? false,
      historyDays: identity.caps.historyDays ?? 7,
      now: _now(),
    );
  }

  /// [messages] without those older than [bound].
  static List<Message> inside(List<Message> messages, DateTime? bound) {
    if (bound == null) return messages;
    final seconds = bound.toUtc().millisecondsSinceEpoch ~/ 1000;
    return [
      for (final message in messages)
        if (message.time >= seconds) message,
    ];
  }
}

/// The rows the Topic screen shows for [newestFirst]. One place, so the rows
/// the list noted and the rows the screen builds cannot differ.
List<TopicDetailMessageItem> topicMessageRows(
  List<Message> messages, {
  required DateTime now,
}) => [
  for (final m in messages)
    TopicDetailMessageItem(
      title: m.title ?? m.topic,
      timestamp: formatWhenWithTime(
        at: DateTime.fromMillisecondsSinceEpoch(m.time * 1000),
        now: now,
        yesterday: LocaleKeys.home_card_row_yesterday.tr(),
      ),
      sentAt: DateTime.fromMillisecondsSinceEpoch(m.time * 1000),
      body: m.message,
      source: m.tags.join(', '),
      isHigh: m.priority == 4,
      messageId: m.id,
      incidentId: m.incidentId,
    ),
];

/// What the app knows of [topic]'s messages once [held] is cut to the window.
TopicGlance topicGlanceOf(
  Topic topic,
  List<Message> held,
  DateTime? lowerBound, {
  required DateTime now,
}) {
  final inside = newestFirst(TopicMessageWindow.inside(held, lowerBound));
  return TopicGlance(
    topicCreatedAt: topic.createdAt,
    messageTimes: [
      for (final m in inside)
        DateTime.fromMillisecondsSinceEpoch(m.time * 1000),
    ],
    hasHighMessage: inside.any((m) => m.priority == 4),
    messages: topicMessageRows(inside, now: now),
  );
}
