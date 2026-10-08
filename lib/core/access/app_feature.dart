import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// A feature that some plan unlocks.
///
/// Everything that is on every plan (the alarm itself, repeats, the test
/// alarm, built-in sounds) is not listed here and is open to everyone.
enum AppFeature {
  unlimitedCriticalTopics,
  longHistory,
  storageRules,
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
}

/// Who may use one [AppFeature].
@immutable
final class FeatureRule {
  const FeatureRule({required this.unlockedBy, required this.onOwnServer});

  /// Any one of these unlocks the feature. The first is the one to offer
  /// when it is locked.
  final Set<Holding> unlockedBy;

  final OwnServerRule onOwnServer;
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
  AppFeature.storageRules: FeatureRule(
    unlockedBy: {Holding.hosted},
    onOwnServer: OwnServerRule.open,
  ),
  AppFeature.appIcons: FeatureRule(
    unlockedBy: {Holding.hosted},
    onOwnServer: OwnServerRule.open,
  ),
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
  AppFeature.weeklyCheck: FeatureRule(
    unlockedBy: {Holding.pro},
    onOwnServer: OwnServerRule.sameAsCloud,
  ),
};
