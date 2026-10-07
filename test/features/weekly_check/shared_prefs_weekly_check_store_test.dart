import 'dart:convert';

import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/data/shared_prefs_weekly_check_store.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsWeeklyCheckStore> store([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPrefsWeeklyCheckStore(await SharedPreferences.getInstance());
  }

  test('nothing kept reads as nothing', () async {
    final subject = await store();
    expect(subject.readCheck(), isNull);
    expect(await subject.readArrival(), isNull);
    expect(subject.readDismissedAt(), isNull);
  });

  test('the relay answer reads back as written', () async {
    final subject = await store();
    const check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.missedOnce,
      misses: 1,
      lastSentAt: 10,
      lastReceivedAt: 5,
      nextDueAt: 20,
      noticeAfter: 30,
    );
    await subject.writeCheck(
      const KeptWeeklyCheck(check: check, seenAt: 15, deviceId: 'dev_1'),
    );
    final kept = subject.readCheck()!;
    expect(kept.check, check);
    expect(kept.seenAt, 15);
    expect(kept.deviceId, 'dev_1');
  });

  test('what the native handler wrote is read', () async {
    final subject = await store({
      SharedPrefsWeeklyCheckStore.arrivalKey: jsonEncode({
        'received_at': 100,
        'notice_after': 900,
        'notice_after_seen_at': 101,
        'next_due_at': 700,
      }),
    });
    final arrival = (await subject.readArrival())!;
    expect(arrival.receivedAt, 100);
    expect(arrival.noticeAfter, 900);
    expect(arrival.noticeAfterSeenAt, 101);
    expect(arrival.nextDueAt, 700);
  });

  test('an arrival with no receipt answer yet has only its time', () async {
    final subject = await store({
      SharedPrefsWeeklyCheckStore.arrivalKey: jsonEncode({'received_at': 100}),
    });
    final arrival = (await subject.readArrival())!;
    expect(arrival.receivedAt, 100);
    expect(arrival.noticeAfter, isNull);
  });

  test('a value that does not read back is the same as none', () async {
    final subject = await store({
      SharedPrefsWeeklyCheckStore.checkKey: 'not json',
      SharedPrefsWeeklyCheckStore.arrivalKey: '[1]',
    });
    expect(subject.readCheck(), isNull);
    expect(await subject.readArrival(), isNull);
  });

  test('the close time is kept, and clear forgets everything', () async {
    final subject = await store({
      SharedPrefsWeeklyCheckStore.arrivalKey: jsonEncode({'received_at': 100}),
    });
    await subject.writeDismissedAt(42);
    expect(subject.readDismissedAt(), 42);
    await subject.clear();
    expect(subject.readDismissedAt(), isNull);
    expect(await subject.readArrival(), isNull);
  });

  test('nothing kept holds the id a check push carries', () async {
    final subject = await store();
    await subject.writeCheck(
      const KeptWeeklyCheck(
        check: WeeklyCheck(enabled: true, state: WeeklyCheckState.waiting),
        seenAt: 1,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}'.contains('check_id'), isFalse);
    }
  });
}
