import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains the latest 50 calls and returns newest failures first', () {
    final log = LaunchCallLog(clock: () => DateTime.utc(2026, 9, 23));
    for (var attempt = 1; attempt <= 55; attempt++) {
      log.recordFailure(
        name: 'call',
        attempt: attempt,
        error: StateError('e$attempt'),
      );
    }

    expect(log.entries, hasLength(50));
    expect(log.entries.first.attempt, 6);
    expect(log.recentFailures(), hasLength(20));
    expect(log.recentFailures().first.attempt, 55);
    expect(log.recentFailures().last.attempt, 36);
  });

  test('success is remembered per call name and replaces only that name', () {
    final log = LaunchCallLog();
    final first = DateTime.utc(2026, 9, 23, 10);
    final second = DateTime.utc(2026, 9, 23, 11);
    log.recordSuccess('topics', at: first);
    log.recordSuccess('register', at: first);
    log.recordSuccess('topics', at: second);

    expect(log.lastSuccessByName, {'topics': second, 'register': first});
  });
}
