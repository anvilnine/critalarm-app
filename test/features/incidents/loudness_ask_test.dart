import 'package:critalarm/features/incidents/domain/loudness_ask.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loudnessAskFor', () {
    LoudnessRetry? ask(
      AckedExits exits, {
      bool isIos = true,
      bool isTestIncident = false,
    }) => loudnessAskFor(
      isIos: isIos,
      exits: exits,
      isTestIncident: isTestIncident,
    );

    test('the setup test ring asks, and Ring again goes back to that step', () {
      expect(ask(AckedExits.continueSetup), LoudnessRetry.setupStep);
    });

    test('a test after setup asks, and Ring again opens the test ring', () {
      expect(ask(AckedExits.retest), LoudnessRetry.testRing);
      expect(
        ask(AckedExits.incident, isTestIncident: true),
        LoudnessRetry.testRing,
      );
    });

    test('a real alarm never asks', () {
      expect(ask(AckedExits.incident), isNull);
      expect(ask(AckedExits.firstToolAlarm), isNull);
      expect(ask(AckedExits.firstToolAlarm, isTestIncident: true), isNull);
    });

    test('the first shipped setup order does not ask', () {
      expect(ask(AckedExits.legacyFinish), isNull);
      expect(ask(AckedExits.legacyCreateTopicOrFinish), isNull);
    });

    test('nothing asks off an iPhone', () {
      for (final exits in AckedExits.values) {
        expect(
          ask(exits, isIos: false, isTestIncident: true),
          isNull,
          reason: '$exits',
        );
      }
    });
  });
}
