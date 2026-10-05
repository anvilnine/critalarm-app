import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PrefsSetupTestRing ring;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ring = PrefsSetupTestRing(await SharedPreferences.getInstance());
  });

  test('nothing is held before a test is sent', () {
    expect(ring.incidentId, isNull);
    expect(ring.incidentIds, isEmpty);
    expect(ring.unclosedIds, isEmpty);
  });

  test('Try again keeps the first id beside the second', () async {
    await ring.hold('inc_7');
    await ring.hold('inc_8');

    expect(ring.incidentId, 'inc_8');
    expect(ring.incidentIds, {'inc_7', 'inc_8'});
  });

  test(
    'a new instance reads the same ids back, as after a cold start',
    () async {
      await ring.hold('inc_7');
      await ring.markUnclosed('inc_6');
      final again = PrefsSetupTestRing(await SharedPreferences.getInstance());

      expect(again.incidentId, 'inc_7');
      expect(again.incidentIds, {'inc_7'});
      expect(again.unclosedIds, {'inc_6'});
    },
  );

  test('an id whose close failed stops being a setup test', () async {
    await ring.hold('inc_7');
    await ring.markUnclosed('inc_7');

    expect(ring.incidentIds, isEmpty);
    expect(ring.unclosedIds, {'inc_7'});
  });

  test(
    'setup completing forgets the run and keeps what is still to close',
    () async {
      await ring.hold('inc_7');
      await ring.hold('inc_8');
      await ring.markUnclosed('inc_7');

      await ring.clear();

      expect(ring.incidentId, isNull);
      expect(ring.incidentIds, isEmpty);
      expect(ring.unclosedIds, {'inc_7'});

      await ring.markClosed('inc_7');
      expect(ring.unclosedIds, isEmpty);
    },
  );

  group('the first tool alarm', () {
    test('is on record once the hook-up step heard it', () async {
      expect(ring.firstToolIncidentId, isNull);

      await ring.holdFirstMessage('inc_tool');

      expect(ring.firstToolIncidentId, 'inc_tool');
      expect(ring.setupIncidentIds, contains('inc_tool'));
      // It is not a test.
      expect(ring.incidentIds, isEmpty);
    });

    test('outlives setup completing, and a cold start', () async {
      await ring.holdFirstMessage('inc_tool');

      await ring.clear();

      final again = PrefsSetupTestRing(await SharedPreferences.getInstance());
      expect(again.firstToolIncidentId, 'inc_tool');
    });

    test('is forgotten once its screen is done with', () async {
      await ring.holdFirstMessage('inc_tool');
      await ring.noteFirstToolSeen(
        openedAt: DateTime(2026, 10, 4),
        lastMessageAt: DateTime(2026, 10, 4),
      );
      await ring.noteFirstToolAcked();

      await ring.forgetFirstTool();

      expect(ring.firstToolIncidentId, isNull);
      expect(ring.firstTool, isNull);
      // Its acknowledgement still never counts as real use.
      expect(ring.setupIncidentIds, contains('inc_tool'));
      // Nothing is left to describe the next one.
      await ring.holdFirstMessage('inc_next');
      expect(ring.firstTool?.wasSeen, isFalse);
      expect(ring.firstTool?.wasAcked, isFalse);
    });

    test(
      'keeps what the first ring looked like, across a cold start',
      () async {
        final openedAt = DateTime(2026, 10, 4, 21, 45);
        await ring.holdFirstMessage('inc_tool');
        await ring.noteFirstToolSeen(
          openedAt: openedAt,
          lastMessageAt: openedAt,
        );
        await ring.noteFirstToolAcked();

        final again = PrefsSetupTestRing(await SharedPreferences.getInstance());

        expect(again.firstTool?.incidentId, 'inc_tool');
        expect(again.firstTool?.openedAt, openedAt);
        expect(again.firstTool?.lastMessageAt, openedAt);
        expect(again.firstTool?.wasAcked, isTrue);
      },
    );

    test('notes with nothing on record write nothing', () async {
      await ring.noteFirstToolSeen(
        openedAt: DateTime(2026, 10, 4),
        lastMessageAt: null,
      );
      await ring.noteFirstToolAcked();

      expect(ring.firstTool, isNull);
    });

    test('a launch forgets one acknowledged in an earlier run', () async {
      await ring.holdFirstMessage('inc_tool');
      await ring.noteFirstToolAcked();

      await ring.settleFirstToolAtLaunch();

      expect(ring.firstTool, isNull);
    });

    test('a launch keeps one not acknowledged yet: the alarm may be what '
        'opened the app', () async {
      await ring.holdFirstMessage('inc_tool');

      await ring.settleFirstToolAtLaunch();

      expect(ring.firstTool?.incidentId, 'inc_tool');
    });
  });
}
