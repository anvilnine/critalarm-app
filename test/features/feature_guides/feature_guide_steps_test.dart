import 'dart:ui';

import 'package:critalarm/features/feature_guides/presentation/feature_guide_layout.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('steps', () {
    test(
      'covers search, making a topic, critical delivery, sound and delete',
      () {
        final anchors = featureGuideSteps.map((s) => s.anchor).toSet();
        expect(
          anchors,
          containsAll(<FeatureGuideAnchorId>[
            FeatureGuideAnchorId.search,
            FeatureGuideAnchorId.searchResults,
            FeatureGuideAnchorId.compose,
            FeatureGuideAnchorId.createName,
            FeatureGuideAnchorId.topicCritical,
            FeatureGuideAnchorId.topicSound,
            FeatureGuideAnchorId.topicDelete,
            FeatureGuideAnchorId.settingsFeatureGuides,
          ]),
        );
      },
    );

    test('search is shown with a settings example and a docs example', () {
      final queries = featureGuideSteps
          .map((s) => s.searchQuery)
          .whereType<String>()
          .toList();
      expect(queries, ['sound', 'uptime kuma']);
      // Every search step points at the results, which only exist while
      // something is typed.
      for (final step in featureGuideSteps.where(
        (s) => s.searchQuery != null,
      )) {
        expect(step.anchor, FeatureGuideAnchorId.searchResults);
      }
    });

    test('steps on one screen sit together, so it never bounces back', () {
      final seen = <FeatureGuidePlace>{};
      FeatureGuidePlace? last;
      for (final step in featureGuideSteps) {
        if (step.place != last) {
          // Home comes back after making a topic and after the topic steps,
          // on purpose. Nothing else should repeat.
          if (step.place != FeatureGuidePlace.home) {
            expect(seen, isNot(contains(step.place)), reason: '${step.anchor}');
          }
          seen.add(step.place);
          last = step.place;
        }
      }
    });

    test('ends on the row that replays it', () {
      expect(
        featureGuideSteps.last.anchor,
        FeatureGuideAnchorId.settingsFeatureGuides,
      );
    });

    test('every guide has at least one step', () {
      for (final guide in FeatureGuide.values) {
        expect(featureGuideStepsFor(guide), isNotEmpty, reason: guide.name);
      }
    });

    test('a guide only points at its own screen', () {
      const places = {
        FeatureGuide.home: FeatureGuidePlace.home,
        FeatureGuide.search: FeatureGuidePlace.home,
        FeatureGuide.createTopic: FeatureGuidePlace.createTopic,
        FeatureGuide.topic: FeatureGuidePlace.topic,
        FeatureGuide.settings: FeatureGuidePlace.settings,
      };
      for (final entry in places.entries) {
        for (final step in featureGuideStepsFor(entry.key)) {
          expect(step.place, entry.value, reason: '${step.anchor}');
        }
      }
    });

    test('the search guide is the typed search examples', () {
      final steps = featureGuideStepsFor(FeatureGuide.search);
      expect(steps.map((s) => s.searchQuery), ['sound', 'uptime kuma']);
    });

    test('the full replay is every guide, with no step left out', () {
      final perGuide = [
        for (final guide in FeatureGuide.values) ...featureGuideStepsFor(guide),
      ];
      expect(perGuide.toSet(), featureGuideSteps.toSet());
      expect(perGuide, hasLength(featureGuideSteps.length));
      expect(featureGuideStepsFor(null), featureGuideSteps);
    });

    test('the example wording is used only while examples are shown', () {
      final step = featureGuideSteps.firstWhere(
        (s) => s.exampleBodyKey != null,
      );
      expect(step.bodyKeyFor(usingExamples: true), step.exampleBodyKey);
      expect(step.bodyKeyFor(usingExamples: false), step.bodyKey);
    });
  });

  group('featureGuidePath', () {
    test('maps each screen to its route', () {
      expect(featureGuidePath(FeatureGuidePlace.home, 'api'), '/');
      expect(
        featureGuidePath(FeatureGuidePlace.createTopic, 'api'),
        '/topics/new',
      );
      expect(featureGuidePath(FeatureGuidePlace.topic, 'api'), '/topics/api');
      expect(featureGuidePath(FeatureGuidePlace.settings, 'api'), '/settings');
    });

    test('a topic name with odd characters stays one path segment', () {
      expect(
        featureGuidePath(FeatureGuidePlace.topic, 'a b/c'),
        '/topics/a%20b%2Fc',
      );
    });
  });

  group('featureGuideForPath', () {
    test("each screen's first visit maps to its guide", () {
      expect(featureGuideForPath('/'), FeatureGuide.home);
      expect(featureGuideForPath('/topics/new'), FeatureGuide.createTopic);
      expect(featureGuideForPath('/topics/prod-db'), FeatureGuide.topic);
      expect(
        featureGuideForPath('/history/topics/prod-db'),
        FeatureGuide.topic,
      );
      expect(featureGuideForPath('/history'), FeatureGuide.history);
      expect(featureGuideForPath('/settings'), FeatureGuide.settings);
    });

    test('screens without a guide, and deeper pages, get none', () {
      expect(featureGuideForPath('/onboarding/welcome'), isNull);
      expect(featureGuideForPath('/incidents/abc'), isNull);
      expect(featureGuideForPath('/alarm'), isNull);
      expect(featureGuideForPath('/topics/prod-db/messages'), isNull);
      expect(featureGuideForPath('/history/topics/prod-db/sounds'), isNull);
      expect(featureGuideForPath('/settings/permissions'), isNull);
      expect(featureGuideForPath(''), isNull);
    });
  });

  group('layout', () {
    const screen = Size(400, 800);

    test('the card goes on the side with more room', () {
      expect(
        featureGuideCardGoesAbove(const Rect.fromLTWH(0, 600, 100, 50), screen),
        isTrue,
      );
      expect(
        featureGuideCardGoesAbove(const Rect.fromLTWH(0, 100, 100, 50), screen),
        isFalse,
      );
    });

    test('a spot already on screen is not scrolled to', () {
      expect(
        featureGuideRectOnScreen(
          const Rect.fromLTWH(0, 100, 100, 50),
          screen,
          topInset: 40,
          bottomInset: 110,
        ),
        isTrue,
      );
      // Under the tab bar.
      expect(
        featureGuideRectOnScreen(
          const Rect.fromLTWH(0, 700, 100, 50),
          screen,
          topInset: 40,
          bottomInset: 110,
        ),
        isFalse,
      );
      // Above the top of the screen.
      expect(
        featureGuideRectOnScreen(const Rect.fromLTWH(0, -20, 100, 50), screen),
        isFalse,
      );
    });

    test('the spotlight grows around the spot but stays on screen', () {
      final hole = featureGuideHoleFor(
        const Rect.fromLTWH(2, 100, 396, 50),
        screen,
      );
      expect(hole.left, 0);
      expect(hole.right, 400);
      expect(hole.top, 100 - featureGuideHolePadding);
      expect(hole.bottom, 150 + featureGuideHolePadding);
    });
  });
}
