import 'package:critalarm/design_system/bar_backing.dart';
import 'package:critalarm/design_system/widgets/progressive_blur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarBackingConfig.defaults', () {
    const defaults = BarBackingConfig.defaults;

    test('both bars are the progressive blur with nothing over it', () {
      expect(defaults.top.mode, BarBackingMode.blur);
      expect(defaults.bottom.mode, BarBackingMode.blur);
    });

    test('neither bar has a flat part', () {
      expect(defaults.top.plateau, 0);
      expect(defaults.bottom.plateau, 0);
    });

    test('the blur is moderately stronger than the quiet edge blur', () {
      for (final style in [defaults.top, defaults.bottom]) {
        expect(style.blurSigma, greaterThan(ProgressiveBlurEdge.quietSigma));
        expect(
          style.blurSigma,
          lessThanOrEqualTo(2.5 * ProgressiveBlurEdge.quietSigma),
        );
      }
    });

    test('the ramp starts a comfortable way past the bar', () {
      expect(defaults.top.fadeLength, greaterThanOrEqualTo(24));
      expect(defaults.bottom.fadeLength, greaterThanOrEqualTo(24));
    });

    test('a gradient mode picked later starts from a light fade', () {
      expect(defaults.top.gradientPeak, lessThanOrEqualTo(0.35));
      expect(defaults.bottom.gradientPeak, lessThanOrEqualTo(0.35));
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

    test('has no plateau unless it is given one, and clamps it', () {
      expect(style().plateau, 0);
      expect(style().copyWith(plateau: 0.4).plateau, 0.4);
      expect(style().copyWith(plateau: -1).plateau, 0);
      expect(style().copyWith(plateau: 7).plateau, 1);
      expect(style(), isNot(style().copyWith(plateau: 0.4)));
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
          plateau: 0.25,
        ),
      );
      expect(BarBackingConfig.decode(config.encode()), config);
      expect(BarBackingConfig.decode(config.encode()).bottom.plateau, 0.25);
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
      // Text saved before the plateau existed has none.
      expect(config.top.plateau, 0);
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

  group('barBackingRamp', () {
    test('is nothing at the inner edge and full only at the screen edge', () {
      expect(barBackingRamp(0), 0);
      expect(barBackingRamp(1), 1);
      expect(barBackingRamp(0.999), lessThan(1));
    });

    test('rises all the way across the zone with no flat part', () {
      var before = barBackingRamp(0);
      for (var i = 1; i <= 100; i++) {
        final here = barBackingRamp(i / 100);
        expect(here, greaterThan(before), reason: 'at $i percent');
        before = here;
      }
    });

    test('is the smoothstep curve the edge blur always had', () {
      expect(barBackingRamp(0.25), closeTo(0.15625, 1e-9));
      expect(barBackingRamp(0.5), 0.5);
      expect(barBackingRamp(0.75), closeTo(0.84375, 1e-9));
    });

    test('starts gently, so there is no line where the effect begins', () {
      expect(barBackingRamp(0.02), lessThan(0.002));
      expect(barBackingRamp(0.1), lessThan(0.03));
    });

    test('a plateau holds the full strength only for its share', () {
      expect(barBackingRamp(0.6, plateau: 0.4), 1);
      expect(barBackingRamp(0.8, plateau: 0.4), 1);
      expect(barBackingRamp(0.3, plateau: 0.4), 0.5);
      expect(barBackingRamp(0, plateau: 0.4), 0);
      expect(barBackingRamp(0, plateau: 1), 1);
    });

    test('never leaves 0 to 1', () {
      expect(barBackingRamp(-3), 0);
      expect(barBackingRamp(9), 1);
    });
  });

  group('the default blur along its zone', () {
    // Sigma from the inner edge (0) to the screen edge (1).
    double sigmaAt(BarBackingStyle style, double position) =>
        style.blurSigma * barBackingRamp(position, plateau: style.plateau);

    test('top bar', () {
      final top = BarBackingConfig.defaults.top;
      expect(top.blurSigma, 8);
      expect(sigmaAt(top, 0), 0);
      expect(sigmaAt(top, 0.25), 1.25);
      expect(sigmaAt(top, 0.5), 4);
      expect(sigmaAt(top, 0.75), 6.75);
      expect(sigmaAt(top, 1), 8);
    });

    test('pinned bottom bar', () {
      final bottom = BarBackingConfig.defaults.bottom;
      expect(bottom.blurSigma, 9);
      expect(sigmaAt(bottom, 0), 0);
      expect(sigmaAt(bottom, 0.25), closeTo(1.41, 0.01));
      expect(sigmaAt(bottom, 0.5), 4.5);
      expect(sigmaAt(bottom, 0.75), closeTo(7.59, 0.01));
      expect(sigmaAt(bottom, 1), 9);
    });
  });

  test('no mode is overridden where a phone cannot blur', () {
    // The fade is exactly what the style says: a mode with no gradient
    // draws none, and nothing raises a peak behind the developer's back.
    expect(BarBackingMode.blur.fadesCanvas, isFalse);
    expect(BarBackingMode.none.fadesCanvas, isFalse);
    expect(BarBackingMode.solid.fadesCanvas, isFalse);
    expect(BarBackingMode.gradient.fadesCanvas, isTrue);
    expect(BarBackingMode.blurAndGradient.fadesCanvas, isTrue);
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

    test('the slices follow the same ramp, from next to nothing', () {
      const n = ProgressiveBlurEdge.sliceCount;
      final sigmas = ProgressiveBlurEdge.sliceSigmas(9);
      for (var i = 0; i < n; i++) {
        // Slice i sits this far from the inner edge, at its middle.
        final position = 1 - (i + 0.5) / n;
        expect(sigmas[i], closeTo(9 * barBackingRamp(position), 1e-9));
      }
      expect(sigmas.last, lessThan(0.02));
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
