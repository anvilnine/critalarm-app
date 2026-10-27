import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/features/in_app_notices/data/shared_prefs_cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<SharedPrefsCancelAnswerStore> store([
    Map<String, Object> seed = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    return SharedPrefsCancelAnswerStore(prefs);
  }

  const entry = CancelAnswer(
    accountId: 'acc_1',
    reason: CancelReason.broken,
    text: 'crashed',
    appVersion: '1.0.0+12',
    platform: 'ios',
    retries: 1,
  );

  test('the asked mark round trips', () async {
    final s = await store();
    expect(s.readAskedFor(), isNull);
    await s.writeAskedFor('2026-10-20');
    expect(s.readAskedFor(), '2026-10-20');
  });

  test('pending entries round trip with every field', () async {
    final s = await store();
    await s.writePending([entry]);
    final read = s.readPending().single;
    expect(read.accountId, 'acc_1');
    expect(read.reason, CancelReason.broken);
    expect(read.text, 'crashed');
    expect(read.appVersion, '1.0.0+12');
    expect(read.platform, 'ios');
    expect(read.retries, 1);
  });

  test('an empty list removes the key', () async {
    final s = await store();
    await s.writePending([entry]);
    await s.writePending(const []);
    expect(s.readPending(), isEmpty);
  });

  test('unreadable data reads as nothing waiting', () async {
    final s = await store({'cancel_question_pending_v1': '{not json'});
    expect(s.readPending(), isEmpty);
  });

  test('one bad entry is skipped and the good one is kept', () async {
    final s = await store();
    await s.writePending([entry]);
    final stored = prefs.getString('cancel_question_pending_v1')!;
    final withoutBrackets = stored.substring(1, stored.length - 1);
    await prefs.setString(
      'cancel_question_pending_v1',
      '[$withoutBrackets,{"reason":"nope"}]',
    );
    expect(s.readPending().map((e) => e.accountId), ['acc_1']);
  });
}
