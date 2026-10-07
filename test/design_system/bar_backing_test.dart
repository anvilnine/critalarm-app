import 'package:critalarm/design_system/bar_backing.dart';
import 'package:critalarm/design_system/widgets/progressive_blur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarBackingConfig.defaults', () {
    const defaults = BarBackingConfig.defaults;

    test('both bars blur under a fade of the canvas colour', () {
      expect(defaults.top.mode, BarBackingMode.blurAndGradient);
      expect(defaults.bottom.mode, BarBackingMode.blurAndGradient);
    });

    test('the blur is clearly stronger than the quiet edge blur', () {
      expect(
        defaults.top.blurSigma,
        greaterThanOrEqualTo(3 * ProgressiveBlurEdge.quietSigma),
      );
      expect(
        defaults.bottom.blurSigma,
        greaterThanOrEqualTo(3 * ProgressiveBlurEdge.quietSigma),
      );
    });

    test('the fade stays well short of a solid band', () {
      expect(defaults.top.gradientPeak, lessThanOrEqualTo(0.75));
      expect(defaults.bottom.gradientPeak, lessThanOrEqualTo(0.75));
      expect(defaults.top.gradientPeak, greaterThan(0));
      expect(defaults.top.fadeLength, greaterThan(0));
      expect(defaults.bottom.fadeLength, greaterThan(0));
    });

    test('every default is inside its slider range', () {
      for (final style in [defaults.top, defaults.bottom]) {
        expect(style, style.copyWith());
      }
    });
  });

  group('BarBackingStyle', () {
    BarBackingStyle style({
      double blur = 10,
      double fade = 20,
      double peak = 0.5,
    }) => BarBackingStyle(
      mode: BarBackingMode.blurAndGradient,
      blurSigma: blur,
      fadeLength: fade,
      gradientPeak: peak,
    );

    test('clamps the blur to 0 and its maximum', () {
      expect(style(blur: -5).blurSigma, 0);
      expect(style(blur: 400).blurSigma, BarBackingStyle.maxBlurSigma);
      expect(style(blur: 12.5).blurSigma, 12.5);
    });

    test('clamps the fade length to 0 and its maximum', () {
      expect(style(fade: -1).fadeLength, 0);
      expect(style(fade: 1000).fadeLength, BarBackingStyle.maxFadeLength);
    });

    test('clamps the gradient peak to 0 and 1', () {
      expect(style(peak: -0.2).gradientPeak, 0);
      expect(style(peak: 1.7).gradientPeak, 1);
    });

    test('copyWith clamps too and keeps the rest', () {
      final changed = style().copyWith(
        gradientPeak: 3,
        mode: BarBackingMode.blur,
      );
      expect(changed.gradientPeak, 1);
      expect(changed.mode, BarBackingMode.blur);
      expect(changed.blurSigma, 10);
      expect(changed.fadeLength, 20);
    });

    test('two styles with the same values are equal', () {
      expect(style(), style());
      expect(style().hashCode, style().hashCode);
      expect(style(), isNot(style(peak: 0.51)));
    });
  });

  group('BarBackingConfig text', () {
    test('reads back what it wrote', () {
      final config = BarBackingConfig(
        top: BarBackingStyle(
          mode: BarBackingMode.gradient,
          blurSigma: 7.5,
          fadeLength: 40,
          gradientPeak: 0.35,
        ),
        bottom: BarBackingStyle(
          mode: BarBackingMode.solid,
          blurSigma: 22,
          fadeLength: 12,
          gradientPeak: 0.9,
        ),
      );
      expect(BarBackingConfig.decode(config.encode()), config);
    });

    test('every mode has its own key and reads back', () {
      final keys = BarBackingMode.values.map((mode) => mode.key).toSet();
      expect(keys, hasLength(BarBackingMode.values.length));
      for (final mode in BarBackingMode.values) {
        expect(BarBackingMode.fromKey(mode.key), mode);
      }
      expect(BarBackingMode.fromKey('frosted'), isNull);
      expect(BarBackingMode.fromKey(null), isNull);
    });

    test('nothing stored is the defaults', () {
      expect(BarBackingConfig.decode(null), BarBackingConfig.defaults);
      expect(BarBackingConfig.decode(''), BarBackingConfig.defaults);
    });

    test('text that is not a config is the defaults', () {
      expect(BarBackingConfig.decode('{not json'), BarBackingConfig.defaults);
      expect(BarBackingConfig.decode('[1, 2]'), BarBackingConfig.defaults);
      expect(BarBackingConfig.decode('"blur"'), BarBackingConfig.defaults);
    });

    test('a missing or broken part takes its default', () {
      final config = BarBackingConfig.decode(
        '{"top": {"mode": "gradient", "blur": "strong", "peak": 0.2}}',
      );
      const defaults = BarBackingConfig.defaults;
      expect(config.top.mode, BarBackingMode.gradient);
      expect(config.top.gradientPeak, 0.2);
      expect(config.top.blurSigma, defaults.top.blurSigma);
      expect(config.top.fadeLength, defaults.top.fadeLength);
      expect(config.bottom, defaults.bottom);
    });

    test('numbers out of range are clamped on the way in', () {
      final config = BarBackingConfig.decode(
        '{"bottom": {"mode": "blur", "blur": 9000, "fade": -3, "peak": 2}}',
      );
      expect(config.bottom.blurSigma, BarBackingStyle.maxBlurSigma);
      expect(config.bottom.fadeLength, 0);
      expect(config.bottom.gradientPeak, 1);
    });
  });

  group('barBackingGradientPeak', () {
    BarBackingStyle style(BarBackingMode mode, {double peak = 0.6}) =>
        BarBackingStyle(
          mode: mode,
          blurSigma: 14,
          fadeLength: 28,
          gradientPeak: peak,
        );

    test('with the blur drawn, each mode fades as much as it says', () {
      expect(
        barBackingGradientPeak(
          style(BarBackingMode.blurAndGradient),
          blurs: true,
        ),
        0.6,
      );
      expect(
        barBackingGradientPeak(style(BarBackingMode.gradient), blurs: true),
        0.6,
      );
      expect(
        barBackingGradientPeak(style(BarBackingMode.blur), blurs: true),
        0,
      );
    });

    test('a mode that blurs leans on the fade where nothing blurs', () {
      expect(
        barBackingGradientPeak(
          style(BarBackingMode.blurAndGradient),
          blurs: false,
        ),
        barBackingPeakWithoutBlur,
      );
      expect(
        barBackingGradientPeak(style(BarBackingMode.blur), blurs: false),
        barBackingPeakWithoutBlur,
      );
      expect(barBackingPeakWithoutBlur, lessThan(1));
    });

    test('the fallback never lowers a peak set higher', () {
      expect(
        barBackingGradientPeak(
          style(BarBackingMode.blurAndGradient, peak: 0.97),
          blurs: false,
        ),
        0.97,
      );
    });

    test('gradient only is what it says with or without a blur', () {
      expect(
        barBackingGradientPeak(style(BarBackingMode.gradient), blurs: false),
        0.6,
      );
    });

    test('solid and none draw no fade', () {
      for (final blurs in [true, false]) {
        expect(
          barBackingGradientPeak(style(BarBackingMode.solid), blurs: blurs),
          0,
        );
        expect(
          barBackingGradientPeak(style(BarBackingMode.none), blurs: blurs),
          0,
        );
      }
    });
  });

  group('ProgressiveBlurEdge.sliceSigmas', () {
    test('a stronger blur keeps the same number of slices', () {
      for (final sigma in [0.0, 1.0, 4.0, 14.0, 16.0, 40.0]) {
        expect(
          ProgressiveBlurEdge.sliceSigmas(sigma),
          hasLength(ProgressiveBlurEdge.sliceCount),
        );
      }
      expect(ProgressiveBlurEdge.sliceCount, 24);
    });

    test('every slice scales with the strength', () {
      final quiet = ProgressiveBlurEdge.sliceSigmas(4);
      final strong = ProgressiveBlurEdge.sliceSigmas(16);
      for (var i = 0; i < quiet.length; i++) {
        expect(strong[i], closeTo(4 * quiet[i], 1e-9));
      }
    });

    test('is strongest at the edge and eases to almost nothing', () {
      final sigmas = ProgressiveBlurEdge.sliceSigmas(16);
      expect(sigmas.first, closeTo(16, 0.05));
      expect(sigmas.first, lessThanOrEqualTo(16));
      expect(sigmas.last, lessThan(0.1));
      for (var i = 1; i < sigmas.length; i++) {
        expect(sigmas[i], lessThan(sigmas[i - 1]));
      }
    });
  });
}
