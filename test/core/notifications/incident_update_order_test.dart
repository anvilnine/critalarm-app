import 'package:critalarm/core/notifications/incident_update_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime.utc(2026, 1, 1, 12);

  test('stale update is ignored while equal and newer updates apply', () {
    final current = IncidentUpdateOrder(base);
    expect(
      current.accepts(
        IncidentUpdateOrder(base.subtract(const Duration(seconds: 1))),
      ),
      isFalse,
    );
    expect(current.accepts(IncidentUpdateOrder(base)), isTrue);
    expect(
      current.accepts(
        IncidentUpdateOrder(base.add(const Duration(seconds: 1))),
      ),
      isTrue,
    );
  });
}
