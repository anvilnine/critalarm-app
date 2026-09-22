import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/features/settings/presentation/debug_push_event_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event details preserve parameters alongside readable local time', () {
    final details = formatDebugPushEventDetails(
      DebugPushEvent({
        'name': 'debug_action',
        'action': 'clear_content_cache',
        'incident_id': 'inc_1',
        'at_ms': DateTime(2026, 9, 23, 9, 55).millisecondsSinceEpoch,
      }),
      now: DateTime(2026, 9, 23, 10),
    );

    expect(details, contains('2026'));
    expect(details, contains('5m ago'));
    expect(details, contains('"action":"clear_content_cache"'));
    expect(details, contains('"incident_id":"inc_1"'));
    expect(details, isNot(contains('"at_ms"')));
  });
}
