import 'package:critalarm/core/models/incident.dart';
import 'package:flutter/foundation.dart';

/// How far back the History list can reach.
///
/// The longest one is also how much the cubit loads, so nothing here can ask
/// for alarms that were never fetched.
abstract final class HistoryWindows {
  static const Duration day = Duration(days: 1);
  static const Duration week = Duration(days: 7);
  static const Duration full = Duration(days: 30);

  /// Shortest first, which is also the order the chips are drawn in.
  static const List<Duration> all = <Duration>[day, week, full];
}

/// What the History list is narrowed down to.
///
/// An empty [states] means every state, which is not the same as listing all
/// four: adding a fifth incident state later should not need this touched.
@immutable
class HistoryFilter {
  const HistoryFilter({
    this.states = const <IncidentState>{},
    this.window = HistoryWindows.full,
  });

  /// Nothing narrowed down. What the screen opens with.
  static const HistoryFilter none = HistoryFilter();

  final Set<IncidentState> states;
  final Duration window;

  bool get isActive => states.isNotEmpty || window != HistoryWindows.full;

  /// How many of the two controls are away from their default, for the badge
  /// on the filter button.
  int get activeCount =>
      (states.isEmpty ? 0 : 1) + (window == HistoryWindows.full ? 0 : 1);

  /// Adds [state] if it is off, removes it if it is on.
  HistoryFilter toggleState(IncidentState state) {
    final next = Set<IncidentState>.of(states);
    if (!next.remove(state)) next.add(state);
    return HistoryFilter(states: next, window: window);
  }

  HistoryFilter withWindow(Duration value) =>
      HistoryFilter(states: states, window: value);

  HistoryFilter withAllStates() => HistoryFilter(window: window);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryFilter &&
          runtimeType == other.runtimeType &&
          setEquals(states, other.states) &&
          window == other.window;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(states), window);
}
