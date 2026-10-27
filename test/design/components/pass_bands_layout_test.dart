import 'package:critalarm/design/components/pass_bands.dart';
import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_stack.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

PassBandsLayout layoutOf({
  double width = 390,
  double scale = 1,
  int count = 4,
  bool hasInsets = false,
}) => PassBandsLayout.of(
  width: width,
  textScale: scale,
  count: count,
  hasInsets: hasInsets,
);

void main() {
  group('PassBandsLayout overlapped', () {
    for (final scale in [1.0, 1.15, 1.29]) {
      test('four cards at text scale $scale: the geometry of the board', () {
        final layout = layoutOf(scale: scale);
        expect(layout.mode, PassStackMode.overlapped);
        expect(layout.step, 104);
        expect(layout.tops, [0, 104, 208, 312]);
        expect(layout.heights, [190, 190, 190, 124]);
        expect(layout.totalHeight, 436);
      });
    }

    for (var count = 1; count <= 4; count++) {
      test('$count cards: the last is 124 tall and the rest 190', () {
        final layout = layoutOf(count: count);
        expect(layout.tops.length, count);
        expect(layout.heights.last, kPassBandLastHeight);
        expect(layout.heights.last, 124);
        for (final height in layout.heights.take(count - 1)) {
          expect(height, kPassBandCardHeight);
        }
        expect(layout.totalHeight, 104.0 * (count - 1) + 124);
      });
    }

    test('three cards end the stack at 332', () {
      final layout = layoutOf(count: 3);
      expect(layout.tops, [0, 104, 208]);
      expect(layout.totalHeight, 332);
    });

    test('no cards is empty and has no height', () {
      final layout = layoutOf(count: 0);
      expect(layout.tops, isEmpty);
      expect(layout.heights, isEmpty);
      expect(layout.totalHeight, 0);
    });

    test('the cards fill the width, or sit 12 in when asked', () {
      final plain = layoutOf(width: 366);
      expect(plain.cardLeft, 0);
      expect(plain.cardWidth, 366);
      final inset = layoutOf(width: 366, hasInsets: true);
      expect(inset.cardLeft, kPassCardInset);
      expect(inset.cardWidth, 366 - 2 * kPassCardInset);
    });

    test('the width does not change the heights', () {
      expect(
        layoutOf(width: 320).totalHeight,
        layoutOf(width: 600).totalHeight,
      );
    });

    test('the step grows with a taller content height', () {
      final layout = PassBandsLayout.of(
        width: 390,
        textScale: 1,
        count: 3,
        contentHeight: 90,
      );
      expect(layout.step, 120);
      expect(layout.tops, [0, 120, 240]);
      expect(layout.totalHeight, 240 + 124);
    });

    test('one line of content at 1.29 still gives the least step', () {
      expect(passBandOneLineHeight(1.29) + 30, lessThan(kPassBandMinStep));
    });
  });

  group('PassBandsLayout flat', () {
    test('the mode switches at exactly 1.3', () {
      expect(layoutOf(scale: 1.299).mode, PassStackMode.overlapped);
      expect(layoutOf(scale: 1.3).mode, PassStackMode.flat);
      expect(layoutOf(scale: 1.3).isFlat, isTrue);
      expect(layoutOf(scale: 1.299).isFlat, isFalse);
    });

    for (final scale in [1.3, 2.0]) {
      test('text scale $scale lets the cards size themselves', () {
        final layout = layoutOf(scale: scale);
        expect(layout.mode, PassStackMode.flat);
        expect(layout.step, 0);
        expect(layout.tops, isEmpty);
        expect(layout.heights, isEmpty);
        expect(layout.totalHeight, 0);
      });
    }

    test('the insets apply in flat mode too', () {
      final layout = layoutOf(scale: 2, width: 366, hasInsets: true);
      expect(layout.cardLeft, kPassCardInset);
      expect(layout.cardWidth, 366 - 2 * kPassCardInset);
    });
  });

  group('passValueLinesFor', () {
    test('a card with no band draws two lines', () {
      expect(
        passValueLinesFor(band: null, textScaler: TextScaler.noScaling),
        2,
      );
    });

    test('the Personalize band always has room for two', () {
      for (final scale in [1.0, 1.15, 1.29]) {
        expect(
          passValueLinesFor(
            band: kPassMinStep,
            textScaler: TextScaler.linear(scale),
          ),
          2,
        );
      }
    });

    test('the compact band has room for two at 1.0 and one from 1.15', () {
      expect(
        passValueLinesFor(
          band: kPassBandMinStep,
          textScaler: TextScaler.noScaling,
        ),
        2,
      );
      expect(
        passValueLinesFor(
          band: kPassBandMinStep,
          textScaler: const TextScaler.linear(1.15),
        ),
        1,
      );
    });
  });

  group('passToneFor tokens', () {
    const themes = {'light': AppColors.light, 'dark': AppColors.dark};
    for (final MapEntry(key: name, value: colors) in themes.entries) {
      test('$name: cream with ink, 4.5 to 1 or more', () {
        final tone = passToneFor(PassId.tokens, colors);
        expect(tone.ground, colors.cream);
        expect(tone.onGround, colors.ink);
        expect(
          ColorContrast.contrastRatio(tone.onGround, tone.ground),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('tokens is the last pass, after the app icon', () {
      expect(PassId.values.last, PassId.tokens);
      expect(PassId.tokens.index, PassId.appIcon.index + 1);
    });
  });
}
