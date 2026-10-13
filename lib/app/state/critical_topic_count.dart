import 'package:critalarm/app/state/topics_cubit.dart';

/// How many critical topics the app's one topic list holds, for the paywall
/// that opens when a plan is ending.
///
/// The list is the one for the server and account the phone is on. A list
/// that is being replaced is waited for, up to [wait], and one that was not
/// read yet is asked for. A list that is still not ready after that, or
/// failed, is not a count: this throws, and the paywall opens as if the
/// numbers could not be read.
Future<int> readCriticalTopicCount(
  TopicsCubit topics, {
  Duration wait = const Duration(seconds: 2),
}) async {
  await (topics.state.isRefreshing ? topics.refresh() : topics.ensureLoaded())
      .timeout(wait, onTimeout: () {});
  final state = topics.state;
  if (!state.isReady || state.isRefreshing) {
    throw StateError('The topic list is not read.');
  }
  return state.topics.where((topic) => topic.critical).length;
}
