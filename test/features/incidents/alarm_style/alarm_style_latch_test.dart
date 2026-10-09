import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_latch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlarmStyleLatch latch;
  late AlarmStyleId answer;
  late int asked;

  AlarmStyleId decide() {
    asked++;
    return answer;
  }

  setUp(() {
    latch = AlarmStyleLatch();
    answer = AlarmStyleId.standard;
    asked = 0;
  });

  test('the first build of an incident decides its look', () {
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.minimal);
    expect(latch.incidentId, 'inc_1');
    expect(asked, 1);
  });

  test('the same incident keeps its look when the decision changes', () {
    // A cold start from an alarm: the plan is not read yet, so the rule
    // answers Standard.
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    // The plan read lands mid-ring and the rule would now say Minimal.
    answer = AlarmStyleId.minimal;
    for (var tick = 0; tick < 5; tick++) {
      expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    }
    expect(asked, 1, reason: 'asked once, on the first build');
  });

  test('a look that was open stays when the plan lapses mid-ring', () {
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.minimal);
    answer = AlarmStyleId.standard;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.minimal);
  });

  test('a re-ring of the same incident keeps its look', () {
    // Ringing, acknowledged, then ringing again from its desk timer: the
    // id is the same all the way through.
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    expect(asked, 1);
  });

  test('a new incident taking the screen decides again', () {
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_2', decide: decide), AlarmStyleId.minimal);
    expect(latch.incidentId, 'inc_2');
    expect(asked, 2);
    // And coming back to the first one is a new look at it too.
    answer = AlarmStyleId.standard;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    expect(asked, 3);
  });

  test('the alarm leaving the screen lets go of the look', () {
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    latch.release();
    expect(latch.incidentId, isNull);
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.minimal);
  });

  test('an incident with no id is asked each time and keeps nothing', () {
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.standard);
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor(null, decide: decide), AlarmStyleId.minimal);
    expect(latch.styleFor('', decide: decide), AlarmStyleId.minimal);
    expect(latch.incidentId, isNull);
    expect(asked, 3);
  });

  test('a decision that throws keeps nothing, and the next build asks '
      'again', () {
    expect(
      () => latch.styleFor('inc_1', decide: () => throw StateError('no')),
      throwsStateError,
    );
    expect(latch.incidentId, isNull);
    answer = AlarmStyleId.minimal;
    expect(latch.styleFor('inc_1', decide: decide), AlarmStyleId.minimal);
  });
}
