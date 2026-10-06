import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_host.dart';

void main() {
  late FakeAlarmHost alarm;

  setUp(() => alarm = FakeAlarmHost());
  tearDown(() => alarm.dispose());

  test('a magic tap from the phone reaches the stream', () async {
    final taps = <void>[];
    final sub = alarm.host.magicTaps.listen(taps.add);
    addTearDown(sub.cancel);

    await alarm.emitMagicTap();
    await Future<void>.delayed(Duration.zero);

    expect(taps, hasLength(1));
  });

  test('nothing is on the stream until the phone sends one', () async {
    final taps = <void>[];
    final sub = alarm.host.magicTaps.listen(taps.add);
    addTearDown(sub.cancel);

    await alarm.emitAlarmScheduled('inc_1');
    await Future<void>.delayed(Duration.zero);

    expect(taps, isEmpty);
  });

  test('arming and disarming tell the phone which', () async {
    await alarm.host.setMagicTapArmed(isArmed: true);
    await alarm.host.setMagicTapArmed(isArmed: false);

    expect(alarm.argsTo('setMagicTapArmed').map((a) => a['armed']), [
      true,
      false,
    ]);
  });

  test('a platform with no handler is left alone', () async {
    alarm.dispose();
    const channel = MethodChannel(AlarmHost.channelName);

    await expectLater(
      AlarmHost(channel).setMagicTapArmed(isArmed: true),
      completes,
    );
  });
}
