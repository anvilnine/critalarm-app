import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/expected_setup.dart';

/// The topics the app holds right now, as the setup guess on Home reads them,
/// or null when it holds no list.
///
/// A list the phone kept from the last answer counts: after a cold start it is
/// what lets the first card be the right one. A list that failed to load and
/// was never held reads as none, because it says nothing about the account.
List<HeldTopic>? heldTopicsFrom(TopicsState topics) {
  if (!topics.isReady) return null;
  return [
    for (final topic in topics.topics)
      (name: topic.name, isCritical: topic.critical),
  ];
}
