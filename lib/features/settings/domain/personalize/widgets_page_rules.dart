import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, immutable;

// The rules of the Widgets page: which widgets it draws, where it exists, and
// which buttons it shows for a plan. Pure, so each is tested without a screen.

/// The home screen widgets Crit Alarm has, in the order the page draws them.
/// iOS and Android each have all three.
enum HomeWidgetKind {
  /// How many incidents are open right now, with the ringing face.
  openIncidents,

  /// One topic, with its I'm up button.
  topic,

  /// Your topics, ringing ones first.
  topics,
}

/// The three kinds, in drawing order. The page's value is their count.
const List<HomeWidgetKind> homeWidgetKinds = HomeWidgetKind.values;

/// Whether the Widgets page exists on [platform]: where there are home screen
/// widgets to add. The router sends every other platform back to Personalize
/// and the root draws no Widgets pass there.
bool widgetsPageExistsOn(TargetPlatform platform) =>
    homeScreenWidgetsExist(platform: platform, isWeb: false);

/// A button the page can show.
enum WidgetsPageButton {
  /// "See Pro". Opens the paywall.
  seePlan,

  /// "How to add one". Opens the steps for this phone.
  howToAdd,
}

/// The buttons in the bottom bar, in order. The first is the primary.
@immutable
class WidgetsPageButtons {
  const WidgetsPageButtons({required this.showsSeePlan});

  /// Whether "See Pro" is drawn. It is only while the widgets are locked and
  /// the plan has been read.
  final bool showsSeePlan;

  /// "See Pro" first when it is shown, then "How to add one".
  List<WidgetsPageButton> get all => [
    if (showsSeePlan) WidgetsPageButton.seePlan,
    WidgetsPageButton.howToAdd,
  ];

  /// The button drawn as the primary.
  WidgetsPageButton get primary => all.first;

  @override
  bool operator ==(Object other) =>
      other is WidgetsPageButtons && other.showsSeePlan == showsSeePlan;

  @override
  int get hashCode => showsSeePlan.hashCode;
}

/// The buttons for [decision], the widgets decision from `FeatureAccess`.
///
/// "How to add one" is always there. "See Pro" is there exactly when a tap on
/// it would sell, which is `lockTapFor`'s answer for a button that says See
/// Pro: not while the plan is unread, and not when nothing is locked.
WidgetsPageButtons widgetsPageButtonsFor({
  required FeatureDecision decision,
  required bool isPlanRead,
}) => WidgetsPageButtons(
  showsSeePlan:
      lockTapFor(
            decision: decision,
            isPlanRead: isPlanRead,
            hasTry: false,
            tap: LockTapKind.seePlan,
          )
          is OpenPaywall,
);

/// The plan the steps sheet words itself for.
///
/// Before the plan is read a locked answer is a guess, so the sheet shows the
/// steps and sells nothing. After it, the sheet follows the decision, as the
/// Home widgets card does.
HomeWidgetsPlan widgetsSheetPlanFor({
  required FeatureDecision decision,
  required bool isPlanRead,
  required bool isOwnServer,
}) {
  if (!isPlanRead) {
    return isOwnServer ? HomeWidgetsPlan.selfHosted : HomeWidgetsPlan.pro;
  }
  return homeWidgetsPlanFor(decision, isOwnServer: isOwnServer);
}
