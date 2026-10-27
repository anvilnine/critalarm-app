import 'dart:ui';

import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/topics/presentation/pane_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DisplayFeature _halfOpen(Rect bounds) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  // The Pixel Fold inner screen with the folds the capture matrix uses.
  const window = Size(841, 701);
  final book = AppFold.fromFeatures([
    _halfOpen(Rect.fromLTWH(420, 0, 0, window.height)),
  ], window);
  final tabletop = AppFold.fromFeatures([
    _halfOpen(Rect.fromLTWH(0, 350, window.width, 0)),
  ], window);

  group('paneSelection', () {
    const topics = ['prod-db', 'nas-backup', 'web'];

    test('nothing picked opens on the first item in list order', () {
      expect(paneSelection(items: topics, picked: null), 'prod-db');
    });

    test('a picked item that is still listed stays picked', () {
      expect(paneSelection(items: topics, picked: 'web'), 'web');
    });

    test('a picked item that has gone shows the empty state', () {
      expect(paneSelection(items: topics, picked: 'deleted'), isNull);
    });

    test('an empty list has nothing to show', () {
      expect(paneSelection<String>(items: const [], picked: null), isNull);
    });

    test('the first item follows the list while nothing is picked', () {
      expect(
        paneSelection(items: const ['web', 'prod-db'], picked: null),
        'web',
      );
    });
  });

  group('heroOnFoldStage', () {
    test('no fold keeps the hero in the list', () {
      expect(heroOnFoldStage(AppFold.none, hasDetail: true), isFalse);
      expect(heroOnFoldStage(AppFold.none, hasDetail: false), isFalse);
    });

    test('tabletop always puts the hero in the top half', () {
      expect(heroOnFoldStage(tabletop, hasDetail: true), isTrue);
      expect(heroOnFoldStage(tabletop, hasDetail: false), isTrue);
    });

    test('book with a detail keeps the hero at the top of the list', () {
      expect(heroOnFoldStage(book, hasDetail: true), isFalse);
    });

    test('book with no detail puts the hero in the start pane', () {
      expect(heroOnFoldStage(book, hasDetail: false), isTrue);
    });
  });

  group('opensTopicInHomePane', () {
    test('an expanded window with no fold opens the topic in the pane', () {
      expect(
        opensTopicInHomePane(const AppSize(1440, 900), AppFold.none),
        isTrue,
      );
      expect(
        opensTopicInHomePane(const AppSize(841, 701), AppFold.none),
        isTrue,
      );
    });

    test('compact and medium open the topic screen', () {
      expect(
        opensTopicInHomePane(const AppSize(390, 844), AppFold.none),
        isFalse,
      );
      expect(
        opensTopicInHomePane(const AppSize(834, 1194), AppFold.none),
        isFalse,
      );
    });

    test('book and tabletop open the topic screen split at the fold', () {
      expect(opensTopicInHomePane(const AppSize(841, 701), book), isFalse);
      expect(opensTopicInHomePane(const AppSize(841, 701), tabletop), isFalse);
    });
  });
}
