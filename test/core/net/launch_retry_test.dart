import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/net/launch_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Duration> waited;
  late List<String> logged;

  Future<void> wait(Duration duration) async => waited.add(duration);
  void log(String line) => logged.add(line);

  setUp(() {
    waited = [];
    logged = [];
  });

  test('retries on SocketException and succeeds on attempt 3', () async {
    var attempt = 0;
    final result = await retryOnLaunch<int>(
      'device_registration',
      () async {
        attempt++;
        if (attempt < 3) throw const SocketException('no route');
        return 7;
      },
      wait: wait,
      log: log,
    );

    expect(result, 7);
    expect(attempt, 3);
    expect(waited, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    expect(logged, hasLength(2));
  });

  test(
    'retries ApiException(503), gives up after six attempts, rethrows',
    () async {
      var attempt = 0;
      await expectLater(
        retryOnLaunch<void>(
          'incident_reconcile',
          () async {
            attempt++;
            throw const ApiException(statusCode: 503, message: 'down');
          },
          wait: wait,
          log: log,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(attempt, 6);
      expect(waited, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 5),
        const Duration(seconds: 10),
        const Duration(seconds: 15),
      ]);
      expect(logged, hasLength(6));
    },
  );

  test('ApiException(401) is rethrown on attempt 1 with no wait', () async {
    var attempt = 0;
    await expectLater(
      retryOnLaunch<void>(
        'device_registration',
        () async {
          attempt++;
          throw const ApiException(
            statusCode: 401,
            message: 'dead credential',
          );
        },
        wait: wait,
        log: log,
      ),
      throwsA(isA<ApiException>()),
    );

    expect(attempt, 1);
    expect(waited, isEmpty);
    const expectedLine =
        'launch_call_failed call=device_registration attempt=1 '
        'error=ApiException status=401';
    expect(logged, [expectedLine]);
  });

  test('ApiException(404) is rethrown on attempt 1', () async {
    var attempt = 0;
    await expectLater(
      retryOnLaunch<void>(
        'incident_reconcile',
        () async {
          attempt++;
          throw const ApiException(statusCode: 404, message: 'not found');
        },
        wait: wait,
        log: log,
      ),
      throwsA(isA<ApiException>()),
    );

    expect(attempt, 1);
    expect(waited, isEmpty);
  });

  test('every failed attempt logs its own attempt number', () async {
    var attempt = 0;
    await retryOnLaunch<int>(
      'live_activity_token',
      () async {
        attempt++;
        if (attempt < 3) throw TimeoutException('slow');
        return 1;
      },
      wait: wait,
      log: log,
    );

    const attempt1 =
        'launch_call_failed call=live_activity_token attempt=1 '
        'error=TimeoutException';
    const attempt2 =
        'launch_call_failed call=live_activity_token attempt=2 '
        'error=TimeoutException';
    expect(logged, [attempt1, attempt2]);
  });
}
