import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the three classes are 56, 120 and 200 points', () {
    expect(PaywallPreviewClass.small.edge, 56);
    expect(PaywallPreviewClass.medium.edge, 120);
    expect(PaywallPreviewClass.large.edge, 200);
  });

  group('the class a box gets', () {
    test('under 88 points it is always the glyph tile', () {
      for (final edge in const [38.0, 44.0, 56.0, 72.0, 87.9]) {
        expect(
          paywallPreviewClassFor(Size.square(edge)),
          PaywallPreviewClass.small,
          reason: '$edge',
        );
      }
      // The short side decides: a wide strip is still small.
      expect(
        paywallPreviewClassFor(const Size(300, 60)),
        PaywallPreviewClass.small,
      );
    });

    test('then medium, and large from 160 points', () {
      expect(
        paywallPreviewClassFor(const Size.square(88)),
        PaywallPreviewClass.medium,
      );
      expect(
        paywallPreviewClassFor(const Size.square(159)),
        PaywallPreviewClass.medium,
      );
      expect(
        paywallPreviewClassFor(const Size.square(160)),
        PaywallPreviewClass.large,
      );
      expect(
        paywallPreviewClassFor(const Size(390, 464)),
        PaywallPreviewClass.large,
      );
    });
  });

  group('the fit', () {
    test('with nothing given it is the small tile at 56', () {
      final fit = paywallPreviewFit();
      expect(fit.sizeClass, PaywallPreviewClass.small);
      expect(fit.box, const Size.square(56));
      expect(fit.drawn, const Size.square(56));
    });

    test('a class alone takes its own size', () {
      for (final sizeClass in PaywallPreviewClass.values) {
        final fit = paywallPreviewFit(sizeClass: sizeClass);
        expect(fit.box, Size.square(sizeClass.edge));
        expect(fit.drawn, Size.square(sizeClass.edge));
      }
    });

    test('a size alone maps to a class and keeps its room', () {
      final small = paywallPreviewFit(box: const Size.square(38));
      expect(small.sizeClass, PaywallPreviewClass.small);
      expect(small.drawn, const Size.square(38));

      final medium = paywallPreviewFit(box: const Size.square(120));
      expect(medium.sizeClass, PaywallPreviewClass.medium);
      expect(medium.drawn, const Size.square(120));

      final old = paywallPreviewFit(box: const Size.square(240));
      expect(old.sizeClass, PaywallPreviewClass.large);
      expect(old.box, const Size.square(240));
      expect(old.drawn, const Size.square(200));
    });

    test('a preview never grows past its class', () {
      for (final sizeClass in PaywallPreviewClass.values) {
        for (final box in const [
          Size.square(240),
          Size(390, 464),
          Size(335, 200),
          Size(180, 600),
        ]) {
          final fit = paywallPreviewFit(sizeClass: sizeClass, box: box);
          expect(fit.sizeClass, sizeClass);
          expect(fit.box, box);
          expect(fit.drawn.longestSide, lessThanOrEqualTo(sizeClass.edge));
        }
      }
    });

    test('a box too small for the class asked for gets a smaller one', () {
      final fit = paywallPreviewFit(
        sizeClass: PaywallPreviewClass.large,
        box: const Size.square(56),
      );
      expect(fit.sizeClass, PaywallPreviewClass.small);
      expect(fit.drawn, const Size.square(56));

      final medium = paywallPreviewFit(
        sizeClass: PaywallPreviewClass.large,
        box: const Size(300, 110),
      );
      expect(medium.sizeClass, PaywallPreviewClass.medium);
      expect(medium.drawn, const Size(120, 110));
    });

    test('the drawing always fits the room', () {
      for (final sizeClass in [null, ...PaywallPreviewClass.values]) {
        for (final box in const [
          Size.square(38),
          Size(300, 60),
          Size(100, 140),
          Size(350, 110),
          Size(170, 230),
        ]) {
          final fit = paywallPreviewFit(sizeClass: sizeClass, box: box);
          expect(fit.drawn.width, lessThanOrEqualTo(box.width));
          expect(fit.drawn.height, lessThanOrEqualTo(box.height));
        }
      }
    });

    test('the small tile is a square, whatever the room', () {
      final fit = paywallPreviewFit(box: const Size(300, 44));
      expect(fit.drawn, const Size.square(44));
    });
  });

  group('the glyph tile', () {
    test('is one size and one corner from 44 to 56 points', () {
      expect(previewGlyphTileEdge(56), 56);
      expect(previewGlyphTileEdge(72), 56);
      expect(previewGlyphTileEdge(44), 44);
      expect(previewGlyphTileRadius(56), previewGlyphTileRadius(48));
      expect(previewGlyphTileRadius(38), lessThan(previewGlyphTileRadius(56)));
    });

    test('the mark is the same share of every tile', () {
      for (final edge in const [38.0, 44.0, 56.0]) {
        expect(previewGlyphSize(edge) / edge, closeTo(0.5, 1e-9));
      }
    });
  });
}
