import 'dart:async';

import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 3, 10);

  Incident incident({
    String id = 'inc_1',
    String state = IncidentStates.open,
    DateTime? openedAt,
  }) => Incident(
    id: id,
    topic: 'ops',
    state: state,
    openedAt: openedAt ?? now.subtract(const Duration(minutes: 2)),
  );

  bool focusOn(List<Incident> incidents, {int? Function(String)? maxRingS}) =>
      alarmFocusOn(
        incidents: incidents,
        now: now,
        maxRingSeconds: maxRingS,
      );

  group('the rule', () {
    test('is on with one open incident nobody has acknowledged', () {
      expect(focusOn([incident()]), isTrue);
    });

    test('is off once that incident is acknowledged', () {
      expect(focusOn([incident(state: IncidentStates.acked)]), isFalse);
    });

    test('stays on after Stop, because the incident is still open', () {
      // Stop silences the phone and leaves the incident open, so nothing in
      // the list changes and focus holds through the quiet gap.
      expect(focusOn([incident()]), isTrue);
    });

    test('is off once the ring window has run out', () {
      final old = incident(openedAt: now.subtract(const Duration(hours: 1)));
      expect(focusOn([old]), isFalse);
    });

    test('reads the ring window off the topic when it has one', () {
      final opened = incident(
        openedAt: now.subtract(const Duration(minutes: 20)),
      );
      // 1800 s by default, so twenty minutes in it is still on.
      expect(focusOn([opened]), isTrue);
      expect(focusOn([opened], maxRingS: (_) => 600), isFalse);
    });

    test('is off with an empty list', () {
      expect(focusOn(const []), isFalse);
    });

    test('holds an open incident that carries no opened time', () {
      expect(
        alarmFocusOn(
          incidents: const [Incident(id: 'inc_1', topic: 'ops')],
          now: now,
        ),
        isTrue,
      );
    });

    test('closed and expired incidents do not hold it', () {
      expect(
        focusOn([
          incident(state: IncidentStates.closed),
          incident(id: 'inc_2', state: IncidentStates.expired),
        ]),
        isFalse,
      );
    });

    test('lists only the open incidents inside their window', () {
      final focused = focusedOpenIncidents(
        incidents: [
          incident(),
          incident(id: 'inc_2', state: IncidentStates.acked),
          incident(
            id: 'inc_3',
            openedAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        now: now,
      );
      expect(focused.map((i) => i.id), ['inc_1']);
    });
  });

  group('the class', () {
    test('is off with nothing wired to it', () {
      expect(AlarmFocus().on, isFalse);
    });

    test('follows the shared list and emits each change', () async {
      final list = StreamController<List<Incident>>.broadcast();
      final focus = AlarmFocus(incidents: list.stream, now: () => now);
      final seen = <bool>[];
      focus.stream.listen(seen.add);

      expect(focus.on, isFalse);

      list.add([incident()]);
      await Future<void>.delayed(Duration.zero);
      expect(focus.on, isTrue);

      // A second incident is not a second change.
      list.add([incident(), incident(id: 'inc_2')]);
      await Future<void>.delayed(Duration.zero);
      expect(focus.on, isTrue);

      list.add([
        incident(state: IncidentStates.acked),
        incident(id: 'inc_2', state: IncidentStates.acked),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(focus.on, isFalse);

      expect(seen, [true, false]);
      await focus.dispose();
      await list.close();
    });

    test('starts from the list it is given', () {
      final focus = AlarmFocus(
        current: () => [incident()],
        now: () => now,
      );
      expect(focus.on, isTrue);
    });
  });
}
