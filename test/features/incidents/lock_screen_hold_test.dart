import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen_hold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showsRingingLayout', () {
    test('a live alarm nobody answered rings', () {
      expect(
        showsRingingLayout(const CriticalAlarmState(isLive: true)),
        isTrue,
      );
    });

    test('acknowledged, answered elsewhere or loading does not', () {
      expect(
        showsRingingLayout(
          const CriticalAlarmState(isLive: true, isAcknowledged: true),
        ),
        isFalse,
      );
      expect(
        showsRingingLayout(
          const CriticalAlarmState(isLive: true, isHandledElsewhere: true),
        ),
        isFalse,
      );
      expect(
        showsRingingLayout(
          const CriticalAlarmState(status: CriticalAlarmStatus.loading),
        ),
        isFalse,
      );
    });
  });

  group('LockScreenHold', () {
    late List<String?> released;
    late List<String> held;
    late LockScreenHold hold;

    setUp(() {
      released = [];
      held = [];
      hold = LockScreenHold(release: released.add, hold: held.add);
    });

    test('loading, then ringing, holds the window and lets nothing go', () {
      hold
        ..show(incidentId: null, isRinging: false)
        ..show(incidentId: 'inc_a', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: true);
      expect(released, isEmpty);
      expect(held, ['inc_a']);
    });

    test('acknowledging lets go of the incident that rang', () {
      hold
        ..show(incidentId: 'inc_a', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: false);
      expect(released, ['inc_a']);
    });

    test('a second state that does not ring lets go only once', () {
      hold
        ..show(incidentId: 'inc_a', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: false)
        ..show(incidentId: 'inc_a', isRinging: false);
      expect(released, ['inc_a']);
    });

    test('"I\'m up" on one of two alarms keeps the window for the next', () {
      hold
        ..show(incidentId: 'inc_b', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: true);
      expect(released, isEmpty);
      expect(held, ['inc_b', 'inc_a']);
      hold.show(incidentId: 'inc_a', isRinging: false);
      expect(released, ['inc_a']);
    });

    test('opening the topic lets go, and coming back holds again', () {
      hold
        ..show(incidentId: 'inc_a', isRinging: true)
        ..cover();
      expect(released, ['inc_a']);
      hold.uncover();
      expect(held, ['inc_a', 'inc_a']);
    });

    test('an alarm answered while the topic was open is not held again', () {
      hold
        ..show(incidentId: 'inc_a', isRinging: true)
        ..cover()
        ..show(incidentId: 'inc_a', isRinging: false)
        ..uncover();
      expect(released, ['inc_a']);
      expect(held, ['inc_a']);
    });

    test('leaving the screen lets go, even before it rang', () {
      hold.leave('inc_route');
      expect(released, ['inc_route']);
    });

    test('leaving a ringing screen lets go of the incident on it', () {
      hold
        ..show(incidentId: 'inc_b', isRinging: true)
        ..leave('inc_a');
      expect(released, ['inc_b']);
    });
  });
}
