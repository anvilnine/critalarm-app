import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 23, 10);

  test(
    'load combines native and Dart ack queues into one immutable snapshot',
    () async {
      final cubit = _cubit(
        native: () async => {
          'ack_queue': [
            {
              'action': 'ack',
              'incident_id': 'inc_1',
              'attempts': 1,
              'next_attempt_at': 2,
            },
          ],
        },
        dart: () => [
          const AckQueueEntry(
            id: 'queue-1',
            action: AckAction.ack,
            incidentId: 'inc_1',
            enqueuedAtMs: 0,
            attempts: 3,
            nextAttemptAtMs: 4000,
          ),
        ],
        clock: () => at,
      );
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.snapshot!.ackQueue, hasLength(1));
      expect(cubit.state.snapshot!.ackQueue.single.attempts, 3);
      expect(
        cubit.state.snapshot!.ackQueue.single.source,
        DebugAckSource.combined,
      );
    },
  );

  test(
    'older refresh completing later cannot replace the newer result',
    () async {
      final first = Completer<Map<String, Object?>>();
      final second = Completer<Map<String, Object?>>();
      var calls = 0;
      final cubit = _cubit(
        native: () => (++calls == 1 ? first.future : second.future),
        clock: () => at,
      );
      addTearDown(cubit.close);

      final older = cubit.refresh();
      final newer = cubit.refresh();
      second.complete({
        'incidents': [
          {'id': 'inc_new'},
        ],
      });
      await newer;
      first.complete({
        'incidents': [
          {'id': 'inc_old'},
        ],
      });
      await older;

      expect(cubit.state.snapshot!.incidents.single.id, 'inc_new');
    },
  );

  test(
    'each action calls only its dependency, records action, then refreshes',
    () async {
      final calls = <String>[];
      final actions = <String>[];
      var nativeReads = 0;
      final cubit = AlarmDebugCubit(
        readNative: () async {
          nativeReads++;
          return <String, Object?>{};
        },
        readEnvironment: () async => const DebugEnvironment(),
        readDartAckQueue: () => const [],
        readPushEvents: () => const [],
        readLaunchCalls: () => const [],
        readStoreStats: () async => DebugStoreStats.empty,
        flushNow: () async => calls.add('flush'),
        cancelAllRearms: () async => calls.add('cancel'),
        clearContentCache: () async => calls.add('content'),
        clearAckedSet: () async => calls.add('acked'),
        reconcileNow: () async => calls.add('reconcile'),
        recordDebugAction: actions.add,
        clock: () => at,
      );
      addTearDown(cubit.close);
      await cubit.refresh();

      await cubit.performAction(AlarmDebugAction.flushNow);
      expect(calls, ['flush']);
      expect(actions, ['flush_now']);
      expect(nativeReads, 2);
    },
  );

  test(
    'copy report is valid snapshot JSON and refresh errors retain prior data',
    () async {
      var fail = false;
      final cubit = _cubit(
        native: () async {
          if (fail) throw StateError('offline');
          return {
            'incidents': [
              {'id': 'inc_1'},
            ],
          };
        },
        clock: () => at,
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      final report = cubit.copyReportJson();
      expect(
        AlarmDebugSnapshot.fromJson(
          Map<String, Object?>.from(jsonDecode(report) as Map),
        ).incidents.single.id,
        'inc_1',
      );

      fail = true;
      await cubit.refresh();
      expect(cubit.state.snapshot!.incidents.single.id, 'inc_1');
      expect(cubit.state.error, contains('offline'));
    },
  );
}

AlarmDebugCubit _cubit({
  required Future<Map<String, Object?>> Function() native,
  List<AckQueueEntry> Function()? dart,
  DateTime Function()? clock,
}) => AlarmDebugCubit(
  readNative: native,
  readEnvironment: () async => const DebugEnvironment(),
  readDartAckQueue: dart ?? () => const [],
  readPushEvents: () => const [],
  readLaunchCalls: () => const [],
  readStoreStats: () async => DebugStoreStats.empty,
  flushNow: () async {},
  cancelAllRearms: () async {},
  clearContentCache: () async {},
  clearAckedSet: () async {},
  reconcileNow: () async {},
  recordDebugAction: (_) {},
  clock: clock,
);
