import 'dart:ui';

import 'package:critalarm/features/tour/presentation/tour_layout.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('steps', () {
    test(
      'covers search, making a topic, critical delivery, sound and delete',
      () {
        final anchors = tourSteps.map((s) => s.anchor).toSet();
        expect(
          anchors,
          containsAll(<TourAnchorId>[
            TourAnchorId.search,
            TourAnchorId.searchResults,
            TourAnchorId.compose,
            TourAnchorId.createName,
            TourAnchorId.topicCritical,
            TourAnchorId.topicSound,
            TourAnchorId.topicDelete,
            TourAnchorId.settingsTour,
          ]),
        );
      },
    );

    test('search is shown with a settings example and a docs example', () {
      final queries = tourSteps
          .map((s) => s.searchQuery)
          .whereType<String>()
          .toList();
      expect(queries, ['sound', 'uptime kuma']);
      // Every search step points at the results, which only exist while
      // something is typed.
      for (final step in tourSteps.where((s) => s.searchQuery != null)) {
        expect(step.anchor, TourAnchorId.searchResults);
      }
    });

    test('steps on one screen sit together, so it never bounces back', () {
      final seen = <TourPlace>{};
      TourPlace? last;
      for (final step in tourSteps) {
        if (step.place != last) {
          // Home comes back after making a topic and after the topic steps,
          // on purpose. Nothing else should repeat.
          if (step.place != TourPlace.home) {
            expect(seen, isNot(contains(step.place)), reason: '${step.anchor}');
          }
          seen.add(step.place);
          last = step.place;
        }
      }
    });

    test('ends on the row that replays it', () {
      expect(tourSteps.last.anchor, TourAnchorId.settingsTour);
    });

    test('every guide has at least one step', () {
      for (final guide in TourGuide.values) {
        expect(tourStepsFor(guide), isNotEmpty, reason: guide.name);
      }
    });

    test('a guide only points at its own screen', () {
      const places = {
        TourGuide.home: TourPlace.home,
        TourGuide.search: TourPlace.home,
        TourGuide.createTopic: TourPlace.createTopic,
        TourGuide.topic: TourPlace.topic,
        TourGuide.settings: TourPlace.settings,
      };
      for (final entry in places.entries) {
        for (final step in tourStepsFor(entry.key)) {
          expect(step.place, entry.value, reason: '${step.anchor}');
        }
      }
    });

    test('the search guide is the typed search examples', () {
      final steps = tourStepsFor(TourGuide.search);
      expect(steps.map((s) => s.searchQuery), ['sound', 'uptime kuma']);
    });

    test('the full replay is every guide, with no step left out', () {
      final perGuide = [
        for (final guide in TourGuide.values) ...tourStepsFor(guide),
      ];
      expect(perGuide.toSet(), tourSteps.toSet());
      expect(perGuide, hasLength(tourSteps.length));
      expect(tourStepsFor(null), tourSteps);
    });

    test('the example wording is used only while examples are shown', () {
      final step = tourSteps.firstWhere((s) => s.exampleBodyKey != null);
      expect(step.bodyKeyFor(usingExamples: true), step.exampleBodyKey);
      expect(step.bodyKeyFor(usingExamples: false), step.bodyKey);
    });
  });

  group('tourPath', () {
    test('maps each screen to its route', () {
      expect(tourPath(TourPlace.home, 'api'), '/');
      expect(tourPath(TourPlace.createTopic, 'api'), '/topics/new');
      expect(tourPath(TourPlace.topic, 'api'), '/topics/api');
      expect(tourPath(TourPlace.settings, 'api'), '/settings');
    });

    test('a topic name with odd characters stays one path segment', () {
      expect(tourPath(TourPlace.topic, 'a b/c'), '/topics/a%20b%2Fc');
    });
  });

  group('tourGuideForPath', () {
    test("each screen's first visit maps to its guide", () {
      expect(tourGuideForPath('/'), TourGuide.home);
      expect(tourGuideForPath('/topics/new'), TourGuide.createTopic);
      expect(tourGuideForPath('/topics/prod-db'), TourGuide.topic);
      expect(tourGuideForPath('/history/topics/prod-db'), TourGuide.topic);
      expect(tourGuideForPath('/history'), TourGuide.history);
      expect(tourGuideForPath('/settings'), TourGuide.settings);
    });

    test('screens without a guide, and deeper pages, get none', () {
      expect(tourGuideForPath('/onboarding/welcome'), isNull);
      expect(tourGuideForPath('/incidents/abc'), isNull);
      expect(tourGuideForPath('/alarm'), isNull);
      expect(tourGuideForPath('/topics/prod-db/messages'), isNull);
      expect(tourGuideForPath('/history/topics/prod-db/sounds'), isNull);
      expect(tourGuideForPath('/settings/permissions'), isNull);
      expect(tourGuideForPath(''), isNull);
    });
  });

  group('layout', () {
    const screen = Size(400, 800);

    test('the card goes on the side with more room', () {
      expect(
        tourCardGoesAbove(const Rect.fromLTWH(0, 600, 100, 50), screen),
        isTrue,
      );
      expect(
        tourCardGoesAbove(const Rect.fromLTWH(0, 100, 100, 50), screen),
        isFalse,
      );
    });

    test('a spot already on screen is not scrolled to', () {
      expect(
        tourRectOnScreen(
          const Rect.fromLTWH(0, 100, 100, 50),
          screen,
          topInset: 40,
          bottomInset: 110,
        ),
        isTrue,
      );
      // Under the tab bar.
      expect(
        tourRectOnScreen(
          const Rect.fromLTWH(0, 700, 100, 50),
          screen,
          topInset: 40,
          bottomInset: 110,
        ),
        isFalse,
      );
      // Above the top of the screen.
      expect(
        tourRectOnScreen(const Rect.fromLTWH(0, -20, 100, 50), screen),
        isFalse,
      );
    });

    test('the spotlight grows around the spot but stays on screen', () {
      final hole = tourHoleFor(const Rect.fromLTWH(2, 100, 396, 50), screen);
      expect(hole.left, 0);
      expect(hole.right, 400);
      expect(hole.top, 100 - tourHolePadding);
      expect(hole.bottom, 150 + tourHolePadding);
    });
  });
}
