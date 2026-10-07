import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/features/reliability/data/platform_phone_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> row(String name, int atMs, [Map<String, Object?>? more]) =>
    {'name': name, 'at_ms': atMs, ...?more};

void main() {
  late SharedPreferences prefs;
  late Map<String, Object?> native;
  late List<AckQueueEntry> ackQueue;

  Future<PlatformPhoneCapture> build({
    List<Object?> pending = const [],
    List<Stream<String>> alarmIds = const [],
    Set<String> Function()? alarmingIds,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (pending.isNotEmpty) 'pending_push_events': jsonEncode(pending),
    });
    prefs = await SharedPreferences.getInstance();
    return PlatformPhoneCapture(
      prefs: prefs,
      readNative: () async => native,
      readAckQueue: () => ackQueue,
      alarmIds: alarmIds,
      alarmingIds: alarmingIds,
    );
  }

  setUp(() {
    native = const {};
    ackQueue = const [];
  });

  test('the pending list is copied and left as it was', () async {
    final pending = [
      row('push_received', 100, {'kind': 'open'}),
      row('alarm_fired', 101, {'incident_id': 'inc_1'}),
    ];
    final capture = await build(pending: pending);
    final taken = await capture.take();
    expect(taken.eventRows, pending);
    expect(taken.lostBeforeMs, isNull);
    // Read, never written: the drain still finds its rows.
    expect(prefs.getString('pending_push_events'), jsonEncode(pending));
  });

  test('rows held before the drain survive it', () async {
    final pending = [
      row('alarm_fired', 101, {'incident_id': 'inc_1'}),
    ];
    final capture = await build(pending: pending);
    capture.holdPendingRows();
    // The drain empties the list.
    await prefs.remove('pending_push_events');
    final taken = await capture.take();
    expect(taken.eventRows, pending);
  });

  test('held rows are handed over once', () async {
    final capture = await build(pending: [row('push_received', 100)]);
    capture.holdPendingRows();
    await prefs.remove('pending_push_events');
    await capture.take();
    expect((await capture.take()).eventRows, isEmpty);
  });

  test('a full list says where rows may have been lost', () async {
    final pending = [
      for (var i = 0; i < 50; i++) row('push_received', 1000 + i),
    ];
    final capture = await build(pending: pending);
    expect((await capture.take()).lostBeforeMs, 1000);
  });

  test('a list one row short of full lost nothing', () async {
    final pending = [
      for (var i = 0; i < 49; i++) row('push_received', 1000 + i),
    ];
    final capture = await build(pending: pending);
    expect((await capture.take()).lostBeforeMs, isNull);
  });

  test(
    'the native snapshot adds its rows, alarms and acknowledgements',
    () async {
      native = {
        'push_events': [
          row('push_received', 200, {'kind': 'open'}),
        ],
        'incidents': [
          {'id': 'inc_rang', 'ring_until': 1757464200},
          {'id': 'inc_state_only'},
          {'id': 'inc_acked', 'acked_locally': true},
          {'id': ''},
          'junk',
        ],
        'acked_set': [
          {'incident_id': 'inc_marked'},
          {'incident_id': ''},
        ],
      };
      final capture = await build();
      final taken = await capture.take();
      expect(taken.eventRows, [
        row('push_received', 200, {'kind': 'open'}),
      ]);
      expect(taken.rangIds, {'inc_rang'});
      expect(taken.acknowledgedHereIds, {'inc_acked', 'inc_marked'});
    },
  );

  test('a native read that throws leaves the rest', () async {
    final capture = PlatformPhoneCapture(
      prefs: await () async {
        SharedPreferences.setMockInitialValues({
          'pending_push_events': jsonEncode([row('push_received', 100)]),
        });
        return SharedPreferences.getInstance();
      }(),
      readNative: () async => throw StateError('no channel'),
      readAckQueue: () => const [],
    );
    expect((await capture.take()).eventRows, hasLength(1));
  });

  test(
    'an acknowledgement still in the queue counts, a close does not',
    () async {
      ackQueue = const [
        AckQueueEntry(
          id: '1',
          action: AckAction.ack,
          incidentId: 'inc_ack',
          enqueuedAtMs: 1,
        ),
        AckQueueEntry(
          id: '2',
          action: AckAction.close,
          incidentId: 'inc_close',
          enqueuedAtMs: 2,
        ),
      ];
      final capture = await build();
      expect((await capture.take()).acknowledgedHereIds, {'inc_ack'});
    },
  );

  test('alarm ids the platform reports while the app runs are kept', () async {
    final scheduled = StreamController<String>.broadcast();
    final pushes = StreamController<String>.broadcast();
    final capture = await build(
      alarmIds: [scheduled.stream, pushes.stream],
      alarmingIds: () => {'inc_controller'},
    );
    capture
      ..start()
      // A second start does not listen twice.
      ..start();
    scheduled.add('inc_scheduled');
    pushes.add('inc_pushed');
    await Future<void>.delayed(Duration.zero);
    expect((await capture.take()).rangIds, {
      'inc_scheduled',
      'inc_pushed',
      'inc_controller',
    });
    await capture.dispose();
    await scheduled.close();
    await pushes.close();
  });

  test('a pending value that is not a list is nothing', () async {
    SharedPreferences.setMockInitialValues({'pending_push_events': '{oops'});
    final capture = PlatformPhoneCapture(
      prefs: await SharedPreferences.getInstance(),
      readNative: () async => const {},
      readAckQueue: () => const [],
    );
    capture.holdPendingRows();
    expect((await capture.take()).eventRows, isEmpty);
  });
}
