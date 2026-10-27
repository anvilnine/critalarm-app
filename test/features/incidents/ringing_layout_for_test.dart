import 'dart:ui';

import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/incidents/domain/ringing_layout_rules.dart';
import 'package:critalarm/features/incidents/presentation/widgets/ringing_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules that pick the ringing screen's layout and size its face on
/// tablets, foldables, covers and desktops. Plain values, no widgets.
void main() {
  group('ringingLayoutFor', () {
    RingingLayout on(double w, double h, [AppPosture p = AppPosture.none]) =>
        ringingLayoutFor(AppSize(w, h), p);

    test('an upright phone and a tablet in portrait keep the one column', () {
      expect(on(390, 844), RingingLayout.tall);
      expect(on(344, 882), RingingLayout.tall);
      expect(on(834, 1194), RingingLayout.tall);
      expect(on(690, 829), RingingLayout.tall);
    });

    test('a phone on its side keeps the face beside the words', () {
      expect(on(844, 390), RingingLayout.sideways);
    });

    test('the Razr cover gets its own layout', () {
      expect(on(384, 388), RingingLayout.cover);
    });

    test('a wide window gets the two columns', () {
      expect(on(1194, 834), RingingLayout.expanded);
      expect(on(1440, 900), RingingLayout.expanded);
      expect(on(1920, 1080), RingingLayout.expanded);
      expect(on(841, 701), RingingLayout.expanded);
    });

    test('a fold wins over the size class', () {
      expect(on(690, 829, AppPosture.book), RingingLayout.book);
      expect(on(841, 701, AppPosture.book), RingingLayout.book);
      // Expanded, but a 350 half is too short for the two columns.
      expect(on(841, 701, AppPosture.tabletop), RingingLayout.tabletop);
    });
  });

  group('ringingExpandedFaceSizeFor', () {
    test('is 300 on a tall window and 240 under 800 tall', () {
      expect(ringingExpandedFaceSizeFor(windowHeight: 834), 300);
      expect(ringingExpandedFaceSizeFor(windowHeight: 1080), 300);
      expect(ringingExpandedFaceSizeFor(windowHeight: 800), 300);
      expect(ringingExpandedFaceSizeFor(windowHeight: 799), 240);
      expect(ringingExpandedFaceSizeFor(windowHeight: 701), 240);
    });

    test('a look may cap it', () {
      expect(ringingExpandedFaceSizeFor(windowHeight: 900, maxFace: 180), 180);
    });
  });

  group('ringingPaneFaceSizeFor', () {
    final header = ringingHeaderHeightFor(textScale: 1, openAlarms: 1);

    test('a wide start pane gets the largest ringing face', () {
      expect(
        ringingPaneFaceSizeFor(
          paneWidth: 404,
          paneHeight: 701,
          headerHeight: header,
        ),
        ringingFaceMax,
      );
    });

    test('a narrow pane keeps the pulse ring 24 in from each side', () {
      final face = ringingPaneFaceSizeFor(
        paneWidth: 329,
        paneHeight: 829,
        headerHeight: header,
      );
      expect(face, closeTo((329 - 48) / ringingPulseRingScale, 0.001));
      expect(face * ringingPulseRingScale, lessThanOrEqualTo(329 - 48));
    });

    test('a short pane takes the face down, and below the floor it goes', () {
      final short = ringingPaneFaceSizeFor(
        paneWidth: 404,
        paneHeight: 300,
        headerHeight: header,
      );
      expect(short, 300 - 48 - header - ringingFaceGap);
      expect(
        ringingPaneFaceSizeFor(
          paneWidth: 404,
          paneHeight: 200,
          headerHeight: header,
        ),
        0,
      );
    });

    test('a look may cap it', () {
      expect(
        ringingPaneFaceSizeFor(
          paneWidth: 329,
          paneHeight: 829,
          headerHeight: header,
          maxFace: 120,
        ),
        120,
      );
    });
  });

  group('ringingBookFaceSizeFor', () {
    AppFold bookAt(double x, Size window) => AppFold.fromFeatures([
      DisplayFeature(
        bounds: Rect.fromLTWH(x, 0, 0, window.height),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ], window);

    test('the Galaxy Fold start pane, 329 wide, keeps the ring in it', () {
      const window = Size(690, 829);
      expect(
        ringingBookFaceSizeFor(
          window: const MediaQueryData(size: window),
          fold: bookAt(345, window),
          openAlarms: 1,
        ),
        closeTo((329 - 48) / ringingPulseRingScale, 0.001),
      );
    });

    test('is 0 in a start pane too short for the face, so drawsFace is '
        'false there', () {
      const window = Size(690, 300);
      expect(
        ringingBookFaceSizeFor(
          window: const MediaQueryData(
            size: window,
            textScaler: TextScaler.linear(2),
          ),
          fold: bookAt(345, window),
          openAlarms: 1,
        ),
        0,
      );
    });

    test('is 0 with no book fold', () {
      expect(
        ringingBookFaceSizeFor(
          window: const MediaQueryData(size: Size(690, 829)),
          fold: AppFold.none,
          openAlarms: 1,
        ),
        0,
      );
    });
  });

  group('ringingBookLiftFor', () {
    test('splits the room the card leaves above and below the group', () {
      // Galaxy Fold end pane 829 tall, a three-line card of 160 at the
      // default text size: 829 - 172 (bar) - 16 - 16 = 625 of room.
      expect(
        ringingBookLiftFor(paneHeight: 829, textScale: 1, cardHeight: 160),
        (625 - 160) / 2,
      );
    });

    test('a setup test has one button less to clear', () {
      expect(
        ringingBookLiftFor(
          paneHeight: 829,
          textScale: 1,
          cardHeight: 160,
          pinnedButtons: 2,
        ),
        (829 - 116 - 16 - 16 - 160) / 2,
      );
    });

    test('is 0 once the card fills the room, so the buttons stay at the '
        'foot', () {
      expect(
        ringingBookLiftFor(paneHeight: 600, textScale: 2, cardHeight: 500),
        0,
      );
    });
  });
}
