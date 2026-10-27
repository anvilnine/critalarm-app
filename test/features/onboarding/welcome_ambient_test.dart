import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/model/welcome_ambient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final colors in [AppColors.light, AppColors.dark]) {
    final pages = OnboardingAmbientProfiles.welcomePages(colors);

    group(
      'welcome ambient (${colors == AppColors.light ? 'light' : 'dark'})',
      () {
        test('has one arrangement for each of the three pages', () {
          expect(pages, hasLength(3));
          for (final page in pages) {
            expect(page.shapes, hasLength(pages.first.shapes.length));
          }
        });

        test('the step profile of the welcome is the first page', () {
          expect(
            OnboardingAmbientProfiles.forColors(
              colors,
            )[OnboardingAmbientStep.welcome],
            pages.first,
          );
        });

        test('every page puts every shape in a different place', () {
          for (var a = 0; a < pages.length; a++) {
            for (var b = a + 1; b < pages.length; b++) {
              for (var i = 0; i < pages[a].shapes.length; i++) {
                final from = pages[a].shapes[i].anchor;
                final to = pages[b].shapes[i].anchor;
                final apart = (from.x - to.x).abs() + (from.y - to.y).abs();
                expect(apart, greaterThan(0.5), reason: 'shape $i, $a to $b');
              }
            }
          }
        });

        test('the canvas colour is the same on every page', () {
          expect(pages[1].canvas, pages[0].canvas);
          expect(pages[2].canvas, pages[0].canvas);
        });

        test('a whole page value is that page, exactly', () {
          for (var i = 0; i < pages.length; i++) {
            expect(welcomeAmbientAt(pages, i.toDouble()), pages[i]);
          }
        });

        test('a value outside the pages holds the nearest end', () {
          expect(welcomeAmbientAt(pages, -0.4), pages.first);
          expect(welcomeAmbientAt(pages, 2.7), pages.last);
        });

        test('between two pages the shapes are between their places', () {
          for (var from = 0; from < 2; from++) {
            for (final between in [0.25, 0.5, 0.75]) {
              final profile = welcomeAmbientAt(pages, from + between);
              for (var i = 0; i < profile.shapes.length; i++) {
                final a = pages[from].shapes[i].anchor;
                final b = pages[from + 1].shapes[i].anchor;
                final at = profile.shapes[i].anchor;
                expect(
                  at.x,
                  inInclusiveRange(
                    a.x < b.x ? a.x : b.x,
                    a.x < b.x ? b.x : a.x,
                  ),
                );
                expect(at, isNot(a), reason: 'moved off page $from');
                expect(at, isNot(b), reason: 'not yet on page ${from + 1}');
              }
            }
          }
        });

        test('a shape only ever moves on towards the next page', () {
          for (var i = 0; i < pages.first.shapes.length; i++) {
            var last = pages[0].shapes[i].anchor;
            final goal = pages[1].shapes[i].anchor;
            var lastLeft = (last.x - goal.x).abs() + (last.y - goal.y).abs();
            for (var step = 1; step <= 40; step++) {
              final at = welcomeAmbientAt(pages, step / 40).shapes[i].anchor;
              final left = (at.x - goal.x).abs() + (at.y - goal.y).abs();
              expect(left, lessThanOrEqualTo(lastLeft + 1e-9));
              last = at;
              lastLeft = left;
            }
            expect(last, goal);
          }
        });

        test('the glide back is the same path as the glide forward', () {
          final forward = welcomeAmbientAt(pages, 0.4);
          expect(welcomeAmbientAt(pages, 0.4), forward);
        });
      },
    );
  }

  group('welcomeShapeProgress', () {
    test('starts at 0 and ends at 1 for every depth', () {
      for (final depth in [0.0, 0.35, 0.65, 0.85, 1.0]) {
        expect(welcomeShapeProgress(0, depth), 0);
        expect(welcomeShapeProgress(1, depth), 1);
      }
    });

    test('never goes back and stays inside 0 to 1', () {
      for (final depth in [0.0, 0.35, 0.65, 0.85, 1.0]) {
        var last = 0.0;
        for (var i = 1; i <= 50; i++) {
          final p = welcomeShapeProgress(i / 50, depth);
          expect(p, inInclusiveRange(0, 1));
          expect(p, greaterThanOrEqualTo(last));
          last = p;
        }
      }
    });

    test('a shape far back runs ahead of one near the front', () {
      expect(
        welcomeShapeProgress(0.5, 0.85),
        greaterThan(welcomeShapeProgress(0.5, 0.35)),
      );
    });
  });
}
