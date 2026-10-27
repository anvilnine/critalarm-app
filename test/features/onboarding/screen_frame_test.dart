import 'dart:ui';

import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/screen_frame.dart';
import 'package:flutter_test/flutter_test.dart';

AppFold _halfOpen(Rect line, Size window) => AppFold.fromFeatures([
  DisplayFeature(
    bounds: line,
    type: DisplayFeatureType.fold,
    state: DisplayFeatureState.postureHalfOpened,
  ),
], window);

void main() {
  group('screenFrameFor', () {
    ScreenFrame frame(double w, double h, {AppFold fold = AppFold.none}) =>
        screenFrameFor(AppSize(w, h), fold);

    test('phones keep the phone column', () {
      expect(frame(390, 844), ScreenFrame.phone);
      expect(frame(344, 882), ScreenFrame.phone);
      expect(frame(411, 797), ScreenFrame.phone);
    });

    test('a phone on its side is too short for the centred group', () {
      expect(frame(844, 390), ScreenFrame.phone);
    });

    test('the Razr cover is a cover', () {
      expect(frame(384, 388), ScreenFrame.cover);
    });

    test('tablets and desktop windows centre the group', () {
      expect(frame(834, 1194), ScreenFrame.centred);
      expect(frame(744, 1133), ScreenFrame.centred);
      expect(frame(1440, 900), ScreenFrame.centred);
      expect(frame(1920, 1080), ScreenFrame.centred);
      // The Galaxy Fold opened flat, both ways round.
      expect(frame(690, 829), ScreenFrame.centred);
      expect(frame(829, 690), ScreenFrame.centred);
    });

    test('a half-open fold wins over the size class', () {
      const book = Size(690, 829);
      const pixel = Size(841, 701);
      expect(
        frame(
          690,
          829,
          fold: _halfOpen(Rect.fromLTWH(345, 0, 0, book.height), book),
        ),
        ScreenFrame.book,
      );
      expect(
        frame(
          841,
          701,
          fold: _halfOpen(Rect.fromLTWH(420, 0, 0, pixel.height), pixel),
        ),
        ScreenFrame.book,
      );
      // Expanded, but its halves are 350 tall.
      expect(
        frame(
          841,
          701,
          fold: _halfOpen(Rect.fromLTWH(0, 350, pixel.width, 0), pixel),
        ),
        ScreenFrame.tabletop,
      );
    });

    test('only the fold frames split', () {
      expect(ScreenFrame.book.splitsAtFold, isTrue);
      expect(ScreenFrame.tabletop.splitsAtFold, isTrue);
      expect(ScreenFrame.phone.splitsAtFold, isFalse);
      expect(ScreenFrame.cover.splitsAtFold, isFalse);
      expect(ScreenFrame.centred.splitsAtFold, isFalse);
    });
  });

  group('actionsInlineFor', () {
    test(
      'the centred group and a book pane put the buttons under the words',
      () {
        expect(actionsInlineFor(ScreenFrame.centred, hasKeyboard: false), true);
        expect(actionsInlineFor(ScreenFrame.book, hasKeyboard: false), true);
      },
    );

    test('a phone, a cover and a tabletop half pin them', () {
      for (final frame in [
        ScreenFrame.phone,
        ScreenFrame.cover,
        ScreenFrame.tabletop,
      ]) {
        expect(actionsInlineFor(frame, hasKeyboard: false), isFalse);
      }
    });

    test('the keyboard pins them above it', () {
      expect(actionsInlineFor(ScreenFrame.centred, hasKeyboard: true), false);
      expect(actionsInlineFor(ScreenFrame.book, hasKeyboard: true), false);
    });

    test('a group taller than the view pins them, so they stay on screen', () {
      expect(
        actionsInlineFor(
          ScreenFrame.centred,
          hasKeyboard: false,
          fits: false,
        ),
        isFalse,
      );
    });
  });

  group('groupFits', () {
    test('form, gap and buttons inside the room fit', () {
      expect(
        groupFits(group: 600, actions: 48, gap: 8, available: 656),
        isTrue,
      );
    });

    test('a pixel over does not', () {
      expect(
        groupFits(group: 600, actions: 48, gap: 8, available: 655),
        isFalse,
      );
    });

    test('Galaxy Fold inner landscape fits the New topic form', () {
      // 690 tall, 58 of top bar, 16 at the foot: the form measured 532.
      final room = centredGroupMinHeight(viewport: 690, above: 58, below: 16);
      expect(room, 616);
      expect(groupFits(group: 532, actions: 48, gap: 8, available: room), true);
    });
  });

  group('centredGroupMinHeight', () {
    test('is the view less the room above and below', () {
      expect(centredGroupMinHeight(viewport: 900, above: 58, below: 16), 826);
    });

    test('never goes below zero', () {
      expect(centredGroupMinHeight(viewport: 50, above: 58, below: 16), 0);
    });
  });
}
