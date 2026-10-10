import 'package:critalarm/features/onboarding/domain/welcome_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the first page', () {
    test('is still the word page on first launch', () {
      expect(welcomeFirstPage, WelcomeFirstPage.word);
    });

    test('has three pictures', () {
      expect(WelcomeFirstPage.values, [
        WelcomeFirstPage.word,
        WelcomeFirstPage.nightFalls,
        WelcomeFirstPage.staysSilent,
      ]);
    });

    test('is asked for by the first query value', () {
      expect(WelcomeFirstPage.fromQuery('night'), WelcomeFirstPage.nightFalls);
      expect(
        WelcomeFirstPage.fromQuery('silent'),
        WelcomeFirstPage.staysSilent,
      );
    });

    test('is the first launch page for no value or one it does not know', () {
      expect(WelcomeFirstPage.fromQuery(null), welcomeFirstPage);
      expect(WelcomeFirstPage.fromQuery(''), welcomeFirstPage);
      expect(WelcomeFirstPage.fromQuery('word'), welcomeFirstPage);
      expect(WelcomeFirstPage.fromQuery('3'), welcomeFirstPage);
    });

    test('changes nothing about the pages after it', () {
      expect(WelcomePage.values.length, 3);
      expect(WelcomePage.rings.next, WelcomePage.curl);
      expect(WelcomePage.curl.next, WelcomePage.widgets);
    });
  });

  group('the backdrop parting', () {
    test('is drawn in full and unmoved at rest', () {
      final parting = welcomeBackdropPartingAt(0);
      expect(parting.opacity, 1);
      expect(parting.shift, 0);
    });

    test('is half faded a quarter of the way and gone by half', () {
      expect(welcomeBackdropPartingAt(0.25).opacity, closeTo(0.5, 1e-9));
      expect(welcomeBackdropPartingAt(0.5).opacity, 0);
      expect(welcomeBackdropPartingAt(1).opacity, 0);
    });

    test('drifts right nearly as fast as the page goes left', () {
      expect(welcomeBackdropPartingAt(0.5).shift, closeTo(0.45, 1e-9));
      expect(welcomeBackdropPartingAt(1).shift, closeTo(0.9, 1e-9));
    });

    test('is gone before the screen edge can cut it', () {
      // The page moves left by its width times the slide, the backdrop is
      // shifted right by the shift. It starts 24 points in from the edge of
      // a phone at least 320 points wide, so its net travel left must stay
      // under that while it can still be seen.
      for (var slide = 0.0; slide <= 1; slide += 0.01) {
        final parting = welcomeBackdropPartingAt(slide);
        if (parting.opacity <= 0) continue;
        final netLeft = (slide - parting.shift) * 320;
        expect(netLeft, lessThan(24));
      }
    });

    test('clamps a slide outside 0 to 1', () {
      expect(welcomeBackdropPartingAt(-1).opacity, 1);
      expect(welcomeBackdropPartingAt(2).opacity, 0);
    });
  });
}
