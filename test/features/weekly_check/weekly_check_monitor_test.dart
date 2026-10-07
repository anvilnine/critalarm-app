import 'package:critalarm/core/models/weekly_check.dart';
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
  Future<void> clear() => _inner.clear();
}

void main() {
  late FakeWeeklyCheckApi api;
  late MemoryWeeklyCheckStore store;
  late List<String?> refusedPacks;
  late String deviceId;
  late DateTime now;

  int seconds() => now.millisecondsSinceEpoch ~/ 1000;

  WeeklyCheckMonitor monitor() => WeeklyCheckMonitor(
    api: api,
    store: store,
    readDeviceId: () async => deviceId,
    onPackRefused: (pack) async => refusedPacks.add(pack),
    now: () => now,
  );

  setUp(() {
    api = FakeWeeklyCheckApi();
    store = MemoryWeeklyCheckStore();
    refusedPacks = [];
    deviceId = 'dev_1';
    now = DateTime.utc(2026, 10, 7, 9);
  });

  group('switching on and off', () {
    test('with the pack, on enrols and the answer is kept', () async {
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(api.puts, [true]);
      expect(subject.check!.enabled, isTrue);
      expect(subject.check!.state, WeeklyCheckState.waiting);
      expect(store.kept!.deviceId, 'dev_1');
      expect(store.kept!.seenAt, seconds());
      expect(refusedPacks, isEmpty);
    });

    test('off stops it and always answers', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.hasPack = false;
      final outcome = await subject.setEnabled(enabled: false);
      expect(outcome, WeeklyCheckSwitchOutcome.done);
      expect(api.puts, [true, false]);
      expect(subject.check!.enabled, isFalse);
      expect(subject.check!.state, WeeklyCheckState.off);
    });

    test('without the pack a 403 goes to the pack access', () async {
      api.hasPack = false;
      final subject = monitor();
      final outcome = await subject.setEnabled(enabled: true);
      expect(outcome, WeeklyCheckSwitchOutcome.packRefused);
      expect(refusedPacks, ['pro']);
      // The check is read back, and it is still off.
      expect(api.reads, 1);
      expect(subject.check!.enabled, isFalse);
    });

    test('a relay that cannot be reached changes nothing', () async {
      final subject = monitor();
      await subject.setEnabled(enabled: true);
      api.isDown = true;
      final outcome = await subject.setEnabled(enabled: false);
      expect(outcome, WeeklyCheckSwitchOutcome.failed);
      expect(subject.check!.enabled, isTrue);
      expect(refusedPacks, isEmpty);
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

    test('a lost pack is handed to the pack access', () async {
      api.check = const WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.off,
        reason: WeeklyCheckOffReason.pack,
      );
      final subject = monitor();
      await subject.refresh();
      expect(refusedPacks, ['pro']);
      expect(subject.check!.reason, WeeklyCheckOffReason.pack);
    });

    test('switched off by hand is not a lost pack', () async {
      await monitor().refresh();
      expect(refusedPacks, isEmpty);
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
        onPackRefused: (pack) async => refusedPacks.add(pack),
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
}
