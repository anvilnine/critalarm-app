import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';

// Small rules for what Home's list sheet shows around the rows. Pure, so each
// one is unit tested and the screen only draws the answer.

/// The one cream card at the top of the list sheet.
enum HomeCreamCard { widgets, day0 }

/// Which cream card the sheet shows, or null. One at a time: the widgets card
/// first, then the day-0 card.
HomeCreamCard? creamCardFor({required bool widgets, required bool day0}) {
  if (widgets) return HomeCreamCard.widgets;
  if (day0) return HomeCreamCard.day0;
  return null;
}

/// The one bar pinned above the tab bar.
enum HomePinnedBar { hostedEnding, accountBackup, oneTopic }

/// Which bar is pinned above the tab bar, or null. One at a time: the Hosted
/// plan ending first, then the account backup reminder, then "One topic so
/// far".
HomePinnedBar? pinnedBarFor({
  required bool hostedEnding,
  required bool accountBackup,
  required bool oneTopic,
}) {
  if (hostedEnding) return HomePinnedBar.hostedEnding;
  if (accountBackup) return HomePinnedBar.accountBackup;
  if (oneTopic) return HomePinnedBar.oneTopic;
  return null;
}

/// The saved flag for the "One topic so far" bar being closed.
const String oneTopicCardClosedKey = 'home_one_topic_card_closed';

/// Whether the "One topic so far" bar shows.
///
/// Once per install: closing it keeps it away for good. Never before setup
/// has finished, and never while the dark card is already asking for the
/// first message.
bool showsOneTopicCard({
  required int topicCount,
  required bool isClosed,
  required bool isSetupDone,
  required HomeCardKind cardKind,
}) =>
    topicCount == 1 &&
    !isClosed &&
    isSetupDone &&
    cardKind != HomeCardKind.waiting &&
    cardKind != HomeCardKind.setup;

/// How fresh a topic that was not in the last list has to be for its message
/// to count as one that just came in.
const Duration glanceFreshness = Duration(minutes: 2);

/// The newest message time of each topic that has one.
typedef MessageTimes = Map<String, DateTime>;

/// The glance count after a build.
///
/// The hero face glances at the list each time the count goes up. It goes up
/// when a topic's newest message moved forward between two builds, while
/// Home is in front and the app is resumed.
///
/// - [before]: the times of the previous build, or null on the first build.
///   The first build never glances, so opening the tab is silent.
/// - [after]: the times of this build.
/// - [isInFront]: Home is the screen in front and the app is resumed. A
///   message that lands while it is not still moves [before] forward on the
///   next build, so it never glances later.
/// - [now]: a topic that was not in [before] counts only when its message is
///   newer than [glanceFreshness], so a list that grows by syncing old
///   topics stays quiet.
int nextGlanceCount({
  required int count,
  required MessageTimes? before,
  required MessageTimes after,
  required bool isInFront,
  required DateTime now,
}) {
  if (before == null || !isInFront) return count;
  for (final MapEntry(key: topic, value: at) in after.entries) {
    final previous = before[topic];
    final isNewer = previous == null
        ? now.difference(at) < glanceFreshness
        : at.isAfter(previous);
    if (isNewer) return count + 1;
  }
  return count;
}
