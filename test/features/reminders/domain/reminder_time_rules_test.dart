import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/features/reminders/domain/reminder_time_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const off = ReminderTimeRules(quietHours: QuietHours.defaults);

  group('allows', () {
    test('never between 22:00 and 08:00', () {
      expect(off.allows(DateTime(2026, 9, 22, 7, 59)), isFalse);
      expect(off.allows(DateTime(2026, 9, 22, 8)), isTrue);
      expect(off.allows(DateTime(2026, 9, 22, 21, 59)), isTrue);
      expect(off.allows(DateTime(2026, 9, 22, 22)), isFalse);
    });

    test('never inside the user quiet hours when they are on', () {
      const rules = ReminderTimeRules(
        quietHours: QuietHours(
          isEnabled: true,
          startMinutes: 9 * 60,
          endMinutes: 11 * 60,
          criticalRingsThrough: true,
        ),
      );
      expect(rules.allows(DateTime(2026, 9, 22, 10)), isFalse);
      expect(rules.allows(DateTime(2026, 9, 22, 11)), isTrue);
    });

    test('quiet hours that are switched off change nothing', () {
      const rules = ReminderTimeRules(
        quietHours: QuietHours(
          isEnabled: false,
          startMinutes: 9 * 60,
          endMinutes: 11 * 60,
          criticalRingsThrough: true,
        ),
      );
      expect(rules.allows(DateTime(2026, 9, 22, 10)), isTrue);
    });

    test('never within 2 hours after a ring known now', () {
      final rules = ReminderTimeRules(
        quietHours: QuietHours.defaults,
        ringsAt: [DateTime(2026, 9, 26, 9, 30)],
      );
      expect(rules.allows(DateTime(2026, 9, 26, 11)), isFalse);
      expect(rules.allows(DateTime(2026, 9, 26, 11, 30)), isTrue);
      // A ring after the fire time does not count.
      expect(rules.allows(DateTime(2026, 9, 26, 9)), isTrue);
    });
  });

  group('nextAllowed', () {
    test('keeps an allowed time as it is', () {
      final at = DateTime(2026, 9, 22, 15, 37);
      expect(off.nextAllowed(at), at);
    });

    test('moves a late evening time to 10:00 next day', () {
      expect(
        off.nextAllowed(DateTime(2026, 9, 22, 23)),
        DateTime(2026, 9, 23, 10),
      );
    });

    test('tries later hours before giving up on a day', () {
      const rules = ReminderTimeRules(
        quietHours: QuietHours(
          isEnabled: true,
          startMinutes: 9 * 60,
          endMinutes: 11 * 60,
          criticalRingsThrough: true,
        ),
      );
      expect(
        rules.nextAllowed(DateTime(2026, 9, 26, 10)),
        DateTime(2026, 9, 26, 11),
      );
    });

    test('steps a week at a time when asked, for the Saturday drill', () {
      final rules = ReminderTimeRules(
        quietHours: QuietHours.defaults,
        ringsAt: [DateTime(2026, 9, 26, 20)],
      );
      // 21:30 is inside the two hours after the 20:00 ring and nothing later
      // that day is open, so it moves a whole week.
      expect(
        rules.nextAllowed(DateTime(2026, 9, 26, 21, 30), stepDays: 7),
        DateTime(2026, 10, 3, 10),
      );
    });

    test('skips past a ring by whole hours', () {
      final rules = ReminderTimeRules(
        quietHours: QuietHours.defaults,
        ringsAt: [DateTime(2026, 9, 26, 9, 30)],
      );
      expect(
        rules.nextAllowed(DateTime(2026, 9, 26, 10), stepDays: 7),
        DateTime(2026, 9, 26, 12),
      );
    });
  });
}
