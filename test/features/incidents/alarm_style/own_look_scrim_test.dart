import 'dart:typed_data';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_contrast.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_photos.dart';

Color _grey(int value) => Color.fromARGB(255, value, value, value);

/// What a pixel of [value] becomes under black at [alpha], as the engine
/// rounds it.
int _under(int value, int alpha) => (value * (255 - alpha) / 255).round();

void main() {
  final photos = syntheticPhotos();

  group('measuring a photo:', () {
    test('the grid is 8 by 16, and each cell holds its brightest and its '
        'darkest value', () {
      final split = photos.firstWhere((p) => p.name.contains('split'));
      final measure = measureOwnPhoto(split.rgba, split.width, split.height);
      expect(measure.columns, 8);
      expect(measure.rows, 16);
      expect(measure.peaks, hasLength(128));
      // 90 pixels over 8 columns: the split at 45 falls on a cell edge.
      for (var row = 0; row < 16; row++) {
        for (var column = 0; column < 8; column++) {
          final cell = row * 8 + column;
          expect(measure.peaks[cell], column < 4 ? 0 : 255);
          expect(measure.lows[cell], column < 4 ? 0 : 255);
        }
      }
      expect(measure.brightest, 255);
      expect(measure.darkest, 0);
    });

    test('a cell is as bright as its brightest pixel, never an average', () {
      final dot = photos.firstWhere((p) => p.name.contains('one white dot'));
      final measure = measureOwnPhoto(dot.rgba, dot.width, dot.height);
      expect(measure.peaks.where((peak) => peak == 255), hasLength(1));
      expect(measure.peaks.where((peak) => peak == 128), hasLength(127));
      expect(measure.brightest, 255);
      expect(measure.darkest, 128);
    });

    test('a pure colour is as bright as its strongest part', () {
      final red = photos.firstWhere((p) => p.name.contains('red'));
      final measure = measureOwnPhoto(red.rgba, red.width, red.height);
      expect(measure.brightest, 255);
      expect(measure.darkest, 0);
    });

    test('a photo smaller than the grid gets a cell per pixel', () {
      final measure = measureOwnPhoto(
        Uint8List.fromList([10, 20, 30, 255, 200, 100, 50, 255]),
        2,
        1,
      );
      expect(measure.columns, 2);
      expect(measure.rows, 1);
      expect(measure.peaks, [30, 200]);
      expect(measure.lows, [10, 50]);
    });

    test('pixels that are not a whole picture are refused', () {
      expect(() => measureOwnPhoto(Uint8List(7), 2, 1), throwsArgumentError);
      expect(() => measureOwnPhoto(Uint8List(8), 0, 1), throwsArgumentError);
    });

    test('a measure reads back as it was written, and anything else reads '
        'as none', () {
      for (final photo in photos) {
        final measure = measureOwnPhoto(photo.rgba, photo.width, photo.height);
        expect(OwnPhotoMeasure.decode(measure.encode()), measure);
      }
      expect(OwnPhotoMeasure.decode(null), isNull);
      expect(OwnPhotoMeasure.decode(''), isNull);
      expect(OwnPhotoMeasure.decode('not json'), isNull);
      expect(
        OwnPhotoMeasure.decode('{"v":2,"c":1,"r":1,"p":[1],"l":[1]}'),
        isNull,
      );
      expect(
        OwnPhotoMeasure.decode('{"v":1,"c":2,"r":1,"p":[1],"l":[1]}'),
        isNull,
      );
      expect(
        OwnPhotoMeasure.decode('{"v":1,"c":1,"r":1,"p":[300],"l":[1]}'),
        isNull,
      );
      // A cell darker at its brightest than at its darkest is not a
      // measure.
      expect(
        OwnPhotoMeasure.decode('{"v":1,"c":1,"r":1,"p":[3],"l":[9]}'),
        isNull,
      );
    });
  });

  group('the scrim:', () {
    final words = ColorContrast.relativeLuminance(ownLookWords);

    test("the luminance here is the design system's", () {
      for (final value in [0, 1, 10, 11, 77, 110, 128, 200, 255]) {
        expect(
          greyLuminance(value),
          closeTo(ColorContrast.relativeLuminance(_grey(value)), 1e-12),
        );
      }
      expect(
        luminanceContrast(words, greyLuminance(40)),
        closeTo(ColorContrast.contrastRatio(ownLookWords, _grey(40)), 1e-12),
      );
    });

    for (final photo in photos) {
      test('${photo.name}: the words read on every pixel under it', () {
        final measure = measureOwnPhoto(photo.rgba, photo.width, photo.height);
        final scrim = ownLookScrimOf(measure);
        final brightest = ColorContrast.contrastRatio(
          ownLookWords,
          _grey(scrim.brightestBehind),
        );
        final darkest = ColorContrast.contrastRatio(
          ownLookWords,
          _grey(scrim.darkestBehind),
        );
        // Printed so the numbers are in the test log.
        // ignore: avoid_print
        print(
          '${photo.name}: photo ${measure.darkest} to ${measure.brightest}, '
          '$scrim, words on the brightest ${brightest.toStringAsFixed(2)}, '
          'on the darkest ${darkest.toStringAsFixed(2)}',
        );
        expect(scrim.alpha, inInclusiveRange(ownLookMinScrim, 255));
        expect(brightest, greaterThanOrEqualTo(ownLookScrimTarget));
        expect(brightest, greaterThanOrEqualTo(alarmStyleMinContrast));
        expect(darkest, greaterThanOrEqualTo(brightest));

        // By construction, for every pixel of the photo and not only for
        // the two ends: each pixel under the scrim, as the engine rounds
        // it, is inside the range the scrim names, and the words read on
        // it.
        var worst = double.infinity;
        for (var at = 0; at < photo.rgba.length; at += 4) {
          final r = _under(photo.rgba[at], scrim.alpha);
          final g = _under(photo.rgba[at + 1], scrim.alpha);
          final b = _under(photo.rgba[at + 2], scrim.alpha);
          for (final value in [r, g, b]) {
            expect(
              value,
              inInclusiveRange(scrim.darkestBehind, scrim.brightestBehind),
            );
          }
          final ratio = ColorContrast.contrastRatio(
            ownLookWords,
            Color.fromARGB(255, r, g, b),
          );
          if (ratio < worst) worst = ratio;
        }
        expect(worst, greaterThanOrEqualTo(alarmStyleMinContrast));
        expect(worst, greaterThanOrEqualTo(brightest));
      });
    }

    test('a brighter photo gets a stronger scrim, and a dark one the '
        'lightest', () {
      OwnLookScrim of(String name) {
        final photo = photos.firstWhere((p) => p.name == name);
        return ownLookScrimOf(
          measureOwnPhoto(photo.rgba, photo.width, photo.height),
        );
      }

      expect(of('all black').alpha, ownLookMinScrim);
      expect(of('a dim room').alpha, ownLookMinScrim);
      expect(of('all white').alpha, greaterThan(ownLookMinScrim));
      // One white pixel is enough: a word can land on it.
      expect(of('noise').alpha, of('all white').alpha);
      expect(of('a hard black and white split').alpha, of('all white').alpha);
      expect(
        of('a mid grey with one white dot').alpha,
        of('all white').alpha,
      );
      // The photo is still there under the strongest scrim.
      expect(of('all white').alpha, lessThan(160));
    });

    test('every peak from black to white gives a scrim the words read '
        'under', () {
      for (var peak = 0; peak <= 255; peak++) {
        final scrim = ownLookScrimFor(
          OwnPhotoMeasure(columns: 1, rows: 1, peaks: [peak], lows: const [0]),
          wordsLuminance: words,
        );
        expect(
          ColorContrast.contrastRatio(
            ownLookWords,
            _grey(scrim.brightestBehind),
          ),
          greaterThanOrEqualTo(ownLookScrimTarget),
          reason: 'peak $peak',
        );
        expect(
          _under(peak, scrim.alpha),
          lessThanOrEqualTo(
            scrim.brightestBehind,
          ),
        );
      }
    });

    test('the scrim is the lightest that works: one step lighter and the '
        'brightest pixel is under the target', () {
      final scrim = ownLookScrimFor(
        const OwnPhotoMeasure(columns: 1, rows: 1, peaks: [255], lows: [255]),
        wordsLuminance: words,
      );
      final lighter = (255 * (255 - (scrim.alpha - 1)) / 255).ceil() + 1;
      expect(
        ColorContrast.contrastRatio(ownLookWords, _grey(lighter)),
        lessThan(ownLookScrimTarget),
      );
    });
  });
}
