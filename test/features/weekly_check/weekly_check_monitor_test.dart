import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_check_fakes.dart';

/// A store whose native record throws when read.
class _UnreadableArrival implements WeeklyCheckStore {
  _UnreadableArrival(this._inner);
  final MemoryWeeklyCheckStore _inner;

  @override
  Future<WeeklyCheckArrival?> readArrival() async =>
      throw const FormatException('not a record');

  @override
  KeptWeeklyCheck? readCheck() => _inner.readCheck();

  @override
  Future<void> writeCheck(KeptWeeklyCheck kept) => _inner.writeCheck(kept);

  @override
  int? readDismissedAt() => _inner.readDismissedAt();

  @override
  Future<void> writeDismissedAt(int at) => _inner.writeDismissedAt(at);

  @override
  int? readPlanAwayAt() => _inner.readPlanAwayAt();

  @override
  Future<void> writePlanAwayAt(int at) => _inner.writePlanAwayAt(at);

  @override
  Future<void> clear() => _inner.clear();
}

void main() {
  late FakeWeeklyCheckApi api;
  late MemoryWeeklyCheckStore store;
  late int tierReads;
  late WeeklyCheckAccess access;

  /// What reading the tier again does to [access]. A test sets it to stand
  /// in for a registration that says Hosted is gone.
  late void Function() onTierRead;
  late String deviceId;
  late DateTime now;

  int seconds() => now.millisecondsSinceEpoch ~/ 1000;

  WeeklyCheckMonitor monitor() => WeeklyCheckMonitor(
    api: api,
    store: store,
    readDeviceId: () async => deviceId,
    readAccess: () => access,
    onTierRefused: () async {
      tierReads++;
      onTierRead();
    },
    now: () => now,
  );

  setUp(() {
    api = FakeWeeklyCheckApi();
    store = MemoryWeeklyCheckStore();
    tierReads = 0;
    access = WeeklyCheckAccess.open;
    onTierRead = () {};
    deviceId = 'dev_1';
    now = DateTime.utc(2026, 10, 7, 9);
  });

  group('switching on and off', () {
    test('on Hosted, on enrols and the answer is kept', () async {
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(api.puts, [true]);
      expect(subject.check!.enabled, isTrue);
      expect(subject.check!.state, WeeklyCheckState.waiting);
      expect(store.kept!.deviceId, 'dev_1');
      expect(store.kept!.seenAt, seconds());
      expect(tierReads, 0);
    });

    test('off stops it and always answers', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.tier = 'free';
      final outcome = await subject.setEnabled(enabled: false);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(api.puts, [true, false]);
      expect(subject.check!.enabled, isFalse);
      expect(subject.check!.state, WeeklyCheckState.off);
    });

    test('off Hosted, the tier error has the tier read again', () async {
      api.tier = 'free';
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.tierRefused);
      expect(tierReads, 1);
      // The check is read back, and it is still off.
      expect(api.reads, 1);
      expect(subject.check!.enabled, isFalse);
    });

    test('holding Pro makes no difference: the relay refuses by tier and '
        'nothing about packs is asked', () async {
      // The monitor has no way to reach the packs at all. Its two inputs
      // are what the access layer says and the tier read.
      api.tier = 'free';
      final outcome = await monitor().setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.tierRefused);
    });

    test('the `relay` tier is not Hosted either', () async {
      api.tier = 'relay';
      final outcome = await monitor().setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.tierRefused);
    });

    test('a 403 that names no tier, as a relay before 1.19.0 sends, is a '
        'switch that failed', () async {
      api
        ..tier = 'free'
        ..answersAsBefore119 = true;
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.failed);
      expect(tierReads, 0);
      expect(subject.check, isNull);
    });

    test('a tier read that throws does not break the switch', () async {
      api.tier = 'free';
      onTierRead = () => throw StateError('offline');
      final outcome = await monitor().setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.tierRefused);
    });

    test('a relay that cannot be reached changes nothing', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.isDown = true;
      final outcome = await subject.setEnabled(enabled: false);
      expect(outcome, WeeklyCheckSwitchOutcome.failed);
      expect(subject.check!.enabled, isTrue);
      expect(tierReads, 0);
    });

    test('the state survives a restart', () async {
      await monitor().setEnabled(enabled: true);
      // A new object over the same store, with no network.
      api.isDown = true;
      final next = monitor();
      await next.refresh();
      expect(next.check!.enabled, isTrue);
      expect(next.check!.state, WeeklyCheckState.waiting);
    });
  });

  group('reading it back', () {
    test('launch and resume read GET, once a minute at most', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        lastReceivedAt: 500,
        noticeAfter: 9000,
      );
      final subject = monitor();
      await subject.refresh();
      await subject.refresh();
      expect(api.reads, 1);
      expect(subject.check!.state, WeeklyCheckState.received);

      now = now.add(const Duration(seconds: 61));
      await subject.refresh();
      expect(api.reads, 2);

      await subject.refresh(force: true);
      expect(api.reads, 3);
    });

    test('a read that fails keeps the last answer', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.check = null;
      await subject.refresh(force: true);
      expect(subject.check!.enabled, isTrue);
    });

    test('the relay saying the account is not on Hosted, while the phone '
        'still counts it as held, has the tier read again', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.off,
        reason: WeeklyCheckOffReason.tier,
      );
      final subject = monitor();
      await subject.refresh();
      expect(tierReads, 1);
      expect(subject.check!.reason, WeeklyCheckOffReason.tier);
      expect(subject.check!.enabled, isTrue);

      // The same answer again is no news: the tier is not read on every
      // resume while it trails.
      await subject.refresh(force: true);
      await subject.refresh(force: true);
      expect(tierReads, 1);
    });

    test('with the plan already known to be away there is nothing to read '
        'again', () async {
      access = WeeklyCheckAccess.locked;
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.off,
        reason: WeeklyCheckOffReason.tier,
      );
      await monitor().refresh();
      expect(tierReads, 0);
    });

    test('switched off by hand is not a lapsed plan', () async {
      await monitor().refresh();
      expect(tierReads, 0);
    });

    test('an answer kept for another device is dropped', () async {
      await monitor().setEnabled(enabled: true);
      store
        ..dismissedAt = 5
        ..arrival = const WeeklyCheckArrival(receivedAt: 4);
      // Signing out gives the phone a new device id with no check state.
      deviceId = 'dev_2';
      api.check = null;
      final next = monitor();
      await next.refresh();
      expect(next.check, isNull);
      expect(store.dismissedAt, isNull);
      expect(store.arrival, isNull);
    });

    test('every change is announced', () async {
      final subject = monitor();
      var changes = 0;
      final sub = subject.changes.listen((_) => changes++);
      await subject.setEnabled(enabled: true);
      await subject.dismissNotice();
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
      await sub.cancel();
    });
  });

  group('the notice', () {
    const day = 24 * 60 * 60;

    test('nothing before the relay has answered', () async {
      expect(await monitor().noticeFacts(), isNull);
      expect(await monitor().shouldShowNotice(isSetupDone: true), isFalse);
    });

    test(
      'notice_after from a read is stored and the clock passes it',
      () async {
        final noticeAfter = seconds() + 8 * day;
        api.check = WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.received,
          noticeAfter: noticeAfter,
        );
        final subject = monitor();
        await subject.refresh();
        expect((await subject.noticeFacts())!.noticeAfter, noticeAfter);
        expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);

        // No network from here on, as when the push path is what broke.
        api.isDown = true;
        now = now.add(const Duration(days: 8, seconds: 1));
        final later = monitor();
        expect(await later.shouldShowNotice(isSetupDone: true), isTrue);
        expect(await later.shouldShowNotice(isSetupDone: false), isFalse);
      },
    );

    test('a receipt answer the native handler stored is used', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: seconds() + 8 * day,
      );
      final subject = monitor();
      await subject.refresh();

      now = now.add(const Duration(days: 7));
      final arrivedAt = seconds();
      store.arrival = WeeklyCheckArrival(
        receivedAt: arrivedAt,
        noticeAfter: arrivedAt + 8 * day,
        noticeAfterSeenAt: arrivedAt + 1,
      );
      final facts = (await subject.noticeFacts())!;
      expect(facts.noticeAfter, arrivedAt + 8 * day);
      expect(facts.lastArrivalAt, arrivedAt);

      now = now.add(const Duration(days: 2));
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      now = now.add(const Duration(days: 7));
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test('an arrival with no receipt answer counts from the arrival', () async {
      final noticeAfter = seconds() + 8 * day;
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: noticeAfter,
      );
      final subject = monitor();
      await subject.refresh();
      // Offline from here. A check arrives and its receipt never lands, as
      // on a phone before its first unlock.
      api.isDown = true;
      now = now.add(const Duration(days: 6));
      final arrivedAt = seconds();
      store.arrival = WeeklyCheckArrival(receivedAt: arrivedAt);

      final facts = (await subject.noticeFacts())!;
      expect(facts.lastArrivalAt, arrivedAt);
      // Not a receipt: the relay's notice_after is still the one held.
      expect(facts.noticeAfter, noticeAfter);

      now = now.add(const Duration(days: 3));
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      now = now.add(const Duration(days: 18));
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      now = now.add(const Duration(days: 1, seconds: 1));
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test('a record that cannot be read is no arrival known', () async {
      final noticeAfter = seconds() + 8 * day;
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: noticeAfter,
      );
      final subject = WeeklyCheckMonitor(
        api: api,
        store: _UnreadableArrival(store),
        readDeviceId: () async => deviceId,
        readAccess: () => access,
        onTierRefused: () async {},
        now: () => now,
      );
      await subject.refresh();
      final facts = (await subject.noticeFacts())!;
      expect(facts.lastArrivalAt, isNull);
      expect(facts.noticeAfter, noticeAfter);
      // It does not raise the notice.
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      // And it does not hide the misses the relay's answer leads to.
      now = now.add(const Duration(days: 8, seconds: 1));
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test('a newer read wins over an older receipt answer', () async {
      store.arrival = WeeklyCheckArrival(
        receivedAt: seconds() - 100,
        noticeAfter: 1,
        noticeAfterSeenAt: seconds() - 99,
      );
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: 4000000000,
      );
      final subject = monitor();
      await subject.refresh();
      expect((await subject.noticeFacts())!.noticeAfter, 4000000000);
    });

    test('two misses show it, closing keeps it gone', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.missedRepeatedly,
        misses: 2,
        noticeAfter: seconds() - 3600,
      );
      final subject = monitor();
      await subject.refresh();
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);

      await subject.dismissNotice();
      expect(store.dismissedAt, seconds());
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      // A restart later it is still gone.
      now = now.add(const Duration(days: 3));
      expect(await monitor().shouldShowNotice(isSetupDone: true), isFalse);
    });

    test('one miss shows nothing', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.missedOnce,
        misses: 1,
        noticeAfter: seconds() + day,
      );
      final subject = monitor();
      await subject.refresh();
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
    });
  });

  // api.md §4.5, "When the tier changes".
  group('a lapse and a return', () {
    const day = 24 * 60 * 60;

    /// What the relay answers for an enrolled device while the account is
    /// not on Hosted: still enrolled, off, with the reason and the times it
    /// had.
    WeeklyCheck lapsed({int? lastReceivedAt}) => WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.off,
      reason: WeeklyCheckOffReason.tier,
      lastSentAt: lastReceivedAt,
      lastReceivedAt: lastReceivedAt,
    );

    test('the lapse takes nothing away: the device stays enrolled and no '
        '"off" is sent', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.puts.clear();

      // Hosted ends. The tier read says so and the access layer locks.
      api
        ..tier = 'free'
        ..check = lapsed();
      onTierRead = () => access = WeeklyCheckAccess.locked;
      await subject.refresh(force: true);
      expect(tierReads, 1);
      await subject.accessChanged();

      expect(api.puts, isEmpty);
      expect(subject.check!.enabled, isTrue);
      expect(subject.check!.state, WeeklyCheckState.off);
      expect(subject.check!.reason, WeeklyCheckOffReason.tier);
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
    });

    test('a notice_after stored before the lapse raises nothing while the '
        'plan is away, with the relay out of reach the whole time', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        lastReceivedAt: seconds(),
        noticeAfter: seconds() + 8 * day,
      );
      final subject = monitor();
      await subject.refresh();

      // Hosted lapses and the phone has no network: the kept answer still
      // says "received" with the old notice_after.
      api.isDown = true;
      access = WeeklyCheckAccess.locked;
      await subject.accessChanged();
      now = now.add(const Duration(days: 30));

      expect(subject.check!.state, WeeklyCheckState.received);
      expect(await subject.twoRoundsMissed(), isFalse);
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      // After a restart too.
      expect(await monitor().shouldShowNotice(isSetupDone: true), isFalse);
    });

    test('the return needs no tap, and the old notice_after raises nothing '
        'before the relay answers again', () async {
      final before = seconds();
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        lastReceivedAt: before,
        noticeAfter: before + 8 * day,
      );
      final subject = monitor();
      await subject.refresh();

      // Lapse, seen with no network, then 30 days pass.
      api.isDown = true;
      access = WeeklyCheckAccess.locked;
      await subject.accessChanged();
      now = now.add(const Duration(days: 30));
      // One look at Home during the lapse.
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      now = now.add(const Duration(days: 1));

      // Hosted is back and the relay still cannot be reached. The clock is
      // far past the old notice_after, and that proves nothing.
      access = WeeklyCheckAccess.open;
      await subject.accessChanged();
      expect(api.puts, isEmpty);
      expect(await subject.twoRoundsMissed(), isFalse);
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);

      // The relay answers: rounds go on from the next one due.
      final next = seconds() + 2 * day;
      api
        ..isDown = false
        ..check = WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.received,
          lastReceivedAt: before,
          nextDueAt: next,
          noticeAfter: next + 8 * day,
        );
      now = now.add(const Duration(minutes: 5));
      await subject.accessChanged();
      expect(api.puts, isEmpty);
      expect(subject.check!.enabled, isTrue);
      expect(subject.check!.state, WeeklyCheckState.received);
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);

      // From here it is an ordinary check again: two rounds with nothing
      // arriving do raise the notice.
      api.isDown = true;
      now = now.add(const Duration(days: 11));
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test('a count of two misses from before the lapse waits for the '
        'relay too, and shows again when the relay still says so', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.missedRepeatedly,
        misses: 2,
        noticeAfter: seconds() - 3600,
      );
      final subject = monitor();
      await subject.refresh();
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);

      api.isDown = true;
      access = WeeklyCheckAccess.locked;
      await subject.accessChanged();
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);

      now = now.add(const Duration(days: 20));
      access = WeeklyCheckAccess.open;
      await subject.accessChanged();
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);

      // `misses` keeps its value across a lapse (api.md §4.5), so a fresh
      // answer that still reports two is a real run of misses.
      api.isDown = false;
      now = now.add(const Duration(minutes: 5));
      await subject.refresh(force: true);
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test('an arrival from before the lapse is not counted on from', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: seconds() + 8 * day,
      );
      final subject = monitor();
      await subject.refresh();
      api.isDown = true;
      // A check arrives and its receipt never lands.
      now = now.add(const Duration(days: 6));
      store.arrival = WeeklyCheckArrival(receivedAt: seconds());

      now = now.add(const Duration(days: 1));
      access = WeeklyCheckAccess.locked;
      await subject.accessChanged();
      now = now.add(const Duration(days: 40));
      access = WeeklyCheckAccess.open;
      await subject.accessChanged();
      // 41 days past the arrival is more than two windows of 11 days.
      expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
    });

    test('a purchase being confirmed and a plan that could not be read '
        'take nothing away and write nothing down', () async {
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.missedRepeatedly,
        misses: 2,
        noticeAfter: seconds() - 3600,
      );
      final subject = monitor();
      await subject.refresh();
      access = WeeklyCheckAccess.unsure;
      await subject.accessChanged();
      expect(store.planAwayAt, isNull);
      expect(api.puts, isEmpty);
      // Nobody knows, so a real run of misses still shows.
      expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);
    });

    test(
      'the moment the plan was seen away is kept for the next launch',
      () async {
        api.check = WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.received,
          noticeAfter: seconds() + 8 * day,
        );
        await monitor().refresh();
        api.isDown = true;
        access = WeeklyCheckAccess.locked;
        await monitor().refresh(force: true);
        expect(store.planAwayAt, seconds());

        now = now.add(const Duration(days: 30));
        access = WeeklyCheckAccess.open;
        expect(await monitor().shouldShowNotice(isSetupDone: true), isFalse);
      },
    );
  });

  // api.md §4.5, "A phone on a self-hosted server gets no weekly check".
  group("on a server of the user's own", () {
    test('the app never sends enabled:true', () async {
      access = WeeklyCheckAccess.notOffered;
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.notOffered);
      expect(api.puts, isEmpty);
    });

    test('a phone that was enrolled tells the relay to stop, once', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.puts.clear();

      // The phone connects to a server of its own.
      access = WeeklyCheckAccess.notOffered;
      await subject.accessChanged();
      expect(api.puts, [false]);
      expect(subject.check!.enabled, isFalse);

      // Launches, resumes and further changes send nothing more.
      now = now.add(const Duration(minutes: 5));
      await subject.refresh();
      await subject.accessChanged();
      await monitor().refresh(force: true);
      expect(api.puts, [false]);
    });

    test('a send that fails is tried again on the next read, and the '
        'caller never waits on an error', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.puts.clear();

      access = WeeklyCheckAccess.notOffered;
      api.isDown = true;
      // Completes normally: a connect that triggered it is not held up or
      // failed by it.
      await subject.accessChanged();
      expect(api.puts, isNotEmpty);
      expect(subject.check!.enabled, isTrue);

      // The network is back at the next resume.
      api
        ..isDown = false
        ..puts.clear();
      now = now.add(const Duration(minutes: 5));
      await subject.refresh();
      expect(api.puts, [false]);
      expect(subject.check!.enabled, isFalse);

      now = now.add(const Duration(minutes: 5));
      await subject.refresh();
      expect(api.puts, [false]);
    });

    test(
      'a phone the relay already has as not enrolled sends nothing',
      () async {
        access = WeeklyCheckAccess.notOffered;
        final subject = monitor();
        await subject.refresh();
        await subject.accessChanged();
        expect(api.puts, isEmpty);
      },
    );

    test('a phone the relay answers as enrolled is stopped even when this '
        'install never switched it on', () async {
      // A reinstall keeps the device id and loses the kept answer.
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.received,
        noticeAfter: 9000,
      );
      access = WeeklyCheckAccess.notOffered;
      final subject = monitor();
      await subject.refresh();
      expect(api.puts, [false]);
    });

    test(
      'nothing is called a miss there, whatever the phone still holds',
      () async {
        api.check = WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.missedRepeatedly,
          misses: 3,
          noticeAfter: seconds() - 3600,
        );
        final subject = monitor();
        await subject.refresh();
        expect(await subject.shouldShowNotice(isSetupDone: true), isTrue);

        api.isDown = true;
        access = WeeklyCheckAccess.notOffered;
        await subject.accessChanged();
        expect(await subject.twoRoundsMissed(), isFalse);
        expect(await subject.shouldShowNotice(isSetupDone: true), isFalse);
      },
    );

    test(
      'Hosted lapsing on Crit Alarm Cloud is not this: nothing is sent',
      () async {
        final subject = monitor();
        await subject.setEnabled(enabled: true);
        api.puts.clear();
        access = WeeklyCheckAccess.locked;
        await subject.accessChanged();
        expect(api.puts, isEmpty);
      },
    );
  });
}
