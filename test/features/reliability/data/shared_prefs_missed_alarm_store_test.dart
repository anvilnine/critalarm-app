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
        rangIds: const {'inc_1'},
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
    expect(next.readRecord().rangAtMs, record.rangAtMs);
    expect(next.readSetupDoneAt(), at);
    expect(next.readConnected()!.server, 'https://alerts.example.com');
    expect(next.readConnected()!.since, at);
  });

  test('a damaged value reads as nothing', () async {
    await prefs.setString(SharedPrefsMissedAlarmStore.recordKey, '{oops');
    await prefs.setString(SharedPrefsMissedAlarmStore.dismissedKey, '[1]');
    final store = SharedPrefsMissedAlarmStore(prefs);
    expect(store.readRecord().rows, isEmpty);
    expect(store.readDismissed(), isEmpty);
  });
}
