import 'package:critalarm/features/reliability/data/shared_prefs_missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final at = DateTime.utc(2026, 10, 7, 9);

  test('an empty phone reads as nothing', () {
    final store = SharedPrefsMissedAlarmStore(prefs);
    expect(store.readRecord().rows, isEmpty);
    expect(store.readDismissed(), isEmpty);
    expect(store.readSetupDoneAt(), isNull);
    expect(store.readConnected(), isNull);
    expect(store.readTopicHolds(), isEmpty);
  });

  test('topic stretches read back, ended and open', () async {
    final holds = {
      'prod': [
        TopicHold(since: at, until: at.add(const Duration(days: 1))),
        TopicHold(since: at.add(const Duration(days: 2))),
      ],
    };
    await SharedPrefsMissedAlarmStore(prefs).writeTopicHolds(holds);
    expect(SharedPrefsMissedAlarmStore(prefs).readTopicHolds(), holds);
  });

  test('a server switch clears the record, the closed entries and the '
      'topic stretches, and keeps the setup stamp', () async {
    final store = SharedPrefsMissedAlarmStore(prefs);
    await store.writeRecord(
      const PhoneRecord().merged(
        const PhoneCapture(arrivedIds: {'inc_1'}),
        now: at,
      ),
    );
    await store.writeDismissed({'inc_1': at});
    await store.writeTopicHolds({
      'prod': [TopicHold(since: at)],
    });
    await store.writeSetupDoneAt(at);

    await store.clearServerData();

    final next = SharedPrefsMissedAlarmStore(prefs);
    expect(next.readRecord().arrivedAtMs, isEmpty);
    expect(next.readRecord().completeSinceMs, isNull);
    expect(next.readDismissed(), isEmpty);
    expect(next.readTopicHolds(), isEmpty);
    expect(next.readSetupDoneAt(), at);
  });

  test('an empty server stamp reads back as no server', () async {
    final store = SharedPrefsMissedAlarmStore(prefs);
    await store.writeConnected(ConnectedServer(server: '', since: at));
    expect(store.readConnected()!.server, isEmpty);
    expect(store.readConnected()!.since, at);
  });

  test('closed entries stick across launches', () async {
    await SharedPrefsMissedAlarmStore(prefs).writeDismissed({'inc_1': at});
    // A new launch builds a new store over the same phone.
    final next = SharedPrefsMissedAlarmStore(prefs);
    expect(next.readDismissed(), {'inc_1': at});
  });

  test('the record, the setup stamp and the server stamp read back', () async {
    final store = SharedPrefsMissedAlarmStore(prefs);
    final record = const PhoneRecord().merged(
      PhoneCapture(
        eventRows: [
          {
            'name': 'push_received',
            'at_ms': at.millisecondsSinceEpoch,
            'kind': 'open',
          },
        ],
        arrivedIds: const {'inc_1'},
      ),
      now: at,
    );
    await store.writeRecord(record);
    await store.writeSetupDoneAt(at);
    await store.writeConnected(
      ConnectedServer(server: 'https://alerts.example.com', since: at),
    );

    final next = SharedPrefsMissedAlarmStore(prefs);
    expect(next.readRecord().rows, record.rows);
    expect(next.readRecord().arrivedAtMs, record.arrivedAtMs);
    expect(next.readSetupDoneAt(), at);
    expect(next.readConnected()!.server, 'https://alerts.example.com');
    expect(next.readConnected()!.since, at);
  });

  test('a damaged value reads as nothing', () async {
    await prefs.setString(SharedPrefsMissedAlarmStore.recordKey, '{oops');
    await prefs.setString(SharedPrefsMissedAlarmStore.dismissedKey, '[1]');
    await prefs.setString(
      SharedPrefsMissedAlarmStore.topicsHeldKey,
      '{"a": 3, "b": [["x"], [5]]}',
    );
    final store = SharedPrefsMissedAlarmStore(prefs);
    expect(store.readRecord().rows, isEmpty);
    expect(store.readDismissed(), isEmpty);
    expect(store.readTopicHolds().keys, ['b']);
  });
}
