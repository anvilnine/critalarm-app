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
