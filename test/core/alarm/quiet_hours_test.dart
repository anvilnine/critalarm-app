import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same rules are asserted in Swift by
/// `ios/RunnerTests/QuietHoursTests.swift`. Keep the two in step.
void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 17, hour, minute);

  int minutes(int hour, [int minute = 0]) => hour * 60 + minute;

  /// 22:00 to 07:00, with critical held too, so the window itself is what the
  /// test is looking at.
  const night = QuietHours(
    isEnabled: true,
    startMinutes: 22 * 60,
    endMinutes: 7 * 60,
    criticalRingsThrough: false,
  );

  group('a window that wraps past midnight', () {
    test('holds a time before midnight and a time after it', () {
      expect(night.containsMinute(minutes(23, 30)), isTrue);
      expect(night.containsMinute(minutes(2)), isTrue);
    });

    test('lets the daytime through', () {
      expect(night.containsMinute(minutes(9)), isFalse);
      expect(night.containsMinute(minutes(21, 59)), isFalse);
    });

    test('the start minute is inside and the end minute is outside', () {
      expect(night.containsMinute(minutes(22)), isTrue);
      expect(night.containsMinute(minutes(7)), isFalse);
    });
  });

  group('a window inside one day', () {
    const lunch = QuietHours(
      isEnabled: true,
      startMinutes: 12 * 60,
      endMinutes: 13 * 60,
      criticalRingsThrough: false,
    );

    test('holds only the hour it names', () {
      expect(lunch.containsMinute(minutes(12, 30)), isTrue);
      expect(lunch.containsMinute(minutes(11, 59)), isFalse);
      expect(lunch.containsMinute(minutes(13)), isFalse);
    });
  });

  group('start equal to end', () {
    const empty = QuietHours(
      isEnabled: true,
      startMinutes: 9 * 60,
      endMinutes: 9 * 60,
      criticalRingsThrough: false,
    );

    test('is an empty window, not a whole day', () {
      expect(empty.containsMinute(minutes(9)), isFalse);
      expect(empty.containsMinute(minutes(3)), isFalse);
      expect(empty.containsMinute(minutes(15)), isFalse);
      expect(empty.holdsRing(now: at(9), priority: 4), isFalse);
    });
  });

  group('a non-critical page', () {
    test('is held inside the window', () {
      expect(night.holdsRing(now: at(23, 30), priority: 4), isTrue);
    });

    test('rings outside the window', () {
      expect(night.holdsRing(now: at(9), priority: 4), isFalse);
    });

    test('rings with quiet hours off', () {
      const off = QuietHours(
        isEnabled: false,
        startMinutes: 22 * 60,
        endMinutes: 7 * 60,
        criticalRingsThrough: false,
      );
      expect(off.holdsRing(now: at(23, 30), priority: 4), isFalse);
    });
  });

  group('a critical page', () {
    test('rings through the window when the switch is on', () {
      const ringsThrough = QuietHours.defaults;
      expect(
        ringsThrough.holdsRing(
          now: at(23, 30),
          priority: QuietHours.criticalPriority,
        ),
        isFalse,
      );
    });

    test('is held when the switch is off', () {
      expect(
        night.holdsRing(
          now: at(23, 30),
          priority: QuietHours.criticalPriority,
        ),
        isTrue,
      );
    });
  });

  test('the defaults are off, 22:00 to 07:00, critical ringing through', () {
    // Off while the settings rows are off the alarm settings screen.
    expect(QuietHours.defaults.isEnabled, isFalse);
    expect(QuietHours.defaults.startMinutes, 1320);
    expect(QuietHours.defaults.endMinutes, 420);
    expect(QuietHours.defaults.criticalRingsThrough, isTrue);
  });

  test('minuteOf reads the local clock', () {
    expect(QuietHours.minuteOf(at(23, 30)), 1410);
    expect(QuietHours.minuteOf(at(0, 1)), 1);
  });
}
