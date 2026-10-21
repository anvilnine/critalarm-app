import 'dart:async';

import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';

/// Whether the alarm screen draws its ringing layout for [state]: an
/// incident that is live, not acknowledged and not answered elsewhere. The
/// same order `CriticalAlarmScreen` picks its layout in.
bool showsRingingLayout(CriticalAlarmState state) =>
    !state.isHandledElsewhere && state.isLive && !state.isAcknowledged;

/// When the alarm screen lets the app window leave the lock screen.
///
/// On Android an alarm opens the app over the lock screen, so a ringing phone
/// can be answered without the PIN. The same window holds Home, topics and
/// Settings. It may only stay over the lock screen while a ringing alarm
/// screen is in front, so this tells the native side when that stops:
///
/// - The screen stops showing a ringing alarm: it was acknowledged, closed,
///   or answered somewhere else.
/// - The screen opens another screen on top, such as the topic's messages.
///   Coming back to a screen that still rings holds the window again.
/// - The screen goes away.
///
/// A screen that starts ringing holds the window. That covers an alarm that
/// reaches the app while it is already in front, where no alarm start
/// reached the native side. A switch from one ringing incident to the next,
/// after "I'm up" on one of two alarms, keeps the window: the screen still
/// rings.
///
/// Native decides in the end (`AlarmLockRule`): a release for an alarm that
/// another one has replaced changes nothing, and a hold for an incident that
/// owes no ack is refused.
///
/// A release answers once the window has left the lock screen: at once on
/// an unlocked phone, after the unlock prompt on a locked one. Until then
/// [mayShowOverLock] stays true, and the screen keeps its ringing layout
/// rather than draw the acknowledged or failure layout over the lock
/// screen. [onSettled] says when to look again.
final class LockScreenHold {
  LockScreenHold({
    required this.release,
    required this.hold,
    this.onSettled,
    this.holdsWindow = true,
    this.answerWithin = const Duration(seconds: 15),
  });

  final Future<void> Function(String? incidentId) release;
  final void Function(String incidentId) hold;

  /// A release answered, so [mayShowOverLock] may have changed.
  final void Function()? onSettled;

  /// False where no window shows over the lock screen (iOS), so nothing
  /// waits on a release there.
  final bool holdsWindow;

  /// A release native never answers stops holding the layout after this.
  final Duration answerWithin;

  /// The ringing incident on screen, or null while nothing rings.
  String? _ringing;

  /// Another screen is on top of this one.
  bool _isCovered = false;

  /// Releases sent and not answered yet, each with the timer that stops
  /// waiting for it.
  final Set<Timer> _waiting = {};

  /// Whether the window may still be over the lock screen for this screen:
  /// it rings in front, or a release has not been answered. While this is
  /// true the screen draws nothing but its ringing layout.
  bool get mayShowOverLock =>
      holdsWindow && ((_ringing != null && !_isCovered) || _waiting.isNotEmpty);

  Future<void> _send(String? incidentId) {
    try {
      return release(incidentId);
    } on Object catch (_) {
      return Future.value();
    }
  }

  /// A release the screen waits for before it draws the next layout.
  void _releaseAndWait(String? incidentId) {
    late final Timer timer;
    void settle() {
      if (!_waiting.remove(timer)) return;
      timer.cancel();
      onSettled?.call();
    }

    timer = Timer(answerWithin, settle);
    _waiting.add(timer);
    unawaited(
      _send(incidentId).then((_) => settle(), onError: (_) => settle()),
    );
  }

  /// The screen drew a new state. [isRinging] is true for the ringing layout.
  void show({required String? incidentId, required bool isRinging}) {
    if (isRinging && incidentId != null) {
      final was = _ringing;
      _ringing = incidentId;
      if (was != incidentId && !_isCovered) hold(incidentId);
      return;
    }
    final was = _ringing;
    if (was == null) return;
    _ringing = null;
    if (!_isCovered) _releaseAndWait(was);
  }

  /// Another screen opened on top. Nothing over the alarm screen may show
  /// over the lock screen.
  void cover() {
    if (_isCovered) return;
    _isCovered = true;
    // Nothing to wait for: the screen on top is what shows.
    final ringing = _ringing;
    if (ringing != null) unawaited(_send(ringing).catchError((Object _) {}));
  }

  /// The screen on top closed. A screen that still rings holds the window.
  void uncover() {
    if (!_isCovered) return;
    _isCovered = false;
    final ringing = _ringing;
    if (ringing != null) hold(ringing);
  }

  /// The alarm screen is gone. [routeIncidentId] is the incident the route
  /// named, for a screen that never got as far as ringing.
  void leave(String? routeIncidentId) {
    final ringing = _ringing;
    _ringing = null;
    // The screen is gone, so nothing waits for the answer.
    for (final timer in _waiting) {
      timer.cancel();
    }
    _waiting.clear();
    unawaited(_send(ringing ?? routeIncidentId).catchError((Object _) {}));
  }
}
