import 'dart:io';

import 'package:critalarm/core/alarm/alarm_trigger_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spike verdict', () {
    const spikePath = 'docs/specs/remote-alarm-ios-spike.md';

    test('the spike file exists', () {
      expect(
        File(spikePath).existsSync(),
        isTrue,
        reason:
            'Part A cannot be built without the spike. Run it on a device and '
            'write $spikePath.',
      );
    });

    test('the path in code is the path the spike picked', () {
      final verdict = AlarmTriggerPath.fromSpike(
        File(spikePath).readAsStringSync(),
      );
      expect(
        AlarmTriggerPath.chosen,
        verdict,
        reason:
            'AlarmTriggerPath.chosen and the spike verdict disagree. They also '
            'have to match AlarmTriggerPath.chosen in '
            'ios/Shared/Alarm/AlarmTriggerPath.swift.',
      );
    });

    test('the Swift copy names the same path', () {
      final swift = File(
        'ios/Shared/Alarm/AlarmTriggerPath.swift',
      ).readAsStringSync();
      final name = switch (AlarmTriggerPath.chosen) {
        AlarmTriggerPath.notificationServiceExtension =>
          'notificationServiceExtension',
        AlarmTriggerPath.appBackgroundPush => 'appBackgroundPush',
      };
      expect(
        swift,
        contains('static let chosen: AlarmTriggerPath = .$name'),
        reason: 'the native side is built for a different trigger path',
      );
    });
  });

  group('parsing', () {
    test('reads the verdict line', () {
      expect(
        AlarmTriggerPath.fromSpike(
          '# Spike\n\nVerdict: app-background-push\n\nNotes follow.\n',
        ),
        AlarmTriggerPath.appBackgroundPush,
      );
      expect(
        AlarmTriggerPath.fromSpike('Verdict: nse\n'),
        AlarmTriggerPath.notificationServiceExtension,
      );
    });

    test('a file with no verdict is not a finished spike', () {
      expect(
        () => AlarmTriggerPath.fromSpike('# Spike\n\nStill running.\n'),
        throwsFormatException,
      );
    });

    test('a verdict naming an unknown path fails loudly', () {
      expect(
        () => AlarmTriggerPath.fromSpike('Verdict: carrier-pigeon\n'),
        throwsFormatException,
      );
    });
  });
}
