import 'dart:async';

import 'package:critalarm/features/onboarding/presentation/model/hook_up_leaving.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  late Completer<void> tick;
  var isHere = true;

  HookUpLeaving build() => HookUpLeaving(
    finishAndGoNext: () => calls.add('next'),
    finishStep: () async => calls.add('finish'),
    openAlarm: (id) => calls.add('alarm:$id'),
    wait: () => tick.future,
    isStillHere: () => isHere,
    forgetFirstTool: () => calls.add('forget'),
  );

  setUp(() {
    calls = [];
    tick = Completer<void>();
    isHere = true;
  });

  test('Done finishes the step and moves on, once', () {
    final leaving = build()
      ..done()
      ..done();

    expect(calls, ['forget', 'next']);
    expect(leaving.hasLeft, isTrue);
  });

  test(
    'an alarm waits for the tick, finishes the step, then opens it',
    () async {
      final leaving = build();

      final handover = leaving.alarm('inc_1');
      await pumpEventQueue();
      expect(calls, isEmpty, reason: 'the row gets its moment first');

      tick.complete();
      await handover;

      expect(calls, ['finish', 'alarm:inc_1']);
    },
  );

  test('a second alarm is not handed over', () async {
    final leaving = build();

    final first = leaving.alarm('inc_1');
    final second = leaving.alarm('inc_2');
    tick.complete();
    await Future.wait([first, second]);

    expect(calls, ['finish', 'alarm:inc_1']);
  });

  test(
    'Done during the tick delay does nothing: the alarm takes over',
    () async {
      final leaving = build();

      final handover = leaving.alarm('inc_1');
      leaving.done();
      tick.complete();
      await handover;

      expect(calls, ['finish', 'alarm:inc_1']);
    },
  );

  test('an alarm after Done opens nothing and finishes nothing', () async {
    final leaving = build()..done();
    tick.complete();

    await leaving.alarm('inc_1');

    // Only the record of that alarm is taken back.
    expect(calls, ['forget', 'next', 'forget']);
  });

  test(
    'when the user is already elsewhere the step is still finished',
    () async {
      // A tap on the alarm's notification got there first.
      final leaving = build();

      final handover = leaving.alarm('inc_1');
      isHere = false;
      tick.complete();
      await handover;

      expect(calls, ['finish'], reason: 'no second move on top of theirs');
    },
  );

  test('an alarm that rings after Done is not owed the setup screen', () async {
    final leaving = build()..done();
    calls.clear();

    await leaving.alarm('inc_1');

    expect(calls, ['forget']);
  });

  test('the alarm path keeps the record it is about to use', () async {
    final leaving = build();

    final handover = leaving.alarm('inc_1');
    tick.complete();
    await handover;

    expect(calls, isNot(contains('forget')));
  });
}
