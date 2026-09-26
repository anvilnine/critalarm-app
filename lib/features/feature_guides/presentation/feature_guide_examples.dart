import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Made-up topics the guide shows to someone who has none yet, so every step
/// has something real-looking to point at. None of it reaches the server.
abstract final class FeatureGuideExamples {
  /// One topic with critical delivery on and one with it off, so the
  /// difference is on screen side by side.
  static List<HomeTopicItem> homeTopics() => [
    HomeTopicItem(
      name: FeatureGuideCubit.exampleTopicName,
      meta: LocaleKeys.home_meta_quiet.tr(),
      priority: PriorityLevel.defaultPriority,
      ringsThroughSilent: true,
    ),
    HomeTopicItem(
      name: 'nightly-backup',
      meta: LocaleKeys.home_meta_quiet.tr(),
      priority: PriorityLevel.defaultPriority,
    ),
  ];

  /// A topic in the middle of a page: alarmed face, critical chip. Shown to
  /// everyone during the guide, next to their own topics, so the list has
  /// something going wrong on it to point at.
  static HomeTopicItem troubleTopic() => HomeTopicItem(
    name: 'payments-api',
    meta: LocaleKeys.home_meta_alert_active.tr(),
    priority: PriorityLevel.critical,
    faceState: FaceState.alarmed,
    isCrit: true,
    isLive: true,
    ringsThroughSilent: true,
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
    subText: LocaleKeys.tour_example_topic_sub.tr(),
    messages: [
      TopicDetailMessageItem(
        title: LocaleKeys.tour_example_message_title.tr(),
        timestamp: LocaleKeys.tour_example_message_time.tr(),
        body: LocaleKeys.tour_example_message_body.tr(),
        source: 'uptime-kuma',
      ),
    ],
  );
}
