import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderKind', () {
    test('reads back from its wire name', () {
      for (final kind in ReminderKind.values) {
        expect(ReminderKind.fromWire(kind.wireName), kind);
      }
      expect(ReminderKind.fromWire('nope'), isNull);
    });

    test('only the morning after and the Pro notice are offers', () {
      expect(
        ReminderKind.values.where((k) => k.isOffer),
        [ReminderKind.morningAfter, ReminderKind.proLater],
      );
    });

    test('plan heads-up and the Pro notice skip the weekly budget', () {
      expect(
        ReminderKind.values.where((k) => !k.usesBudget),
        [ReminderKind.planHeadsUp, ReminderKind.proLater],
      );
    });

    test('priority runs 1 > 10 > 2 > 7 > 21 > 22', () {
      final order = [
        ReminderKind.fireDrill,
        ReminderKind.morningAfter,
        ReminderKind.silentTopic,
        ReminderKind.backup,
        ReminderKind.reviewAsk,
        ReminderKind.feedbackAsk,
      ];
      for (var i = 0; i < order.length - 1; i++) {
        expect(order[i].priority, lessThan(order[i + 1].priority));
      }
    });

    test('faces follow the spec for 21 and 22', () {
      expect(ReminderKind.reviewAsk.face, ReminderFace.happy);
      expect(ReminderKind.feedbackAsk.face, ReminderFace.watching);
      expect(
        ReminderFace.happy.assetPath,
        'assets/reminder_faces/happy.png',
      );
    });
  });

  group('ReminderIds', () {
    test('planned ranges match the spec', () {
      expect(ReminderIds.isPlanned(9100), isTrue);
      expect(ReminderIds.isPlanned(9250), isTrue);
      expect(ReminderIds.isPlanned(9300), isTrue);
      expect(ReminderIds.isPlanned(9352), isTrue);
      expect(ReminderIds.isPlanned(9400), isTrue);
      expect(ReminderIds.isPlanned(9410), isTrue);
      expect(ReminderIds.isPlanned(9500), isTrue);
      expect(ReminderIds.isPlanned(9510), isTrue);
      expect(ReminderIds.isPlanned(9301), isFalse);
      expect(ReminderIds.isPlanned(1234), isFalse);
    });

    test('kindOf maps every planned range to its kind', () {
      expect(ReminderIds.kindOf(9150), ReminderKind.fireDrill);
      expect(ReminderIds.kindOf(9250), ReminderKind.silentTopic);
      expect(ReminderIds.kindOf(9300), ReminderKind.backup);
      expect(ReminderIds.kindOf(9352), ReminderKind.planHeadsUp);
      expect(ReminderIds.kindOf(9400), ReminderKind.morningAfter);
      expect(ReminderIds.kindOf(9410), ReminderKind.proLater);
      expect(ReminderIds.kindOf(9500), ReminderKind.reviewAsk);
      expect(ReminderIds.kindOf(9510), ReminderKind.feedbackAsk);
      expect(ReminderIds.kindOf(9301), isNull);
      expect(ReminderIds.kindOf(ReminderIds.lab(ReminderKind.backup)), isNull);
    });

    test('lab ids are reminders but never planned', () {
      final id = ReminderIds.lab(ReminderKind.backup);
      expect(ReminderIds.isReminder(id), isTrue);
      expect(ReminderIds.isPlanned(id), isFalse);
    });

    test('silent topic ids stay inside their range', () {
      expect(ReminderIds.silent(0), 9200);
      expect(ReminderIds.silent(150), inInclusiveRange(9200, 9299));
    });
  });

  group('PlannedRecord.tryParse', () {
    test('reads a record back', () {
      final record = PlannedRecord.tryParse({
        'id': 9300,
        'kind': 'backup',
        'fire_at': 1000,
        'dedupe_key': 'k',
        'pool': 2,
      })!;
      expect(record.kind, ReminderKind.backup);
      expect(record.dedupeKey, 'k');
      expect(record.poolIndex, 2);
    });

    test('answers null for fields of the wrong type, never throws', () {
      final base = {'id': 9300, 'kind': 'backup', 'fire_at': 1000};
      expect(PlannedRecord.tryParse({...base, 'kind': 4}), isNull);
      expect(PlannedRecord.tryParse({...base, 'dedupe_key': 4}), isNull);
      expect(PlannedRecord.tryParse({...base, 'pool': 'two'}), isNull);
    });
  });

  group('ReminderSwitches', () {
    test('defaults are Reminders on and Offers off', () {
      expect(ReminderSwitches.defaults.reminders, isTrue);
      expect(ReminderSwitches.defaults.offers, isFalse);
    });

    test('offers kinds follow the Offers switch', () {
      const switches = ReminderSwitches(reminders: false, offers: true);
      expect(switches.allows(ReminderKind.morningAfter), isTrue);
      expect(switches.allows(ReminderKind.fireDrill), isFalse);
    });
  });

  group('DeviceTimeZone', () {
    const manila = DeviceTimeZone(name: 'Asia/Manila', offsetMinutes: 480);

    test('turns an instant into wall-clock time', () {
      final wall = manila.toWall(DateTime.utc(2026, 9, 22, 2));
      expect(wall, DateTime(2026, 9, 22, 10));
    });

    test('turns wall-clock time back into the same instant', () {
      expect(
        manila.toInstant(DateTime(2026, 9, 22, 10)),
        DateTime.utc(2026, 9, 22, 2),
      );
    });

    test('a zone change moves the wall clock, not the instant', () {
      const tokyo = DeviceTimeZone(name: 'Asia/Tokyo', offsetMinutes: 540);
      final instant = DateTime.utc(2026, 9, 22, 2);
      expect(tokyo.toWall(instant), DateTime(2026, 9, 22, 11));
      // Saturday 10:00 is a different instant in each zone, which is why a
      // plan pass re-plans after every resume.
      expect(
        tokyo.toInstant(DateTime(2026, 9, 26, 10)),
        isNot(manila.toInstant(DateTime(2026, 9, 26, 10))),
      );
    });
  });

  group('ReminderDates', () {
    test('atHourOnOrAfter moves to tomorrow once the hour has passed', () {
      expect(
        ReminderDates.atHourOnOrAfter(DateTime(2026, 9, 22, 11), 10),
        DateTime(2026, 9, 23, 10),
      );
      expect(
        ReminderDates.atHourOnOrAfter(DateTime(2026, 9, 22, 9), 10),
        DateTime(2026, 9, 22, 10),
      );
    });

    test('weekdayAtHourOnOrAfter finds the next Saturday at 10:00', () {
      // 22 September 2026 is a Tuesday.
      expect(
        ReminderDates.weekdayAtHourOnOrAfter(
          DateTime(2026, 9, 22, 12),
          DateTime.saturday,
          10,
        ),
        DateTime(2026, 9, 26, 10),
      );
      // A Saturday after 10:00 waits a week.
      expect(
        ReminderDates.weekdayAtHourOnOrAfter(
          DateTime(2026, 9, 26, 11),
          DateTime.saturday,
          10,
        ),
        DateTime(2026, 10, 3, 10),
      );
    });

    test('daysBetween counts calendar days', () {
      expect(
        ReminderDates.daysBetween(
          DateTime(2026, 8, 20, 23),
          DateTime(2026, 9, 26, 1),
        ),
        37,
      );
    });

    test('hasRingWithin looks back from the fire time only', () {
      final incidents = [
        ReminderIncident(
          id: 'inc_1',
          topic: 'prod-db',
          openedAt: DateTime(2026, 9, 22, 9),
        ),
      ];
      final fireAt = DateTime(2026, 9, 22, 10);
      expect(
        ReminderDates.hasRingWithin(
          incidents,
          fireAt,
          const Duration(hours: 2),
        ),
        isTrue,
      );
      expect(
        ReminderDates.hasRingWithin(
          incidents,
          fireAt,
          const Duration(minutes: 30),
        ),
        isFalse,
      );
    });
  });

  group('IncidentKinds.isTest', () {
    test('knows the demo alarm and a server test alarm', () {
      expect(
        IncidentKinds.isTest(const Incident(id: 'inc_demo', topic: 'x')),
        isTrue,
      );
      expect(
        IncidentKinds.isTest(
          const Incident(
            id: 'inc_1',
            topic: 'prod-db',
            messages: [
              Message(id: 'm1', topic: 'prod-db', title: 'Crit Alarm test'),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('a page from a real source is not a test', () {
      expect(
        IncidentKinds.isTest(
          const Incident(
            id: 'inc_2',
            topic: 'prod-db',
            messages: [Message(id: 'm2', topic: 'prod-db', title: 'disk')],
          ),
        ),
        isFalse,
      );
    });
  });
}
