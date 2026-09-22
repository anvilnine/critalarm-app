import 'package:critalarm/core/push/incident_push.dart';

/// Whether the phone may set its own next ring for an incident it just
/// silenced, and when that ring lands.
///
/// Stop, X, a swipe and Back all silence the alarm and nothing more. The phone
/// then rings again for the same incident at `now + repeat_interval_s`, and
/// only "I'm up" ends it. The server keeps repeating too; both are keyed to the
/// incident id, so they collapse into one alarm.
///
/// The same five inputs answer the same way in
/// `ios/Shared/Alarm/RearmRule.swift` and
/// `android/app/src/main/kotlin/app/critalarm/alarm/RearmRule.kt`. Change the
/// three together.
///
/// The app never generates an alert of its own (PRD commitment 5). A re-arm
/// re-delivers an incident the server opened, which is why every gate below
/// traces back to something the server said: the incident id came in a
/// priority-5 push, the topic's critical switch is on, and `ring_until` from
/// api.md §5.1 has not passed.
abstract final class RearmRule {
  /// What every topic is created with (api.md §3.1). Used when the topic is
  /// not in the cache, so a silenced alarm still comes back.
  static const int defaultRepeatIntervalS = 30;

  /// Kinds that mean the server opened or continued an incident. Only these
  /// ring, so only these may re-arm.
  static const Set<IncidentPushKind> ringingKinds = {
    IncidentPushKind.open,
    IncidentPushKind.repeat,
    IncidentPushKind.reopen,
  };

  static bool canRearm({
    required String incidentId,
    required IncidentPushKind kind,
    required bool criticalOn,
    required bool ackedLocally,
    required DateTime? ringUntil,
    required DateTime now,
    required bool quietHoursHold,
  }) {
    if (incidentId.isEmpty) return false;
    if (!ringingKinds.contains(kind)) return false;
    if (!criticalOn) return false;
    if (ackedLocally) return false;
    // No `ring_until` means no priority-5 alarm push from the server carried
    // this id. The onboarding demo `inc_demo` is the one that reaches here,
    // and it gets no re-arm.
    if (ringUntil == null) return false;
    if (!now.isBefore(ringUntil)) return false;
    if (quietHoursHold) return false;
    return true;
  }

  /// When the next ring lands, or null when it would fall past [ringUntil].
  static DateTime? nextRingAt({
    required DateTime now,
    required int repeatIntervalS,
    DateTime? ringUntil,
  }) {
    final seconds = repeatIntervalS > 0
        ? repeatIntervalS
        : defaultRepeatIntervalS;
    final at = now.add(Duration(seconds: seconds));
    if (ringUntil != null && !at.isBefore(ringUntil)) return null;
    return at;
  }
}
