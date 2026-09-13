import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the queue sent and answers however the test wants.
class _FakeApi implements ApiClient {
  _FakeApi({this.onAck});

  final Future<Incident> Function(String id)? onAck;

  final acked = <String>[];
  final closed = <String>[];

  @override
  Future<Incident> ackIncident(String id) async {
    acked.add(id);
    return onAck?.call(id) ?? Incident(id: id, topic: 'prod', state: 'acked');
  }

  @override
  Future<Incident> closeIncident(String id) async {
    closed.add(id);
    return Incident(id: id, topic: 'prod', state: 'closed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

DateTime Function() _fixedClock(DateTime Function() read) => read;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('an ack is written to disk before it is sent', () async {
    final api = _FakeApi(
      onAck: (_) async => throw const ApiException(
        statusCode: 503,
        message: 'offline',
      ),
    );
    final queue = AckQueue(prefs, api);

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');

    expect(prefs.getString(AckQueue.storageKey), isNotNull);
    expect(queue.pending.single.incidentId, 'inc_1');
    expect(queue.pending.single.action, AckAction.ack);
  });

  test('a send that works clears the entry', () async {
    final api = _FakeApi();
    final queue = AckQueue(prefs, api);

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    await queue.flush();

    expect(api.acked, ['inc_1']);
    expect(queue.pending, isEmpty);
    expect(prefs.getString(AckQueue.storageKey), isNull);
  });

  test('close calls the close route', () async {
    final api = _FakeApi();
    final queue = AckQueue(prefs, api);

    await queue.enqueue(action: AckAction.close, incidentId: 'inc_2');
    await queue.flush();

    expect(api.closed, ['inc_2']);
    expect(api.acked, isEmpty);
  });

  test('a send that fails is kept and retried with a growing wait', () async {
    var now = DateTime.utc(2026, 2, 3);
    var fail = true;
    final api = _FakeApi(
      onAck: (_) async {
        if (fail) throw const ApiException(statusCode: 503, message: 'down');
        return const Incident(id: 'inc_1', topic: 'prod', state: 'acked');
      },
    );
    final queue = AckQueue(prefs, api, clock: _fixedClock(() => now));

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    await queue.flush();
    expect(queue.pending.single.attempts, 1);
    final firstWait =
        queue.pending.single.nextAttemptAtMs - now.millisecondsSinceEpoch;
    expect(firstWait, AckQueue.baseBackoff.inMilliseconds);

    // Too early: the entry is skipped, so no second call is made.
    final callsSoFar = api.acked.length;
    await queue.flush();
    expect(api.acked.length, callsSoFar);

    now = now.add(AckQueue.baseBackoff);
    await queue.flush();
    expect(api.acked.length, callsSoFar + 1);
    expect(queue.pending.single.attempts, 2);
    final secondWait =
        queue.pending.single.nextAttemptAtMs - now.millisecondsSinceEpoch;
    expect(secondWait, AckQueue.baseBackoff.inMilliseconds * 2);

    // Network is back.
    fail = false;
    now = now.add(Duration(milliseconds: secondWait));
    await queue.flush();
    expect(queue.pending, isEmpty);
  });

  test('the wait never passes the cap', () async {
    var now = DateTime.utc(2026, 2, 3);
    final api = _FakeApi(
      onAck: (_) async =>
          throw const ApiException(statusCode: 503, message: 'down'),
    );
    final queue = AckQueue(prefs, api, clock: _fixedClock(() => now));

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    for (var i = 0; i < 10; i++) {
      await queue.flush();
      if (queue.pending.isEmpty) break;
      final wait =
          queue.pending.single.nextAttemptAtMs - now.millisecondsSinceEpoch;
      expect(wait, lessThanOrEqualTo(AckQueue.maxBackoff.inMilliseconds));
      now = now.add(Duration(milliseconds: wait));
    }
  });

  test('a 409 is the end of the road, not a retry', () async {
    final api = _FakeApi(
      onAck: (_) async => throw const ApiException(
        statusCode: 409,
        message: 'incident is not open',
      ),
    );
    final queue = AckQueue(prefs, api);

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    await queue.flush();

    expect(queue.pending, isEmpty);
    expect(api.acked, ['inc_1']);
  });

  test('a 429 is retried', () async {
    final api = _FakeApi(
      onAck: (_) async =>
          throw const ApiException(statusCode: 429, message: 'rate limited'),
    );
    final queue = AckQueue(prefs, api);

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    await queue.flush();

    expect(queue.pending.single.attempts, 1);
  });

  test('an entry survives a restart', () async {
    final offline = _FakeApi(
      onAck: (_) async => throw Exception('no network'),
    );
    final first = AckQueue(prefs, offline);
    await first.enqueue(
      action: AckAction.ack,
      incidentId: 'inc_1',
      alarmFiredAtMs: 1000,
    );
    await first.flush();
    expect(first.pending, hasLength(1));

    // Restart: a brand new queue over the same storage.
    SharedPreferences.setMockInitialValues({
      AckQueue.storageKey: prefs.getString(AckQueue.storageKey)!,
    });
    final reloaded = await SharedPreferences.getInstance();
    final online = _FakeApi();
    // The retry wait from the failed attempt has passed by the time the app is
    // opened again.
    final second = AckQueue(
      reloaded,
      online,
      clock: _fixedClock(() => DateTime.now().add(const Duration(hours: 1))),
    );

    expect(second.pending.single.incidentId, 'inc_1');
    expect(second.pending.single.alarmFiredAtMs, 1000);

    await second.flush();
    expect(online.acked, ['inc_1']);
    expect(second.pending, isEmpty);
  });

  test('an entry is dropped after too many failures', () async {
    var now = DateTime.utc(2026, 2, 3);
    final api = _FakeApi(onAck: (_) async => throw Exception('no network'));
    final queue = AckQueue(prefs, api, clock: _fixedClock(() => now));

    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    for (var i = 0; i < AckQueue.maxAttempts + 2; i++) {
      await queue.flush();
      if (queue.pending.isEmpty) break;
      now = now.add(AckQueue.maxBackoff);
    }
    expect(queue.pending, isEmpty);
    expect(api.acked.length, AckQueue.maxAttempts);
  });

  test('two acks for one incident do not collapse into one', () async {
    final api = _FakeApi(
      onAck: (_) async => throw Exception('no network'),
    );
    final queue = AckQueue(prefs, api);
    await queue.enqueue(action: AckAction.ack, incidentId: 'inc_1');
    await queue.enqueue(action: AckAction.close, incidentId: 'inc_1');
    expect(queue.pending.length, 2);
    expect(queue.pending.map((e) => e.id).toSet().length, 2);
  });

  test('a corrupt store reads as empty instead of throwing', () async {
    await prefs.setString(AckQueue.storageKey, 'not json');
    final queue = AckQueue(prefs, _FakeApi());
    expect(queue.pending, isEmpty);
  });
}
