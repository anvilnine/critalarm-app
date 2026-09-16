import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/push/push_host.dart';

/// What a running app does with a push.
///
/// It sits beside the root widget rather than inside it so it can be tested
/// without pumping one. Three jobs:
///
/// - a notification tapped while the app is running opens its screen;
/// - a push that lands while the app is open reloads the shared incident
///   list, so the screen the user is already on catches up;
/// - coming back from the background asks the platform for a tap it may still
///   be holding, and opens that screen before the lists reload.
///
/// Nothing here fetches on a timer and nothing holds its own copy of the
/// data. Both cubits are the app's only lists.
class AppPushBindings {
  AppPushBindings(this._push, this._incidents, this._topics, this._navigate);

  final PushHost _push;
  final IncidentsCubit _incidents;
  final TopicsCubit _topics;
  final void Function(String location) _navigate;

  StreamSubscription<String>? _taps;
  StreamSubscription<void>? _pushes;

  void start() {
    // A tap that lands while the app is already in front. There is no resume
    // to hang it off, so it opens its screen as it arrives.
    _taps = _push.deepLinks.listen(_navigate);
    // A push the user has not touched. Only incidents can have changed, and
    // the push carries an id rather than the incident, so the shared list is
    // asked again instead of being handed something.
    _pushes = _push.foregroundPushes.listen((_) {
      unawaited(_incidents.refresh());
    });
  }

  /// Coming back to the app, in the order that matters.
  ///
  /// The tap that woke the app is asked for first and opens its screen first;
  /// the lists reload after. Reloading first is what made Home paint, show a
  /// refresh, and only then jump to the incident.
  Future<void> onResumed() async {
    final route = await _push.takePendingRoute();
    if (route != null) _navigate(route);
    await reload();
  }

  /// Reloads the shared lists. A page can land while the phone is in a
  /// pocket, and the whole point of this app is showing it.
  Future<void> reload() =>
      Future.wait([_incidents.refresh(), _topics.refresh()]);

  Future<void> dispose() async {
    await _taps?.cancel();
    await _pushes?.cancel();
  }
}
