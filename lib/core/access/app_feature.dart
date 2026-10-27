import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// A feature that some plan unlocks.
///
/// Everything that is on every plan (the alarm itself, repeats, the test
/// alarm, built-in sounds) is not listed here and is open to everyone.
enum AppFeature {
  unlimitedCriticalTopics,
  longHistory,
  appIcons,
  widgets,
  ownSounds,
  alarmScreenStyles,
  wakeUpChallenges,
  weeklyCheck,
}

/// What a feature does on a phone connected to a server of the user's own.
enum OwnServerRule {
  /// Such a server has no plans, so the feature is open there.
  open,

  /// The feature needs the same holding there as on Crit Alarm Cloud.
  sameAsCloud,

  /// The feature does not exist there, whatever is held. It needs a plan
  /// that is only sold on Crit Alarm Cloud, so there is nothing to sell
  /// and nothing to switch on.
  notOffered,
}

/// Who may use one [AppFeature].
@immutable
final class FeatureRule {
  const FeatureRule({
    required this.unlockedBy,
    required this.onOwnServer,
    this.offer,
  });

  /// Any one of these unlocks the feature.
  final Set<Holding> unlockedBy;

  final OwnServerRule onOwnServer;

  /// The holding to sell when the feature is locked. A row that more than
  /// one holding unlocks names it, so the choice is written down and never
  /// falls out of the order of a set literal. Left out, it is the one
  /// holding in [unlockedBy].
  final Holding? offer;

  /// The holding a locked feature offers: [offer], or the first of
  /// [unlockedBy] where the row names none.
  Holding get offered => offer ?? unlockedBy.first;
}

/// The one table that says which holding unlocks which feature.
///
/// It says who is past a cap, never what the cap is: the server sends the
/// numbers and enforces them.
const Map<AppFeature, FeatureRule> featureTable = {
  AppFeature.unlimitedCriticalTopics: FeatureRule(
    unlockedBy: {Holding.hosted},
    onOwnServer: OwnServerRule.open,
  ),
  AppFeature.longHistory: FeatureRule(
    unlockedBy: {Holding.hosted},
    onOwnServer: OwnServerRule.open,
  ),
  // Either purchase is enough. Hosted is the one offered.
  AppFeature.appIcons: FeatureRule(
    unlockedBy: {Holding.hosted, Holding.pro},
    offer: Holding.hosted,
    onOwnServer: OwnServerRule.open,
  ),
  // Pro only, also on a server of the user's own.
  AppFeature.widgets: FeatureRule(
    unlockedBy: {Holding.pro},
    onOwnServer: OwnServerRule.sameAsCloud,
  ),
  AppFeature.ownSounds: FeatureRule(
    unlockedBy: {Holding.pro},
    onOwnServer: OwnServerRule.sameAsCloud,
  ),
  AppFeature.alarmScreenStyles: FeatureRule(
    unlockedBy: {Holding.pro},
    onOwnServer: OwnServerRule.sameAsCloud,
  ),
  AppFeature.wakeUpChallenges: FeatureRule(
    unlockedBy: {Holding.pro},
    onOwnServer: OwnServerRule.sameAsCloud,
  ),
  // The relay runs it, so it is Hosted. Hosted is not sold for a server
  // of the user's own, and the relay sends no check there (api.md §4.5).
  AppFeature.weeklyCheck: FeatureRule(
    unlockedBy: {Holding.hosted},
    onOwnServer: OwnServerRule.notOffered,
  ),
};
