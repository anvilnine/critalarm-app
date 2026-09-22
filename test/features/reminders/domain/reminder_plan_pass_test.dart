import 'dart:async';

import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_pass.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_home_prompt_repository.dart';
import '../fake_reminder_scheduler.dart';

/// Counts every schedule call and can fail some of them.
class _TestScheduler extends FakeReminderScheduler {
  final List<int> scheduleCalls = [];
  final Set<int> failIds = {};
  bool failPending = false;

  @override
  Future<void> schedule(ReminderRequest request) async {
    scheduleCalls.add(request.id);
    if (failIds.contains(request.id)) throw StateError('schedule failed');
    await super.schedule(request);
  }

  @override
  Future<List<PendingReminder>> pending() async {
    if (failPending) throw StateError('pending failed');
    return super.pending();
  }
}

/// A store whose reload can fail, to stop a pass before it settles.
class _FlakyStore extends SharedPrefsReminderStore {
  _FlakyStore(super._prefs);

  bool failReload = false;

  @override
  Future<void> reload() async {
    if (failReload) throw StateError('reload failed');
    await super.reload();
  }
}

Matcher sameMomentAs(DateTime expected) => predicate<DateTime?>(
  (actual) => actual != null && actual.isAtSameMomentAs(expected),
  'the same moment as $expected',
);

void main() {
  late _FlakyStore store;
  late _TestScheduler scheduler;
  late FakeHomePromptRepository prompts;
  final clock = DateTime.utc(2026, 9, 22, 12);

  // A drill for prod-db on Saturday 26 September at 10:00 (UTC wall-clock).
  ReminderInputs drillInputs({
    ReminderSwitches? switches,
    DateTime? proLaterAt,
  }) => ReminderInputs(
    now: DateTime(2026, 9, 22, 12),
    switches: switches ?? ReminderSwitches.defaults,
    topics: const [ReminderTopic(name: 'prod-db', isCritical: true)],
    lastTestAt: {'prod-db': DateTime(2026, 8, 20)},
    proLaterAt: proLaterAt,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _FlakyStore(await SharedPreferences.getInstance());
    scheduler = _TestScheduler();
    prompts = FakeHomePromptRepository();
  });

  ReminderPlanPass pass(
    Future<ReminderInputs?> Function() readInputs, {
    bool isWeb = false,
  }) => ReminderPlanPass(
    store: store,
    scheduler: scheduler,
    settler: ReminderSettler(store: store, prompts: prompts),
    readInputs: readInputs,
    copy: const ReminderCopy(isIos: true),
    isWeb: isWeb,
    clock: () => clock,
  );

  test('schedules the plan and records it', () async {
    await pass(() async => drillInputs()).run();
    final request = scheduler.scheduled[ReminderIds.drill]!;
    expect(request.kind, ReminderKind.fireDrill);
    expect(request.fireAt, DateTime(2026, 9, 26, 10));
    final record = store.readPlanned().single;
    expect(record.id, ReminderIds.drill);
    expect(record.fireAt, sameMomentAs(DateTime.utc(2026, 9, 26, 10)));
  });

  test('cancels planned ids only, never incidents or lab fires', () async {
    scheduler.otherPending.addAll({1234, 9591, 9300});
    await pass(() async => drillInputs()).run();
    expect(scheduler.cancelled.single, [9300]);
    expect(scheduler.otherPending, {1234, 9591});
  });

  test('Reminders off cancels what was planned and plans nothing', () async {
    await pass(() async => drillInputs()).run();
    await pass(
      () async => drillInputs(switches: ReminderSwitches.allOff),
    ).run();
    expect(scheduler.scheduled, isEmpty);
    expect(store.readPlanned(), isEmpty);
  });

  test(
    'schedules a still planned reminder again and never cancels it',
    () async {
      final p = pass(() async => drillInputs());
      await p.run();
      await p.run();
      // A force-stop can wipe the alarm while pending() still lists it.
      expect(
        scheduler.scheduleCalls.where((id) => id == ReminderIds.drill),
        hasLength(2),
      );
      expect(
        scheduler.cancelled.expand((ids) => ids),
        isNot(contains(ReminderIds.drill)),
      );
    },
  );

  test('keeps the review ask fire time for the settle step', () async {
    await pass(
      () async => ReminderInputs(
        now: DateTime(2026, 9, 21, 12),
        installedAt: DateTime(2026, 9, 1, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
      ),
    ).run();
    expect(
      store.readReviewFireAt(),
      sameMomentAs(DateTime.utc(2026, 9, 24, 10)),
    );
  });

  test('a re-plan after the home popup asked cancels the review ask', () async {
    await pass(
      () async => ReminderInputs(
        now: DateTime(2026, 9, 21, 12),
        installedAt: DateTime(2026, 9, 1, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
      ),
    ).run();
    // Home opened, the popup asked, the pass runs again.
    await pass(
      () async => ReminderInputs(
        now: DateTime(2026, 9, 21, 13),
        installedAt: DateTime(2026, 9, 1, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
        reviewAskedAt: DateTime(2026, 9, 21, 13),
        reviewAskCount: 1,
      ),
    ).run();
    expect(scheduler.scheduled, isEmpty);
    expect(store.readReviewFireAt(), isNull);
  });

  test('settles before it plans', () async {
    await store.writePlanned([
      PlannedRecord(
        id: 9200,
        kind: ReminderKind.silentTopic,
        fireAt: DateTime.utc(2026, 9, 21, 10),
        dedupeKey: 'fresh',
      ),
    ]);
    await pass(() async => drillInputs()).run();
    expect(store.readSilentDone(), {'fresh'});
    expect(
      store.readBudgetSpentAt(),
      sameMomentAs(DateTime.utc(2026, 9, 21, 10)),
    );
  });

  test('keeps what the switches allow when inputs cannot be read', () async {
    scheduler.otherPending.add(9300);
    await pass(() async => null).run();
    expect(scheduler.cancelled, isEmpty);
  });

  test('keeps what the switches allow when reading inputs throws', () async {
    scheduler.otherPending.add(9300);
    await pass(() async => throw StateError('offline')).run();
    expect(scheduler.cancelled, isEmpty);
  });

  PlannedRecord record(int id, ReminderKind kind) => PlannedRecord(
    id: id,
    kind: kind,
    fireAt: DateTime.utc(2026, 9, 30, 10),
  );

  test('Reminders off still cancels reminders when offline', () async {
    await store.writeSwitches(
      const ReminderSwitches(reminders: false, offers: true),
    );
    scheduler.otherPending.addAll({ReminderIds.drill, 9200, 9400, 9500});
    await store.writePlanned([
      record(ReminderIds.drill, ReminderKind.fireDrill),
      record(9200, ReminderKind.silentTopic),
      record(9400, ReminderKind.morningAfter),
      record(9500, ReminderKind.reviewAsk),
    ]);
    await store.writeReviewFireAt(DateTime.utc(2026, 9, 30, 10));
    await store.writeFeedbackFireAt(DateTime.utc(2026, 9, 30, 10));

    await pass(() async => null).run();

    expect(
      scheduler.cancelled.expand((ids) => ids).toSet(),
      {ReminderIds.drill, 9200, 9500},
    );
    expect(scheduler.otherPending, {9400});
    expect(store.readPlanned().map((r) => r.id), [9400]);
    expect(store.readReviewFireAt(), isNull);
    expect(store.readFeedbackFireAt(), isNull);
  });

  test('Offers off still cancels offers when offline', () async {
    await store.writeSwitches(ReminderSwitches.defaults);
    scheduler.otherPending.addAll({ReminderIds.drill, 9400, 9410});
    await store.writePlanned([
      record(ReminderIds.drill, ReminderKind.fireDrill),
      record(9410, ReminderKind.proLater),
    ]);
    await store.writeReviewFireAt(DateTime.utc(2026, 9, 30, 10));

    await pass(() async => throw StateError('offline')).run();

    expect(scheduler.cancelled.expand((ids) => ids).toSet(), {9400, 9410});
    expect(scheduler.otherPending, {ReminderIds.drill});
    expect(store.readPlanned().map((r) => r.id), [ReminderIds.drill]);
    expect(
      store.readReviewFireAt(),
      sameMomentAs(DateTime.utc(2026, 9, 30, 10)),
    );
  });

  test('a failed settle stops the pass and keeps the records', () async {
    await store.writePlanned([record(9200, ReminderKind.silentTopic)]);
    store.failReload = true;
    await pass(() async => drillInputs()).run();
    expect(scheduler.scheduleCalls, isEmpty);
    expect(store.readPlanned().map((r) => r.id), [9200]);
  });

  test('cancels recorded ids no longer planned when pending fails', () async {
    scheduler.failPending = true;
    await store.writePlanned([
      record(9300, ReminderKind.backup),
      record(ReminderIds.drill, ReminderKind.fireDrill),
    ]);
    await pass(() async => drillInputs()).run();
    expect(scheduler.cancelled.single, [9300]);
    expect(scheduler.scheduled.keys, [ReminderIds.drill]);
  });

  test('one failed schedule does not stop the rest', () async {
    scheduler.failIds.add(ReminderIds.drill);
    await pass(
      () async => drillInputs(
        switches: const ReminderSwitches(reminders: true, offers: true),
        proLaterAt: DateTime(2026, 8, 3),
      ),
    ).run();
    expect(scheduler.scheduleCalls, contains(ReminderIds.drill));
    expect(scheduler.scheduled.keys, [ReminderIds.proLater]);
    // Only what reached the scheduler is recorded for the settle step.
    expect(store.readPlanned().map((r) => r.id), [ReminderIds.proLater]);
  });

  test('still schedules when pending cannot be read', () async {
    scheduler.failPending = true;
    await pass(() async => drillInputs()).run();
    expect(scheduler.scheduled.keys, [ReminderIds.drill]);
  });

  test('does nothing on web', () async {
    await pass(() async => drillInputs(), isWeb: true).run();
    expect(scheduler.scheduled, isEmpty);
  });

  test('a run asked for during a run happens once, after it', () async {
    final gate = Completer<void>();
    var reads = 0;
    final p = pass(() async {
      reads++;
      if (reads == 1) await gate.future;
      return drillInputs();
    });
    final first = p.run();
    final second = p.run();
    final third = p.run();
    gate.complete();
    await Future.wait([first, second, third]);
    expect(reads, 2);
  });
}
