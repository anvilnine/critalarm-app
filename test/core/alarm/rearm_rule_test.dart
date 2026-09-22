import 'package:critalarm/core/alarm/rearm_rule.dart';
import 'package:critalarm/core/push/incident_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 3);
  final ringUntil = now.add(const Duration(minutes: 20));

  bool ask({
    String incidentId = 'inc_9a8b7c',
    IncidentPushKind kind = IncidentPushKind.repeat,
    bool criticalOn = true,
    bool ackedLocally = false,
    DateTime? until,
    bool quietHoursHold = false,
  }) => RearmRule.canRearm(
    incidentId: incidentId,
    kind: kind,
    criticalOn: criticalOn,
    ackedLocally: ackedLocally,
    ringUntil: until ?? ringUntil,
    now: now,
    quietHoursHold: quietHoursHold,
  );

  group('RearmRule.canRearm', () {
    test('all five inputs good lets the phone set its own next ring', () {
      expect(ask(), isTrue);
    });

    test('an acked incident does not ring again', () {
      expect(ask(ackedLocally: true), isFalse);
    });

    test('a ring_until in the past stops the loop', () {
      expect(ask(until: now.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('ring_until exactly now stops the loop', () {
      expect(ask(until: now), isFalse);
    });

    test('no ring_until means the server never sent this incident', () {
      expect(
        RearmRule.canRearm(
          incidentId: 'inc_demo',
          kind: IncidentPushKind.open,
          criticalOn: true,
          ackedLocally: false,
          ringUntil: null,
          now: now,
          quietHoursHold: false,
        ),
        isFalse,
      );
    });

    test('a topic whose critical switch is off does not ring', () {
      expect(ask(criticalOn: false), isFalse);
    });

    test('quiet hours holds the ring', () {
      expect(ask(quietHoursHold: true), isFalse);
    });

    test('an empty incident id never rings', () {
      expect(ask(incidentId: ''), isFalse);
    });

    test('open, repeat and reopen all re-arm', () {
      for (final kind in [
        IncidentPushKind.open,
        IncidentPushKind.repeat,
        IncidentPushKind.reopen,
      ]) {
        expect(ask(kind: kind), isTrue, reason: kind.name);
      }
    });

    test('a forward or a state change never re-arms', () {
      for (final kind in [
        IncidentPushKind.p4,
        IncidentPushKind.p5,
        IncidentPushKind.ack,
        IncidentPushKind.close,
        IncidentPushKind.expire,
      ]) {
        expect(ask(kind: kind), isFalse, reason: kind.name);
      }
    });
  });

  group('RearmRule.nextRingAt', () {
    test('sets the next ring one repeat interval out', () {
      expect(
        RearmRule.nextRingAt(now: now, repeatIntervalS: 30),
        now.add(const Duration(seconds: 30)),
      );
    });

    test('never lands after ring_until', () {
      expect(
        RearmRule.nextRingAt(
          now: now,
          repeatIntervalS: 30,
          ringUntil: now.add(const Duration(seconds: 10)),
        ),
        isNull,
      );
    });

    test('a nonsense interval falls back to the server default', () {
      expect(
        RearmRule.nextRingAt(now: now, repeatIntervalS: 0),
        now.add(const Duration(seconds: RearmRule.defaultRepeatIntervalS)),
      );
    });
  });
}
