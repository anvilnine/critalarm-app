import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/planned_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';

void main() {
  late SharedPrefsLocalReminderStore store;
  late FakeInAppNoticeRepository notices;
  late LocalReminderSettler settler;
  final fireAt = DateTime(2026, 9, 24, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    notices = FakeInAppNoticeRepository();
    settler = LocalReminderSettler(store: store, notices: notices);
  });

  group('settleAsks', () {
    test('counts a passed review ask once, at its fire time', () async {
      await store.writeReviewFireAt(fireAt);
      await settler.settleAsks(now: fireAt.add(const Duration(minutes: 1)));
      await settler.settleAsks(now: fireAt.add(const Duration(hours: 5)));
      expect(notices.reviewAskCount, 1);
      expect(notices.reviewAskedAt, fireAt);
      expect(store.readReviewFireAt(), isNull);
    });

    test('leaves a review ask that has not fired yet', () async {
      await store.writeReviewFireAt(fireAt);
      await settler.settleAsks(now: fireAt.subtract(const Duration(hours: 1)));
      expect(notices.reviewAskCount, 0);
      expect(store.readReviewFireAt(), fireAt);
    });

    test('counts a passed feedback ask at its fire time', () async {
      await store.writeFeedbackFireAt(fireAt);
      await settler.settleAsks(now: fireAt.add(const Duration(minutes: 1)));
      expect(notices.feedbackAskedAt, fireAt);
      expect(store.readFeedbackFireAt(), isNull);
    });

    test('after a settled review ask, home and Pro wait 24 hours', () async {
      await store.writeReviewFireAt(fireAt);
      await settler.settleAsks(now: fireAt.add(const Duration(minutes: 1)));

      HomeAsk homeAt(DateTime now) => HomeAskRules.decide(
        now: now,
        firstSeenAt: DateTime(2026, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        isConsentGiven: false,
        reviewAskedAt: notices.reviewAskedAt,
        reviewAskCount: notices.reviewAskCount,
        lastAcknowledgedAt: DateTime(2026, 9, 20),
        proAskedAt: null,
        isRinging: false,
        isWeb: false,
        isSetupDone: true,
      );
      bool proAt(DateTime now) => ProAskRules.decide(
        isPaid: false,
        isSelfHosted: false,
        dismissCount: 0,
        lastAskedAt: null,
        now: now,
        isSetupDone: true,
        otherAskedAt: [notices.reviewAskedAt],
      );

      expect(homeAt(fireAt.add(const Duration(hours: 23))), HomeAsk.none);
      expect(proAt(fireAt.add(const Duration(hours: 23))), isFalse);
      expect(proAt(fireAt.add(const Duration(hours: 25))), isTrue);
    });
  });

  group('settleAll', () {
    test('spends the budget and marks each kind done', () async {
      await store.writePlanned([
        PlannedRecord(
          id: 9100,
          kind: LocalReminderKind.fireDrill,
          fireAt: DateTime(2026, 9, 19, 10),
          poolIndex: 6,
        ),
        PlannedRecord(
          id: 9200,
          kind: LocalReminderKind.silentTopic,
          fireAt: DateTime(2026, 9, 20, 10),
          dedupeKey: 'fresh',
        ),
        PlannedRecord(
          id: 9352,
          kind: LocalReminderKind.planHeadsUp,
          fireAt: DateTime(2026, 9, 21, 10),
          dedupeKey: 'ends:2026-9-23',
        ),
        PlannedRecord(
          id: 9400,
          kind: LocalReminderKind.morningAfter,
          fireAt: DateTime(2026, 9, 21, 9),
          dedupeKey: 'inc_1',
        ),
        PlannedRecord(
          id: 9300,
          kind: LocalReminderKind.backup,
          fireAt: DateTime(2026, 9, 30, 10),
        ),
      ]);

      await settler.settleAll(now: DateTime(2026, 9, 22));

      expect(store.readDrillLastIndex(), 6);
      expect(store.readSilentDone(), {'fresh'});
      expect(store.readPlanHeadsUpsSent(), {'ends:2026-9-23'});
      expect(store.readMorningAfterDone(), {'inc_1'});
      // The latest budgeted fire time that passed. Plan heads-up skips it.
      expect(store.readBudgetSpentAt(), DateTime(2026, 9, 21, 9));
      // The backup has not fired yet, so it stays.
      expect(store.readPlanned().single.id, 9300);
    });

    test('a delivered backup shares the home card snooze', () async {
      notices.now = () => DateTime(2026, 9, 22);
      await store.writePlanned([
        PlannedRecord(
          id: 9300,
          kind: LocalReminderKind.backup,
          fireAt: DateTime(2026, 9, 21, 10),
        ),
      ]);
      await settler.settleAll(now: DateTime(2026, 9, 22));
      expect(notices.accountDismissedAt, DateTime(2026, 9, 22));
    });

    test('a delivered Pro remind-later clears it', () async {
      notices.proLaterAt = DateTime(2026, 8);
      await store.writePlanned([
        PlannedRecord(
          id: 9410,
          kind: LocalReminderKind.proLater,
          fireAt: DateTime(2026, 9, 21, 10),
        ),
      ]);
      await settler.settleAll(now: DateTime(2026, 9, 22));
      expect(notices.proLaterAt, isNull);
      expect(store.readBudgetSpentAt(), isNull);
    });

    test('turns a native "Not now" into an ask and a dismissal', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_pending_pro_dismiss': true,
      });
      store = SharedPrefsLocalReminderStore(
        await SharedPreferences.getInstance(),
      );
      settler = LocalReminderSettler(store: store, notices: notices);
      await settler.settleAll(now: DateTime(2026, 9, 22));
      expect(notices.proAskedAt, isNotNull);
      expect(notices.proDismissCount, 1);
    });
  });
}
