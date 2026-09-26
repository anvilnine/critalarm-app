import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/domain/planned_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalReminderKind', () {
    test('reads back from its wire name', () {
      for (final kind in LocalReminderKind.values) {
        expect(LocalReminderKind.fromWire(kind.wireName), kind);
      }
      expect(LocalReminderKind.fromWire('nope'), isNull);
    });

    test('only the morning after and the Pro notice are offers', () {
      expect(
        LocalReminderKind.values.where((k) => k.isOffer),
        [LocalReminderKind.morningAfter, LocalReminderKind.proLater],
      );
    });

    test('plan heads-up and the Pro notice skip the weekly budget', () {
      expect(
        LocalReminderKind.values.where((k) => !k.usesBudget),
        [LocalReminderKind.planHeadsUp, LocalReminderKind.proLater],
      );
    });

    test('priority runs 1 > 10 > 2 > 7 > 21 > 22', () {
      final order = [
        LocalReminderKind.fireDrill,
        LocalReminderKind.morningAfter,
        LocalReminderKind.silentTopic,
        LocalReminderKind.backup,
        LocalReminderKind.reviewAsk,
        LocalReminderKind.feedbackAsk,
      ];
      for (var i = 0; i < order.length - 1; i++) {
        expect(order[i].priority, lessThan(order[i + 1].priority));
      }
    });

    test('faces follow the spec for 21 and 22', () {
      expect(LocalReminderKind.reviewAsk.face, LocalReminderFace.happy);
      expect(LocalReminderKind.feedbackAsk.face, LocalReminderFace.watching);
      expect(
        LocalReminderFace.happy.assetPath,
        'assets/reminder_faces/happy.png',
      );
    });
  });

  group('LocalReminderIds', () {
    test('planned ranges match the spec', () {
      expect(LocalReminderIds.isPlanned(9100), isTrue);
      expect(LocalReminderIds.isPlanned(9250), isTrue);
      expect(LocalReminderIds.isPlanned(9300), isTrue);
      expect(LocalReminderIds.isPlanned(9352), isTrue);
      expect(LocalReminderIds.isPlanned(9400), isTrue);
      expect(LocalReminderIds.isPlanned(9410), isTrue);
      expect(LocalReminderIds.isPlanned(9500), isTrue);
      expect(LocalReminderIds.isPlanned(9510), isTrue);
      expect(LocalReminderIds.isPlanned(9301), isFalse);
      expect(LocalReminderIds.isPlanned(1234), isFalse);
    });

    test('kindOf maps every planned range to its kind', () {
      expect(LocalReminderIds.kindOf(9150), LocalReminderKind.fireDrill);
      expect(LocalReminderIds.kindOf(9250), LocalReminderKind.silentTopic);
      expect(LocalReminderIds.kindOf(9300), LocalReminderKind.backup);
      expect(LocalReminderIds.kindOf(9352), LocalReminderKind.planHeadsUp);
      expect(LocalReminderIds.kindOf(9400), LocalReminderKind.morningAfter);
      expect(LocalReminderIds.kindOf(9410), LocalReminderKind.proLater);
      expect(LocalReminderIds.kindOf(9500), LocalReminderKind.reviewAsk);
      expect(LocalReminderIds.kindOf(9510), LocalReminderKind.feedbackAsk);
      expect(LocalReminderIds.kindOf(9301), isNull);
      expect(
        LocalReminderIds.kindOf(LocalReminderIds.lab(LocalReminderKind.backup)),
        isNull,
      );
    });

    test('lab ids are reminders but never planned', () {
      final id = LocalReminderIds.lab(LocalReminderKind.backup);
      expect(LocalReminderIds.isReminder(id), isTrue);
      expect(LocalReminderIds.isPlanned(id), isFalse);
    });

    test('silent topic ids stay inside their range', () {
      expect(LocalReminderIds.silent(0), 9200);
      expect(LocalReminderIds.silent(150), inInclusiveRange(9200, 9299));
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
      expect(record.kind, LocalReminderKind.backup);
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

  group('LocalReminderSwitches', () {
    test('defaults are Reminders on and Offers off', () {
      expect(LocalReminderSwitches.defaults.reminders, isTrue);
      expect(LocalReminderSwitches.defaults.offers, isFalse);
    });

    test('offers kinds follow the Offers switch', () {
      const switches = LocalReminderSwitches(reminders: false, offers: true);
      expect(switches.allows(LocalReminderKind.morningAfter), isTrue);
      expect(switches.allows(LocalReminderKind.fireDrill), isFalse);
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

  group('LocalReminderDates', () {
    test('atHourOnOrAfter moves to tomorrow once the hour has passed', () {
      expect(
        LocalReminderDates.atHourOnOrAfter(DateTime(2026, 9, 22, 11), 10),
        DateTime(2026, 9, 23, 10),
      );
      expect(
        LocalReminderDates.atHourOnOrAfter(DateTime(2026, 9, 22, 9), 10),
        DateTime(2026, 9, 22, 10),
      );
    });

    test('weekdayAtHourOnOrAfter finds the next Saturday at 10:00', () {
      // 22 September 2026 is a Tuesday.
      expect(
        LocalReminderDates.weekdayAtHourOnOrAfter(
          DateTime(2026, 9, 22, 12),
          DateTime.saturday,
          10,
        ),
        DateTime(2026, 9, 26, 10),
      );
      // A Saturday after 10:00 waits a week.
      expect(
        LocalReminderDates.weekdayAtHourOnOrAfter(
          DateTime(2026, 9, 26, 11),
          DateTime.saturday,
          10,
        ),
        DateTime(2026, 10, 3, 10),
      );
    });

    test('daysBetween counts calendar days', () {
      expect(
        LocalReminderDates.daysBetween(
          DateTime(2026, 8, 20, 23),
          DateTime(2026, 9, 26, 1),
        ),
        37,
      );
    });

    test('hasRingWithin looks back from the fire time only', () {
      final incidents = [
        LocalReminderIncident(
          id: 'inc_1',
          topic: 'prod-db',
          openedAt: DateTime(2026, 9, 22, 9),
        ),
      ];
      final fireAt = DateTime(2026, 9, 22, 10);
      expect(
        LocalReminderDates.hasRingWithin(
          incidents,
          fireAt,
          const Duration(hours: 2),
        ),
        isTrue,
      );
      expect(
        LocalReminderDates.hasRingWithin(
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
