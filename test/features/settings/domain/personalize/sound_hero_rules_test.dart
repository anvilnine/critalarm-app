import 'package:critalarm/features/settings/domain/personalize/sound_hero_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bar count', () {
    test('is one bar per pitch and never leaves 14 to 40', () {
      expect(soundHeroBarCount(0), kSoundHeroMinBars);
      expect(soundHeroBarCount(100), kSoundHeroMinBars);
      expect(soundHeroBarCount(280), 15);
      expect(soundHeroBarCount(350), 19);
      expect(soundHeroBarCount(520), 28);
      expect(soundHeroBarCount(5000), kSoundHeroMaxBars);
    });

    test('the wave is shorter on a short display', () {
      expect(soundHeroHeightFor(isShort: false), 150);
      expect(soundHeroHeightFor(isShort: true), 96);
    });
  });

  group('peaks to bars', () {
    test('more peaks than bars: each bar takes the loudest of its share', () {
      final peaks = [0.1, 0.9, 0.2, 0.3, 0.8, 0.4, 0.5, 0.6];
      expect(soundHeroBars(peaks, 4), [0.9, 0.3, 0.8, 0.6]);
    });

    test('a share that is not a whole number of peaks overlaps its edge', () {
      // Three peaks over two bars: the shares are 1.5 peaks wide.
      expect(soundHeroBars([0.2, 0.9, 0.4], 2), [0.9, 0.9]);
    });

    test('fewer peaks than bars: each bar takes the peak under its middle', () {
      final bars = soundHeroBars([0.2, 0.8], 6);
      expect(bars, [0.2, 0.2, 0.2, 0.8, 0.8, 0.8]);
    });

    test('equal counts keep the peaks as they are', () {
      expect(soundHeroBars([0.3, 0.6, 0.9], 3), [0.3, 0.6, 0.9]);
    });

    test('empty or missing peaks give no bars, so the wave draws flat', () {
      expect(soundHeroBars(const [], 20), isEmpty);
      expect(soundHeroBars(null, 20), isEmpty);
    });

    test('a single peak makes every bar the same height', () {
      expect(soundHeroBars([0.7], 5), [0.7, 0.7, 0.7, 0.7, 0.7]);
    });

    test('values outside 0 to 1 are held inside it', () {
      expect(soundHeroBars([1.4, -0.2], 2), [1.0, 0.0]);
    });

    test('asking for no bars gives none', () {
      expect(soundHeroBars([0.5], 0), isEmpty);
    });
  });

  group('playhead fill', () {
    test('follows the progress and stays between 0 and 1', () {
      expect(soundHeroFill(0), 0);
      expect(soundHeroFill(0.5), 0.5);
      expect(soundHeroFill(1), 1);
      expect(soundHeroFill(1.2), 1);
      expect(soundHeroFill(-0.3), 0);
    });

    test('is null with no progress: the wave is at rest', () {
      expect(soundHeroFill(null), isNull);
    });

    test('fills no bar at 0, half at 0.5 and all at 1', () {
      const count = 20;
      int filled(double? fill) => [
        for (var i = 0; i < count; i++)
          if (soundHeroBarFilled(i, count, fill)) i,
      ].length;
      expect(filled(0), 0);
      expect(filled(0.5), 10);
      expect(filled(1), count);
    });

    test('at rest every bar is full', () {
      for (var i = 0; i < 14; i++) {
        expect(soundHeroBarFilled(i, 14, null), isTrue);
      }
    });

    test('fills from the left', () {
      expect(soundHeroBarFilled(0, 10, 0.2), isTrue);
      expect(soundHeroBarFilled(1, 10, 0.2), isTrue);
      expect(soundHeroBarFilled(2, 10, 0.2), isFalse);
    });
  });

  group('header state word', () {
    test('says playing while a preview plays', () {
      expect(
        soundHeaderStateKey(isPlaying: true),
        LocaleKeys.personalize_passes_sound_playing,
      );
    });

    test('says nothing at rest', () {
      expect(soundHeaderStateKey(isPlaying: false), isNull);
    });
  });
}
