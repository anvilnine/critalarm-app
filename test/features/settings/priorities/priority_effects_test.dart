import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/features/settings/domain/priorities/priority_effects.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('priorityPhoneFor', () {
    test('Android is Android whatever the claim says', () {
      for (final claim in RingClaim.values) {
        expect(
          priorityPhoneFor(
            platform: TargetPlatform.android,
            isWeb: false,
            claim: claim,
          ),
          PriorityPhone.android,
        );
      }
    });

    test('iOS 26 or later is the alarm phone', () {
      expect(
        priorityPhoneFor(
          platform: TargetPlatform.iOS,
          isWeb: false,
          claim: RingClaim.alarm,
        ),
        PriorityPhone.iosAlarm,
      );
    });

    test('iOS 16 to 25 is the Time-Sensitive phone', () {
      expect(
        priorityPhoneFor(
          platform: TargetPlatform.iOS,
          isWeb: false,
          claim: RingClaim.timeSensitive,
        ),
        PriorityPhone.iosTimeSensitive,
      );
    });

    test('the web never reads as an iPhone', () {
      expect(
        priorityPhoneFor(
          platform: TargetPlatform.iOS,
          isWeb: true,
          claim: RingClaim.timeSensitive,
        ),
        PriorityPhone.android,
      );
    });
  });

  group('priorityEntriesFor', () {
    test('Android: priority 5 is the full-screen alarm', () {
      final entries = priorityEntriesFor(PriorityPhone.android);
      expect(entries, const [
        PriorityEntry(5, PriorityLine.alarmAndroid),
        PriorityEntry(4, PriorityLine.notificationAndroid),
        PriorityEntry(3, PriorityLine.historyOnly),
        PriorityEntry(2, PriorityLine.historyOnly),
        PriorityEntry(1, PriorityLine.historyOnly),
      ]);
    });

    test('iOS 26 or later: priority 5 is the AlarmKit alarm', () {
      final entries = priorityEntriesFor(PriorityPhone.iosAlarm);
      expect(entries, const [
        PriorityEntry(5, PriorityLine.alarmIos),
        PriorityEntry(4, PriorityLine.notificationIos),
        PriorityEntry(3, PriorityLine.historyOnly),
        PriorityEntry(2, PriorityLine.historyOnly),
        PriorityEntry(1, PriorityLine.historyOnly),
      ]);
    });

    test('iOS 16 to 25: priority 5 is a Time-Sensitive notification', () {
      final entries = priorityEntriesFor(PriorityPhone.iosTimeSensitive);
      expect(entries, const [
        PriorityEntry(5, PriorityLine.timeSensitiveIos),
        PriorityEntry(4, PriorityLine.notificationIos),
        PriorityEntry(3, PriorityLine.historyOnly),
        PriorityEntry(2, PriorityLine.historyOnly),
        PriorityEntry(1, PriorityLine.historyOnly),
      ]);
    });

    test('an old iPhone is never given the alarm line', () {
      final lines = priorityEntriesFor(
        PriorityPhone.iosTimeSensitive,
      ).map((e) => e.line);
      expect(lines, isNot(contains(PriorityLine.alarmIos)));
      expect(lines, isNot(contains(PriorityLine.alarmAndroid)));
    });

    test('every phone lists 5 down to 1, once each', () {
      for (final phone in PriorityPhone.values) {
        expect(
          priorityEntriesFor(phone).map((e) => e.priority),
          [5, 4, 3, 2, 1],
        );
      }
    });

    test('only priority 5 can be heard', () {
      for (final phone in PriorityPhone.values) {
        final hearable = priorityEntriesFor(
          phone,
        ).where((e) => e.canHearIt).map((e) => e.priority);
        expect(hearable, [5]);
      }
    });
  });
}
