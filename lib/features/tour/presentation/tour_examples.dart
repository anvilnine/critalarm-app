import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Made-up topics the tour shows to someone who has none yet, so every step
/// has something real-looking to point at. None of it reaches the server.
abstract final class TourExamples {
  /// One topic with critical delivery on and one with it off, so the
  /// difference is on screen side by side.
  static List<HomeTopicItem> homeTopics() => [
    HomeTopicItem(
      name: TourCubit.exampleTopicName,
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

  /// The example topic's own screen.
  static TopicDetailState topicDetail() => TopicDetailState(
    status: TopicDetailStatus.success,
    topicName: TourCubit.exampleTopicName,
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
