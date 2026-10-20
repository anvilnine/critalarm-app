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
final class LockScreenHold {
  LockScreenHold({required this.release, required this.hold});

  final void Function(String? incidentId) release;
  final void Function(String incidentId) hold;

  /// The ringing incident on screen, or null while nothing rings.
  String? _ringing;

  /// Another screen is on top of this one.
  bool _isCovered = false;

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
    if (!_isCovered) release(was);
  }

  /// Another screen opened on top. Nothing over the alarm screen may show
  /// over the lock screen.
  void cover() {
    if (_isCovered) return;
    _isCovered = true;
    final ringing = _ringing;
    if (ringing != null) release(ringing);
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
    release(ringing ?? routeIncidentId);
  }
}
