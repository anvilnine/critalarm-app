import 'dart:async';

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
      hold = LockScreenHold(
        release: (id) async => released.add(id),
        hold: held.add,
      );
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

  group('LockScreenHold before the window has left the lock screen', () {
    late List<String?> released;
    late Completer<void> answer;
    late int settled;

    LockScreenHold make({
      bool holdsWindow = true,
      Duration answerWithin = const Duration(seconds: 15),
    }) {
      released = [];
      answer = Completer<void>();
      settled = 0;
      return LockScreenHold(
        release: (id) {
          released.add(id);
          return answer.future;
        },
        hold: (_) {},
        onSettled: () => settled++,
        holdsWindow: holdsWindow,
        answerWithin: answerWithin,
      );
    }

    test('nothing rang yet: the screen may draw what it likes', () {
      final hold = make()..show(incidentId: null, isRinging: false);
      expect(hold.mayShowOverLock, isFalse);
    });

    test('a ringing screen is over the lock screen', () {
      final hold = make()..show(incidentId: 'inc_a', isRinging: true);
      expect(hold.mayShowOverLock, isTrue);
    });

    test(
      'an acknowledge holds the ringing layout until native answers',
      () async {
        final hold = make()
          ..show(incidentId: 'inc_a', isRinging: true)
          ..show(incidentId: 'inc_a', isRinging: false);
        expect(released, ['inc_a']);
        await pumpEventQueue();
        // The release is out, and the window may still be over the lock.
        expect(hold.mayShowOverLock, isTrue);
        expect(settled, 0);

        answer.complete();
        await pumpEventQueue();

        expect(hold.mayShowOverLock, isFalse);
        expect(settled, 1);
      },
    );

    test('a release that fails still lets the screen go on', () async {
      final hold = make()
        ..show(incidentId: 'inc_a', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: false);

      answer.completeError(StateError('channel gone'));
      await pumpEventQueue();

      expect(hold.mayShowOverLock, isFalse);
      expect(settled, 1);
    });

    test(
      'a release native never answers stops holding after a while',
      () async {
        final hold = make(answerWithin: const Duration(milliseconds: 50))
          ..show(incidentId: 'inc_a', isRinging: true)
          ..show(incidentId: 'inc_a', isRinging: false);
        await pumpEventQueue();
        expect(hold.mayShowOverLock, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(hold.mayShowOverLock, isFalse);
        expect(settled, 1);
      },
    );

    test(
      'leaving the screen stops waiting, and a late answer is quiet',
      () async {
        final hold = make()
          ..show(incidentId: 'inc_a', isRinging: true)
          ..show(incidentId: 'inc_a', isRinging: false)
          ..leave('inc_a');
        expect(hold.mayShowOverLock, isFalse);
        expect(released, ['inc_a', 'inc_a']);

        answer.complete();
        await pumpEventQueue();

        expect(settled, 0);
      },
    );

    test('iOS shows no window over the lock screen, so nothing waits', () {
      final hold = make(holdsWindow: false)
        ..show(incidentId: 'inc_a', isRinging: true)
        ..show(incidentId: 'inc_a', isRinging: false);
      expect(hold.mayShowOverLock, isFalse);
    });

    test('the topic on top: the alarm screen is not what shows', () {
      final hold = make()..show(incidentId: 'inc_a', isRinging: true);
      answer.complete();
      hold.cover();
      expect(released, ['inc_a']);
    });
  });
}
