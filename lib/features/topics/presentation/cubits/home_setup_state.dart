import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart';

/// Which piece of setup content Home draws at the top of its list sheet.
/// One at a time, never two.
enum HomeSetupPhase {
  /// Nothing.
  none,

  /// The three rows.
  checklist,

  /// The one line that says setup is finished, once.
  celebration,

  /// The widgets card, once.
  widgetsCard,
}

/// The setup content on Home: the checklist, its celebration and the
/// widgets card. Home content, not an In-App Notice and not an ask.
@immutable
class HomeSetupState {
  const HomeSetupState({
    this.phase = HomeSetupPhase.none,
    this.checklist = SetupChecklist.hidden,
    this.firstTopic,
    this.watchedTopic,
    this.widgetsPlan = HomeWidgetsPlan.needsPro,
  });

  final HomeSetupPhase phase;

  /// The rows, while [phase] is [HomeSetupPhase.checklist].
  final SetupChecklist checklist;

  /// The first topic in the list, which the critical-topic row opens.
  final String? firstTopic;

  /// The topic the first-message row opens with its curl line.
  final String? watchedTopic;

  /// How this user gets widgets, while [phase] is
  /// [HomeSetupPhase.widgetsCard].
  final HomeWidgetsPlan widgetsPlan;

  /// Where a tap on [row] goes, or null when the row is not a button.
  String? routeFor(SetupChecklistRow row) => setupChecklistRoute(
    row,
    checklist: checklist,
    firstTopic: firstTopic,
    watchedTopic: watchedTopic,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeSetupState &&
      other.phase == phase &&
      other.checklist == checklist &&
      other.firstTopic == firstTopic &&
      other.watchedTopic == watchedTopic &&
      other.widgetsPlan == widgetsPlan;

  @override
  int get hashCode =>
      Object.hash(phase, checklist, firstTopic, watchedTopic, widgetsPlan);

  @override
  String toString() => 'HomeSetupState($phase, $checklist)';
}
