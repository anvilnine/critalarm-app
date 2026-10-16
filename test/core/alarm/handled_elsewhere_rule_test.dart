import 'package:critalarm/core/alarm/handled_elsewhere_rule.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

final _openedAt = DateTime.utc(2026, 10, 17, 3);

Incident _incident({
  String state = IncidentStates.open,
  DateTime? openedAt,
  DateTime? updatedAt,
}) => Incident(
  id: 'inc_1',
  topic: 'prod-db',
  state: state,
  openedAt: openedAt,
  updatedAt: updatedAt,
);

void main() {
  group('endingState', () {
    test('acked, closed and expired end the ring', () {
      expect(HandledElsewhereRule.endingState('acked'), IncidentState.acked);
      expect(HandledElsewhereRule.endingState('closed'), IncidentState.closed);
      expect(
        HandledElsewhereRule.endingState('expired'),
        IncidentState.expired,
      );
    });

    test('open, null and words the app does not know do not', () {
      for (final state in ['open', null, '', 'ACKED', 'snoozed']) {
        expect(HandledElsewhereRule.endingState(state), isNull, reason: state);
      }
    });
  });

  group('endsRing', () {
    final ringing = _incident(openedAt: _openedAt, updatedAt: _openedAt);

    test('the same stage, acknowledged later, ends it', () {
      final held = _incident(
        state: IncidentStates.acked,
        openedAt: _openedAt,
        updatedAt: _openedAt.add(const Duration(minutes: 1)),
      );
      expect(HandledElsewhereRule.endsRing(held: held, ringing: ringing), true);
    });

    test('an earlier stage of a reopened incident does not', () {
      final held = _incident(
        state: IncidentStates.acked,
        openedAt: _openedAt.subtract(const Duration(minutes: 20)),
        updatedAt: _openedAt.subtract(const Duration(minutes: 15)),
      );
      expect(
        HandledElsewhereRule.endsRing(held: held, ringing: ringing),
        isFalse,
      );
    });

    test('a copy older than the ring does not', () {
      final held = _incident(
        state: IncidentStates.acked,
        openedAt: _openedAt,
        updatedAt: _openedAt.subtract(const Duration(seconds: 1)),
      );
      final later = ringing.copyWith(
        updatedAt: _openedAt.add(const Duration(minutes: 2)),
      );
      expect(HandledElsewhereRule.endsRing(held: held, ringing: later), false);
    });

    test('a copy with no opened_at does not', () {
      final held = _incident(state: IncidentStates.closed);
      expect(
        HandledElsewhereRule.endsRing(held: held, ringing: ringing),
        isFalse,
      );
    });

    test('an open copy does not', () {
      final held = _incident(openedAt: _openedAt, updatedAt: _openedAt);
      expect(
        HandledElsewhereRule.endsRing(held: held, ringing: ringing),
        isFalse,
      );
    });

    test('another incident does not', () {
      final held = _incident(
        state: IncidentStates.acked,
        openedAt: _openedAt,
      ).copyWith(id: 'inc_2');
      expect(
        HandledElsewhereRule.endsRing(held: held, ringing: ringing),
        isFalse,
      );
    });
  });

  test('wire names match the Live Activity words', () {
    expect(HandledElsewhereRule.wireName(IncidentState.acked), 'acked');
    expect(HandledElsewhereRule.wireName(IncidentState.closed), 'closed');
    expect(HandledElsewhereRule.wireName(IncidentState.expired), 'expired');
  });
}
