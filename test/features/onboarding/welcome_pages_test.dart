import 'package:critalarm/features/onboarding/domain/welcome_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pages are rings, the curl, then the widgets', () {
    expect(WelcomePage.values, [
      WelcomePage.rings,
      WelcomePage.curl,
      WelcomePage.widgets,
    ]);
  });

  group('next and previous', () {
    test('walk the pages in order', () {
      expect(WelcomePage.rings.next, WelcomePage.curl);
      expect(WelcomePage.curl.next, WelcomePage.widgets);
      expect(WelcomePage.widgets.previous, WelcomePage.curl);
      expect(WelcomePage.curl.previous, WelcomePage.rings);
    });

    test('stop at both ends and never wrap', () {
      expect(WelcomePage.widgets.next, WelcomePage.widgets);
      expect(WelcomePage.rings.previous, WelcomePage.rings);
    });
  });

  group('welcomeButtonFor', () {
    test('Next on the first two pages', () {
      expect(welcomeButtonFor(WelcomePage.rings), WelcomeButton.next);
      expect(welcomeButtonFor(WelcomePage.curl), WelcomeButton.next);
    });

    test('Get started on the last page', () {
      expect(welcomeButtonFor(WelcomePage.widgets), WelcomeButton.getStarted);
    });
  });

  group('welcomePageAfterStory', () {
    test('the story of the first page hands on to the curl', () {
      expect(
        welcomePageAfterStory(WelcomePage.rings, userHasMoved: false),
        WelcomePage.curl,
      );
    });

    test('the last page stays and never goes back to the first', () {
      expect(
        welcomePageAfterStory(WelcomePage.widgets, userHasMoved: false),
        WelcomePage.widgets,
      );
    });

    test('once the user has moved, every page plays again in place', () {
      for (final page in WelcomePage.values) {
        expect(welcomePageAfterStory(page, userHasMoved: true), page);
      }
    });
  });

  group('welcomePageIsInFront', () {
    test('only the page the pager rests on', () {
      for (final page in WelcomePage.values) {
        expect(
          welcomePageIsInFront(
            page,
            restingOn: WelcomePage.curl,
            isMoving: false,
          ),
          page == WelcomePage.curl,
        );
      }
    });

    test('no page while the pager moves', () {
      for (final page in WelcomePage.values) {
        expect(
          welcomePageIsInFront(
            page,
            restingOn: WelcomePage.curl,
            isMoving: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('welcomePageAfterSwipe', () {
    test('a swipe to the left opens the next page', () {
      expect(
        welcomePageAfterSwipe(WelcomePage.rings, moved: -60),
        WelcomePage.curl,
      );
    });

    test('a swipe to the right opens the page before', () {
      expect(
        welcomePageAfterSwipe(WelcomePage.widgets, moved: 60),
        WelcomePage.curl,
      );
    });

    test('a swipe shorter than the least distance changes nothing', () {
      expect(
        welcomePageAfterSwipe(
          WelcomePage.curl,
          moved: -(welcomeSwipeMinDistance - 1),
        ),
        WelcomePage.curl,
      );
      expect(
        welcomePageAfterSwipe(
          WelcomePage.curl,
          moved: welcomeSwipeMinDistance - 1,
        ),
        WelcomePage.curl,
      );
    });

    test('a swipe past either end changes nothing', () {
      expect(
        welcomePageAfterSwipe(WelcomePage.rings, moved: 200),
        WelcomePage.rings,
      );
      expect(
        welcomePageAfterSwipe(WelcomePage.widgets, moved: -200),
        WelcomePage.widgets,
      );
    });
  });

  group('welcomeFirstPageSlide', () {
    test('is the page value between the first and second page', () {
      expect(welcomeFirstPageSlide(0), 0);
      expect(welcomeFirstPageSlide(0.25), 0.25);
      expect(welcomeFirstPageSlide(1), 1);
    });

    test('stays at 1 from the second page on and at 0 before the first', () {
      expect(welcomeFirstPageSlide(1.6), 1);
      expect(welcomeFirstPageSlide(2), 1);
      expect(welcomeFirstPageSlide(-0.2), 0);
    });
  });

  group('welcomeWordPartingAt', () {
    test('at rest everything is drawn where it is', () {
      final p = welcomeWordPartingAt(0);
      expect(p.faceOpacity, 1);
      expect(p.titleOpacity, 1);
      expect(p.faceShift, 0);
      expect(p.titleShift, 0);
    });

    test('the face and the title are gone before the page is half away', () {
      final p = welcomeWordPartingAt(0.5);
      expect(p.faceOpacity, 0);
      expect(p.titleOpacity, 0);
    });

    test('fades out evenly and never comes back', () {
      var face = 1.0;
      var title = 1.0;
      for (var i = 1; i <= 20; i++) {
        final p = welcomeWordPartingAt(i / 20);
        expect(p.faceOpacity, lessThanOrEqualTo(face));
        expect(p.titleOpacity, lessThanOrEqualTo(title));
        face = p.faceOpacity;
        title = p.titleOpacity;
      }
    });

    test('the face ends up to the right of the page edge it started at', () {
      // The page goes left by one width at slide 1. The net travel of a part
      // on screen is its shift minus the slide, in page widths.
      for (final slide in [0.25, 0.5, 0.75, 1.0]) {
        final p = welcomeWordPartingAt(slide);
        expect(p.faceShift - slide, greaterThan(0), reason: 'at $slide');
      }
    });

    test('the title drifts left by less than the side padding at first', () {
      // 390 point page, 20 point padding: the title may travel left by
      // about 5 percent of a page before it would touch the screen edge.
      final p = welcomeWordPartingAt(0.25);
      expect(0.25 - p.titleShift, lessThan(0.06));
      expect(p.titleShift, lessThan(0.25));
    });
  });
}
