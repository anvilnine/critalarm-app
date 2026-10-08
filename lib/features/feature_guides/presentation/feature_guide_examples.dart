import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Made-up topics the guide shows to someone who has none yet, so every step
/// has something real-looking to point at. None of it reaches the server.
abstract final class FeatureGuideExamples {
  /// One topic with critical delivery on and one with it off, so the
  /// difference is on screen side by side.
  static List<HomeTopicItem> homeTopics({DateTime? now}) {
    final at = now ?? DateTime.now();
    return [
      HomeTopicItem(
        name: FeatureGuideCubit.exampleTopicName,
        meta: LocaleKeys.home_meta_quiet.tr(),
        priority: PriorityLevel.defaultPriority,
        ringsThroughSilent: true,
        preview: LocaleKeys.home_card_example_message_quiet.tr(),
        lastMessageAt: at.subtract(const Duration(hours: 3)),
      ),
      HomeTopicItem(
        name: 'nightly-backup',
        meta: LocaleKeys.home_meta_quiet.tr(),
        priority: PriorityLevel.defaultPriority,
        preview: LocaleKeys.home_card_example_message_quiet.tr(),
        lastMessageAt: at.subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// A topic in the middle of a page: alarmed face, critical delivery. Shown
  /// to everyone during the guide, next to their own topics, so the list has
  /// something going wrong on it to point at.
  static HomeTopicItem troubleTopic({DateTime? now}) => HomeTopicItem(
    name: 'payments-api',
    meta: LocaleKeys.home_meta_alert_active.tr(),
    priority: PriorityLevel.critical,
    faceState: FaceState.alarmed,
    isCrit: true,
    isLive: true,
    ringsThroughSilent: true,
    preview: LocaleKeys.home_card_example_message_ringing.tr(),
    lastMessageAt: (now ?? DateTime.now()).subtract(
      const Duration(minutes: 2),
    ),
    rowKind: InboxRowKind.ringing,
  );

  /// What the dark card shows while [troubleTopic] is in the list: the same
  /// trouble, so the card and the row never disagree. Its button opens
  /// nothing, because the incident is made up.
  static HomeCardModel troubleCard({DateTime? now}) => HomeCardModel(
    kind: HomeCardKind.ringing,
    label: HomeCardLabel.ringing,
    numeral: Elapsed(
      (now ?? DateTime.now()).subtract(const Duration(minutes: 2, seconds: 17)),
    ),
    foot: HomeCardFoot(HomeCardFootSlot.topic, topic: troubleTopic().name),
    action: const OpenAlarm('example'),
    face: FaceState.alarmed,
    severity: SeverityMode.crit,
    discTone: HomeCardDiscTone.red,
    numeralTone: HomeCardNumeralTone.redAlt,
  );

  /// The example topic's own screen.
  static TopicDetailState topicDetail() => TopicDetailState(
    status: TopicDetailStatus.success,
    topicName: FeatureGuideCubit.exampleTopicName,
    critical: true,
    // Lets the switch draw as usable, the way it will be once the user has
    // a topic of their own.
    alarm: AlarmAuthorization.authorized,
    word: LocaleKeys.topic_detail_stage_word_clear.tr(),
    subText: LocaleKeys.feature_guides_example_topic_sub.tr(),
    messages: [
      TopicDetailMessageItem(
        title: LocaleKeys.feature_guides_example_message_title.tr(),
        timestamp: LocaleKeys.feature_guides_example_message_time.tr(),
        body: LocaleKeys.feature_guides_example_message_body.tr(),
        source: 'uptime-kuma',
      ),
    ],
  );
}
