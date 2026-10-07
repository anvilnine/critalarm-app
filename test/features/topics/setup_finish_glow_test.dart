import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/features/topics/domain/setup_finish_glow.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

SetupGlowStep _step({
  bool isHomeInFront = true,
  bool isGuideOffered = false,
  bool isGuideRunning = false,
  bool isListLoaded = true,
  bool hasTopicRow = true,
}) => setupGlowStepFor(
  isHomeInFront: isHomeInFront,
  isGuideOffered: isGuideOffered,
  isGuideRunning: isGuideRunning,
  isListLoaded: isListLoaded,
  hasTopicRow: hasTopicRow,
);

void main() {
  group('which topic glows', () {
    test('the topic setup made, when finishing a step ended setup', () {
      expect(
        setupGlowTopicFor(
          endedSetup: true,
          isReplay: false,
          firstTopicName: 'prod-db',
        ),
        'prod-db',
      );
    });

    test('none while setup goes on to another step', () {
      expect(
        setupGlowTopicFor(
          endedSetup: false,
          isReplay: false,
          firstTopicName: 'prod-db',
        ),
        isNull,
      );
    });

    test('none on a replay from Settings, which also ends at Home', () {
      expect(
        setupGlowTopicFor(
          endedSetup: true,
          isReplay: true,
          firstTopicName: 'prod-db',
        ),
        isNull,
      );
    });

    test('none when setup made no topic', () {
      for (final name in [null, '', '  ']) {
        expect(
          setupGlowTopicFor(
            endedSetup: true,
            isReplay: false,
            firstTopicName: name,
          ),
          isNull,
        );
      }
    });
  });

  group('the signal', () {
    test('holds nothing until setup ends', () {
      expect(SetupFinishSignal().take(), isNull);
    });

    test('is taken once, so a second Home finds nothing', () {
      final signal = SetupFinishSignal()..raise('prod-db');
      expect(signal.take(), 'prod-db');
      expect(signal.take(), isNull);
    });

    test('a new one, as after a restart, holds nothing', () {
      SetupFinishSignal().raise('prod-db');
      expect(SetupFinishSignal().take(), isNull);
    });
  });

  group('when the glow plays', () {
    test('with Home in front, the list loaded and the topic in it', () {
      expect(_step(), SetupGlowStep.play);
    });

    test('waits while the list is loading', () {
      expect(
        _step(isListLoaded: false, hasTopicRow: false),
        SetupGlowStep.wait,
      );
    });

    test('waits while Home is covered or the app is not in front', () {
      expect(_step(isHomeInFront: false), SetupGlowStep.wait);
    });

    test('waits behind the offer to be shown around', () {
      expect(_step(isGuideOffered: true), SetupGlowStep.wait);
    });

    test('is dropped once a guide runs', () {
      expect(_step(isGuideRunning: true), SetupGlowStep.drop);
      expect(
        _step(isGuideRunning: true, isListLoaded: false),
        SetupGlowStep.drop,
      );
    });

    test('is dropped when the loaded list does not hold the topic', () {
      expect(_step(hasTopicRow: false), SetupGlowStep.drop);
    });
  });

  group('the glow', () {
    test('fades in, holds and leaves, in design system times', () {
      expect(setupGlowFadeInTakes, AppDurations.base);
      expect(setupGlowFadeOutTakes, AppDurations.slow);
      expect(setupGlowTakes(isStill: false), _ms(1600));
    });

    test('rises to full, stays, and is gone at the end', () {
      expect(setupGlowStrengthAt(Duration.zero, isStill: false), 0);
      expect(
        setupGlowStrengthAt(_ms(150), isStill: false),
        closeTo(0.5, 1e-9),
      );
      expect(setupGlowStrengthAt(_ms(300), isStill: false), 1);
      expect(setupGlowStrengthAt(_ms(1200), isStill: false), 1);
      expect(
        setupGlowStrengthAt(_ms(1400), isStill: false),
        closeTo(0.5, 1e-9),
      );
      expect(setupGlowStrengthAt(_ms(1600), isStill: false), 0);
      expect(setupGlowStrengthAt(_ms(9000), isStill: false), 0);
    });

    test('under reduced motion is full at once and holds for 2 s', () {
      expect(setupGlowStrengthAt(Duration.zero, isStill: true), 1);
      expect(setupGlowStrengthAt(_ms(1999), isStill: true), 1);
      expect(setupGlowStrengthAt(_ms(2000), isStill: true), 1);
    });

    test('under reduced motion then fades and is gone', () {
      expect(setupGlowStillFadeTakes, AppDurations.base);
      expect(
        setupGlowStrengthAt(_ms(2150), isStill: true),
        closeTo(0.5, 1e-9),
      );
      expect(setupGlowStrengthAt(_ms(2300), isStill: true), 0);
      expect(setupGlowTakes(isStill: true), _ms(2300));
    });

    test('is nothing before it starts', () {
      expect(setupGlowStrengthAt(_ms(-1), isStill: false), 0);
      expect(setupGlowStrengthAt(_ms(-1), isStill: true), 0);
    });
  });
}
