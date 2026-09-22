import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsReminderStore store;

  Future<SharedPrefsReminderStore> fresh([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPrefsReminderStore(await SharedPreferences.getInstance());
  }

  setUp(() async => store = await fresh());

  test('starts with Reminders on and Offers off', () {
    expect(store.readSwitches(), ReminderSwitches.defaults);
  });

  test('keeps the switches', () async {
    await store.writeSwitches(ReminderSwitches.allOff);
    expect(store.readSwitches(), ReminderSwitches.allOff);
  });

  test('keeps lastTestAt per topic', () async {
    await store.markTested('prod-db', DateTime(2026, 9, 20, 10));
    await store.markTested('db-2', DateTime(2026, 9, 21, 10));
    await store.markTested('prod-db', DateTime(2026, 9, 22, 10));
    expect(store.readLastTestAt(), {
      'prod-db': DateTime(2026, 9, 22, 10),
      'db-2': DateTime(2026, 9, 21, 10),
    });
  });

  test(
    'keeps the failed test time, sheet flag, budget and pool index',
    () async {
      await store.markTestFailed(DateTime(2026, 9, 22));
      await store.markSheetShown();
      await store.writeBudgetSpentAt(DateTime(2026, 9, 19, 10));
      await store.writeDrillLastIndex(4);
      expect(store.readLastTestFailedAt(), DateTime(2026, 9, 22));
      expect(store.readSheetShown(), isTrue);
      expect(store.readBudgetSpentAt(), DateTime(2026, 9, 19, 10));
      expect(store.readDrillLastIndex(), 4);
    },
  );

  test('keeps planned records and skips ones it cannot read', () async {
    final record = PlannedRecord(
      id: 9100,
      kind: ReminderKind.fireDrill,
      fireAt: DateTime(2026, 9, 26, 10),
      poolIndex: 3,
    );
    await store.writePlanned([record]);
    final read = store.readPlanned().single;
    expect(read.id, 9100);
    expect(read.kind, ReminderKind.fireDrill);
    expect(read.fireAt, DateTime(2026, 9, 26, 10));
    expect(read.poolIndex, 3);

    store = await fresh({
      'reminder_planned': '[{"id":1,"kind":"gone","fire_at":0}]',
    });
    expect(store.readPlanned(), isEmpty);
  });

  test('degrades to empty instead of throwing on wrong-shape JSON', () async {
    store = await fresh({
      'reminder_last_test_at': '[]',
      'reminder_topics_created_here': '"nope"',
      'reminder_planned': '{"id":1,"kind":"fire_drill","fire_at":0}',
    });
    expect(store.readLastTestAt, returnsNormally);
    expect(store.readLastTestAt(), isEmpty);
    expect(store.readTopicsCreatedHere, returnsNormally);
    expect(store.readTopicsCreatedHere(), isEmpty);
    expect(store.readPlanned, returnsNormally);
    expect(store.readPlanned(), isEmpty);
  });

  test('keeps and clears the review and feedback fire times', () async {
    await store.writeReviewFireAt(DateTime(2026, 9, 24, 10));
    await store.writeFeedbackFireAt(DateTime(2026, 10, 1, 10));
    expect(store.readReviewFireAt(), DateTime(2026, 9, 24, 10));
    expect(store.readFeedbackFireAt(), DateTime(2026, 10, 1, 10));
    await store.writeReviewFireAt(null);
    expect(store.readReviewFireAt(), isNull);
  });

  test('keeps the done sets and topics made here', () async {
    await store.recordTopicCreatedHere('fresh', DateTime(2026, 9, 21, 15));
    await store.addSilentDone('fresh');
    await store.addPlanNoticeSent('ends:2026-10-2');
    await store.addMorningAfterDone('inc_1');
    expect(store.readTopicsCreatedHere(), {
      'fresh': DateTime(2026, 9, 21, 15),
    });
    expect(store.readSilentDone(), {'fresh'});
    expect(store.readPlanNoticesSent(), {'ends:2026-10-2'});
    expect(store.readMorningAfterDone(), {'inc_1'});
  });

  test('takes the native "Not now" flag once', () async {
    store = await fresh({'reminder_pending_pro_dismiss': true});
    expect(await store.takePendingProDismiss(), isTrue);
    expect(await store.takePendingProDismiss(), isFalse);
  });

  test('resetAll wipes every reminder key and keeps others', () async {
    store = await fresh({'home_prompt_first_seen_at': 1});
    await store.markSheetShown();
    await store.markTested('prod-db', DateTime(2026, 9));
    await store.writeSkipRules(skip: true);
    await store.writeProSheetOwed(owed: true);
    await store.resetAll();
    expect(store.readSheetShown(), isFalse);
    expect(store.readLastTestAt(), isEmpty);
    expect(store.readSkipRules(), isFalse);
    expect(store.readProSheetOwed(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('home_prompt_first_seen_at'), 1);
  });
}
