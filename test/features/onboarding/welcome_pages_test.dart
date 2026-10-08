import 'package:critalarm/features/onboarding/domain/welcome_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pages are rings, priorities, then the curl', () {
    expect(WelcomePage.values, [
      WelcomePage.rings,
      WelcomePage.priorities,
      WelcomePage.curl,
    ]);
  });

  group('next and previous', () {
    test('walk the pages in order', () {
      expect(WelcomePage.rings.next, WelcomePage.priorities);
      expect(WelcomePage.priorities.next, WelcomePage.curl);
      expect(WelcomePage.curl.previous, WelcomePage.priorities);
      expect(WelcomePage.priorities.previous, WelcomePage.rings);
    });

    test('stop at both ends and never wrap', () {
      expect(WelcomePage.curl.next, WelcomePage.curl);
      expect(WelcomePage.rings.previous, WelcomePage.rings);
    });
  });

  group('welcomeButtonFor', () {
    test('Next on the first two pages', () {
      expect(welcomeButtonFor(WelcomePage.rings), WelcomeButton.next);
      expect(welcomeButtonFor(WelcomePage.priorities), WelcomeButton.next);
    });

    test('Get started on the last page', () {
      expect(welcomeButtonFor(WelcomePage.curl), WelcomeButton.getStarted);
    });
  });

  group('welcomePageAfterStory', () {
    test('each story hands on to the next page', () {
      expect(
        welcomePageAfterStory(WelcomePage.rings, userHasMoved: false),
        WelcomePage.priorities,
      );
      expect(
        welcomePageAfterStory(WelcomePage.priorities, userHasMoved: false),
        WelcomePage.curl,
      );
    });

    test('the last page stays and never goes back to the first', () {
      expect(
        welcomePageAfterStory(WelcomePage.curl, userHasMoved: false),
        WelcomePage.curl,
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
            restingOn: WelcomePage.priorities,
            isMoving: false,
          ),
          page == WelcomePage.priorities,
        );
      }
    });

    test('no page while the pager moves', () {
      for (final page in WelcomePage.values) {
        expect(
          welcomePageIsInFront(
            page,
            restingOn: WelcomePage.priorities,
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
        WelcomePage.priorities,
      );
    });

    test('a swipe to the right opens the page before', () {
      expect(
        welcomePageAfterSwipe(WelcomePage.curl, moved: 60),
        WelcomePage.priorities,
      );
    });

    test('a swipe shorter than the least distance changes nothing', () {
      expect(
        welcomePageAfterSwipe(
          WelcomePage.priorities,
          moved: -(welcomeSwipeMinDistance - 1),
        ),
        WelcomePage.priorities,
      );
      expect(
        welcomePageAfterSwipe(
          WelcomePage.priorities,
          moved: welcomeSwipeMinDistance - 1,
        ),
        WelcomePage.priorities,
      );
    });

    test('a swipe past either end changes nothing', () {
      expect(
        welcomePageAfterSwipe(WelcomePage.rings, moved: 200),
        WelcomePage.rings,
      );
      expect(
        welcomePageAfterSwipe(WelcomePage.curl, moved: -200),
        WelcomePage.curl,
      );
    });
  });
}
