import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_photo_crop_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A frame the shape of a phone, 200 by 400 on screen.
  const frame = Size(200, 400);

  group('the photo covers the frame:', () {
    test('a wide photo is as tall as the frame and runs past its sides', () {
      final cover = coverSizeFor(picture: const Size(4000, 3000), frame: frame);
      expect(cover.height, 400);
      expect(cover.width, closeTo(533.33, 0.01));
    });

    test('a tall photo is as wide as the frame and runs past its ends', () {
      final cover = coverSizeFor(picture: const Size(1000, 4000), frame: frame);
      expect(cover.width, 200);
      expect(cover.height, 800);
    });

    test('a photo the shape of the frame fits it exactly', () {
      expect(
        coverSizeFor(picture: const Size(1170, 2340), frame: frame),
        frame,
      );
    });
  });

  group('the part that is kept:', () {
    final wide = coverSizeFor(picture: const Size(4000, 3000), frame: frame);

    test('centred and zoomed out, it is the middle of the photo, full '
        'height', () {
      final crop = cropShownIn(
        frame: frame,
        coverSize: wide,
        scale: 1,
        offset: Offset(-(wide.width - frame.width) / 2, 0),
      );
      expect(crop.top, 0);
      expect(crop.bottom, 1);
      expect(crop.left, closeTo(0.3125, 1e-9));
      expect(crop.right, closeTo(0.6875, 1e-9));
      expect(crop.isSane, isTrue);
      // The kept part has the shape of the frame.
      expect(
        (crop.width * 4000) / (crop.height * 3000),
        closeTo(frame.width / frame.height, 1e-9),
      );
    });

    test('dragged to the left edge, it starts at the edge', () {
      final crop = cropShownIn(
        frame: frame,
        coverSize: wide,
        scale: 1,
        offset: Offset.zero,
      );
      expect(crop.left, 0);
      expect(crop.right, closeTo(0.375, 1e-9));
    });

    test('zoomed in twice, it is half as wide and half as tall', () {
      final crop = cropShownIn(
        frame: frame,
        coverSize: wide,
        scale: 2,
        offset: const Offset(-300, -200),
      );
      expect(crop.left, closeTo(150 / wide.width, 1e-9));
      expect(crop.width, closeTo(100 / wide.width, 1e-9));
      expect(crop.top, closeTo(0.25, 1e-9));
      expect(crop.height, closeTo(0.5, 1e-9));
      expect(
        (crop.width * 4000) / (crop.height * 3000),
        closeTo(frame.width / frame.height, 1e-9),
      );
    });

    test('it never reaches outside the photo, whatever the view says', () {
      final crop = cropShownIn(
        frame: frame,
        coverSize: wide,
        scale: 1,
        offset: const Offset(50, 30),
      );
      expect(crop.left, 0);
      expect(crop.top, 0);
      expect(crop.right, lessThanOrEqualTo(1));
      expect(crop.bottom, lessThanOrEqualTo(1));
    });

    test('with nothing laid out yet, it is the whole photo', () {
      expect(
        cropShownIn(
          frame: Size.zero,
          coverSize: wide,
          scale: 1,
          offset: Offset.zero,
        ),
        OwnPhotoCrop.whole,
      );
      expect(
        cropShownIn(
          frame: frame,
          coverSize: wide,
          scale: 0,
          offset: Offset.zero,
        ),
        OwnPhotoCrop.whole,
      );
    });
  });
}
