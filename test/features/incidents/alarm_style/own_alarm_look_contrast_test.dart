import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_contrast.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_photos.dart';

List<SeverityMode> _severitiesOf(AlarmStage stage) => switch (stage) {
  AlarmStage.ringing => const [
    SeverityMode.none,
    SeverityMode.high,
    SeverityMode.crit,
  ],
  AlarmStage.acknowledged => const [SeverityMode.ack],
};

const Map<Brightness, AppColors> _themes = {
  Brightness.light: AppColors.light,
  Brightness.dark: AppColors.dark,
};

/// The own look for [photo] with [accent]. The contrast rule reads the
/// measure and the colours, never the picture, so none is decoded here.
AlarmStyle _look(SyntheticPhoto photo, OwnLookAccent accent) =>
    buildOwnAlarmStyle(
      photo: OwnLookPhoto(null),
      measure: measureOwnPhoto(photo.rgba, photo.width, photo.height),
      accent: accent,
    );

OwnLookScrim _scrim(SyntheticPhoto photo) =>
    ownLookScrimOf(measureOwnPhoto(photo.rgba, photo.width, photo.height));

void main() {
  final photos = syntheticPhotos();

  // The check itself: the same rule every fixed look passes, run once on
  // the bare canvas and once on each end of what the scrim leaves of the
  // photo. "I'm up" is measured at rest and while it spins, with every
  // accent, in both themes and both stages.
  for (final photo in photos) {
    for (final accent in ownLookAccents) {
      test('${photo.name}, ${accent.id}: the buttons and the text read on '
          'the photo, both themes, both stages', () {
        final style = _look(photo, accent);
        final scrim = _scrim(photo);
        for (final MapEntry(key: brightness, value: base) in _themes.entries) {
          for (final stage in AlarmStage.values) {
            for (final severity in _severitiesOf(stage)) {
              final colors = style.colorsFor(
                stage,
                base: base,
                severity: severity,
                brightness: brightness,
              );
              final tones = ownLookBackdropTones(colors, scrim);
              expect(tones, hasLength(3));
              expect(tones.first, colors.canvas);
              for (final (index, tone) in tones.indexed) {
                final report = alarmStyleContrast(
                  style,
                  stage,
                  brightness: brightness,
                  severity: severity,
                  behindTheStage: tone,
                );
                final where =
                    '${stage.name} ${brightness.name} ${severity.name}, '
                    'behind it ${const [
                      'the bare canvas',
                      'the darkest of the photo',
                      'the brightest of the photo',
                    ][index]}';
                expect(
                  report.failed,
                  isEmpty,
                  reason: '$where\n${report.failures.join('\n')}',
                );
                expect(
                  report.lines.where((line) => line.isRequired),
                  isNotEmpty,
                );
                if (stage == AlarmStage.ringing) {
                  expect(report.weights, hasLength(4), reason: where);
                  // "I'm up" is the heaviest thing in the bar by a clear
                  // margin, at rest and while it spins: at least twice
                  // the stand-out of a quiet button, and never under the
                  // floor.
                  for (final weight in report.weights) {
                    expect(
                      weight.heavy,
                      greaterThanOrEqualTo(alarmStyleMinFillContrast),
                      reason: '$where: $weight',
                    );
                    expect(
                      weight.heavy,
                      greaterThanOrEqualTo(weight.light * 2),
                      reason: '$where: $weight',
                    );
                  }
                  // The card and the wash of the quiet buttons are the
                  // same in both themes while the phone rings.
                  expect(colors.surface, const Color(0xFFFFFFFF));
                }
              }
            }
          }
        }
      });
    }
  }

  test('the numbers, for the brightest photo there is and each accent', () {
    final white = photos.firstWhere((p) => p.name == 'all white');
    final scrim = _scrim(white);
    for (final accent in ownLookAccents) {
      final style = _look(white, accent);
      for (final brightness in Brightness.values) {
        final colors = style.colorsFor(
          AlarmStage.ringing,
          base: _themes[brightness]!,
          severity: SeverityMode.crit,
          brightness: brightness,
        );
        final report = alarmStyleContrast(
          style,
          AlarmStage.ringing,
          brightness: brightness,
          behindTheStage: ownLookBackdropTones(colors, scrim).last,
        );
        // Printed so the numbers are in the test log.
        // ignore: avoid_print
        print(
          'own ${accent.id} ${brightness.name}, over the brightest a photo '
          'can be: ${[...report.lines, ...report.weights].join('; ')}',
        );
      }
    }
  });

  group('the accent set:', () {
    test('eight colours, each id and each name used once, yellow first', () {
      expect(ownLookAccents, hasLength(8));
      expect(ownLookAccents.map((a) => a.id).toSet(), hasLength(8));
      expect(ownLookAccents.map((a) => a.nameKey).toSet(), hasLength(8));
      expect(ownLookAccents.map((a) => a.fill).toSet(), hasLength(8));
      expect(ownLookAccents.first.id, 'yellow');
      expect(ownLookAccents.first.fill, AppColors.light.yellow);
    });

    test('an id saved by another build, or none, is the first accent', () {
      expect(ownLookAccentOf(null), ownLookAccents.first);
      expect(ownLookAccentOf('teal_from_a_newer_build'), ownLookAccents.first);
      expect(ownLookAccentOf('mint').id, 'mint');
    });

    test('each label reads on its fill and on its hover fill', () {
      for (final accent in ownLookAccents) {
        final rest = ColorContrast.contrastRatio(accent.label, accent.fill);
        final hover = ColorContrast.contrastRatio(accent.label, accent.hover);
        // Printed so the numbers are in the test log.
        // ignore: avoid_print
        print(
          'accent ${accent.id}: label on fill ${rest.toStringAsFixed(2)}, '
          'on hover ${hover.toStringAsFixed(2)}',
        );
        expect(rest, greaterThanOrEqualTo(alarmStyleMinContrast));
        expect(hover, greaterThanOrEqualTo(alarmStyleMinContrast));
        expect(accent.fill.a, 1, reason: 'a see-through fill');
      }
    });

    test('every fill, and the busy fill in both themes, is brighter than '
        'anything a scrim leaves of any photo', () {
      // The brightest the photo can be under the scrim, for a photo that
      // is pure white.
      final ceiling = greyLuminance(
        ownLookScrimOf(
          const OwnPhotoMeasure(
            columns: 1,
            rows: 1,
            peaks: [255],
            lows: [255],
          ),
        ).brightestBehind,
      );
      for (final accent in ownLookAccents) {
        final fill = ColorContrast.relativeLuminance(accent.fill);
        expect(fill, greaterThan(ceiling), reason: accent.id);
        // Far enough to be a shape on it (WCAG AA for graphics is 3; a
        // filled pill with a dark label needs less to be the button).
        expect(
          (fill + 0.05) / (ceiling + 0.05),
          greaterThanOrEqualTo(2),
          reason: accent.id,
        );
      }
      final style = _look(photos.first, ownLookAccents.first);
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        final busy = style
            .colorsFor(
              AlarmStage.ringing,
              base: base,
              severity: SeverityMode.crit,
              brightness: brightness,
            )
            .ash;
        expect(
          ColorContrast.relativeLuminance(busy),
          greaterThan(ceiling),
          reason: brightness.name,
        );
      }
    });
  });

  group('the own look is a whole look:', () {
    final style = _look(photos.first, ownLookAccents.first);

    test('its id is own, saved as "own", and it needs a plan', () {
      expect(style.id, AlarmStyleId.own);
      expect(AlarmStyleId.own.id, 'own');
      expect(AlarmStyleId.own.isFree, isFalse);
      expect(AlarmStyleId.fromId('own'), AlarmStyleId.own);
    });

    test('the buttons keep the standard type, and nothing moves', () {
      expect(style.ringing.type, standardRingingType);
      expect(style.acknowledged.type, standardAcknowledgedType);
      expect(style.backdrop, isNotNull);
      expect(style.backdropMoves, isFalse);
      expect(style.ringing.maxFace, double.infinity);
      expect(style.ringing.acknowledgeButton, AppButtonVariant.primary);
      expect(style.ringing.quietButton, AppButtonVariant.tinted);
    });

    test('the face is the yellow one in both themes and both stages', () {
      expect(style.keepsThemeFace, isFalse);
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        for (final stage in AlarmStage.values) {
          final colors = style.colorsFor(
            stage,
            base: base,
            severity: SeverityMode.crit,
            brightness: brightness,
          );
          expect(colors.faceFill, AppColors.light.yellow);
          expect(colors.faceInk, AppColors.light.faceInk);
        }
        expect(style.facePaletteFor(brightness), AppColors.light);
      }
    });

    test('each stage has a solid canvas with three shapes, and it is what '
        'backs the pinned buttons', () {
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        for (final stage in AlarmStage.values) {
          final profile = style.lookOf(stage).ambient(base, brightness);
          expect(profile.shapes, hasLength(3));
          expect(profile.canvas.a, 1);
          final colors = style.colorsFor(
            stage,
            base: base,
            severity: SeverityMode.crit,
            brightness: brightness,
          );
          expect(colors.canvas, profile.canvas);
          // The card and the bar behind the buttons are solid: no word on
          // them has the photo behind it.
          expect(colors.surface.a, 1);
          expect(colors.cream.a, 1);
        }
      }
    });

    test('the accent is the fill of "I\'m up" and nothing else', () {
      for (final accent in ownLookAccents) {
        final colors = _look(photos.first, accent).colorsFor(
          AlarmStage.ringing,
          base: AppColors.light,
          severity: SeverityMode.crit,
          brightness: Brightness.light,
        );
        expect(colors.highlight, accent.fill);
        expect(colors.onHighlight, accent.label);
        expect(colors.onCanvas, ownLookWords);
      }
    });

    test('what is laid over the photo under a word only darkens it', () {
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        final colors = style.colorsFor(
          AlarmStage.acknowledged,
          base: base,
          severity: SeverityMode.ack,
          brightness: brightness,
        );
        // The topic pill, and the hover of an outlined button.
        for (final tint in [colors.canvasGhostStrong, colors.canvasGhost]) {
          expect(ColorContrast.relativeLuminance(tint.withValues(alpha: 1)), 0);
        }
        for (final photo in photos) {
          final brightest = ownLookBackdropTones(colors, _scrim(photo)).last;
          expect(
            ColorContrast.contrastRatio(
              colors.onCanvas,
              Color.alphaBlend(colors.canvasGhostStrong, brightest),
            ),
            greaterThanOrEqualTo(alarmStyleMinContrast),
          );
        }
      }
    });
  });

  group('the painter:', () {
    Future<ui.Image> image(int width, int height) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final picture = recorder.endRecording();
      final made = await picture.toImage(width, height);
      picture.dispose();
      return made;
    }

    AlarmBackdropFrame frame(AlarmStyle style, AlarmStage stage) =>
        AlarmBackdropFrame(
          stage: stage,
          colors: style.colorsFor(
            stage,
            base: AppColors.light,
            severity: SeverityMode.crit,
            brightness: Brightness.light,
          ),
          elapsed: Duration.zero,
          isStill: true,
        );

    test('it paints at every size and leaves the canvas as it found it, '
        'and a photo that was let go paints nothing', () async {
      final photo = OwnLookPhoto(await image(90, 195));
      final style = buildOwnAlarmStyle(
        photo: photo,
        measure: measureOwnPhoto(
          photos.first.rgba,
          photos.first.width,
          photos.first.height,
        ),
        accent: ownLookAccents.first,
      );
      void paintAll() {
        for (final size in const [
          Size(390, 844),
          Size(375, 667),
          Size(1024, 768),
          Size(60, 130),
          Size.zero,
        ]) {
          for (final stage in AlarmStage.values) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            final saves = canvas.getSaveCount();
            style.backdrop!(frame(style, stage)).paint(canvas, size);
            expect(canvas.getSaveCount(), saves);
            recorder.endRecording().dispose();
          }
        }
      }

      paintAll();
      final before = style.backdrop!(frame(style, AlarmStage.ringing));
      // The same photo: one picture, never painted again.
      expect(
        style.backdrop!(frame(style, AlarmStage.acknowledged)).shouldRepaint(
          before,
        ),
        isFalse,
      );
      photo.release();
      expect(photo.image, isNull);
      paintAll();
      expect(
        style.backdrop!(frame(style, AlarmStage.ringing)).shouldRepaint(before),
        isTrue,
      );
    });

    test('the scrimmed photo is what reaches the screen: a white photo is '
        'drawn no brighter than the scrim says', () async {
      const width = 20;
      const height = 40;
      final white = await image(width, height);
      final measure = measureOwnPhoto(
        (await white.toByteData())!.buffer.asUint8List(),
        width,
        height,
      );
      expect(measure.brightest, 255);
      final style = buildOwnAlarmStyle(
        photo: OwnLookPhoto(white),
        measure: measure,
        accent: ownLookAccents.first,
      );
      final scrim = ownLookScrimOf(measure);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      style.backdrop!(frame(style, AlarmStage.ringing)).paint(
        canvas,
        const Size(30, 50),
      );
      final picture = recorder.endRecording();
      final drawn = await picture.toImage(30, 50);
      final pixels = (await drawn.toByteData())!.buffer.asUint8List();
      var brightest = 0;
      var darkest = 255;
      for (var at = 0; at < pixels.length; at += 4) {
        for (var channel = 0; channel < 3; channel++) {
          final value = pixels[at + channel];
          if (value > brightest) brightest = value;
          if (value < darkest) darkest = value;
        }
        expect(pixels[at + 3], 255, reason: 'the photo covers the screen');
      }
      // Printed so the numbers are in the test log.
      // ignore: avoid_print
      print(
        'a white photo under $scrim is drawn $darkest to $brightest of 255',
      );
      expect(brightest, lessThanOrEqualTo(scrim.brightestBehind));
      expect(darkest, greaterThanOrEqualTo(scrim.darkestBehind));
      expect(
        ColorContrast.contrastRatio(
          ownLookWords,
          Color.fromARGB(255, brightest, brightest, brightest),
        ),
        greaterThanOrEqualTo(alarmStyleMinContrast),
      );
      picture.dispose();
      drawn.dispose();
    });
  });

  group('the look the alarm screen asks for:', () {
    tearDown(() => holdOwnAlarmStyle(null));

    test('with no own look held, the own id draws the standard look', () {
      holdOwnAlarmStyle(null);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      expect(pickableAlarmStyles, alarmStyles);
    });

    test('with one held, it is that one, and the pickers list it last', () {
      final style = _look(photos.first, ownLookAccents.first);
      holdOwnAlarmStyle(style);
      expect(identical(alarmStyleOf(AlarmStyleId.own), style), isTrue);
      expect(pickableAlarmStyles, [...alarmStyles, style]);
      expect(
        drawableAlarmStyle(
          style,
          base: AppColors.dark,
          severity: SeverityMode.crit,
          brightness: Brightness.dark,
        ),
        style,
      );
    });

    test('the fixed looks are what they were', () {
      expect(alarmStyles.map((style) => style.id), [
        AlarmStyleId.standard,
        AlarmStyleId.minimal,
        AlarmStyleId.terminal,
        AlarmStyleId.redAlert,
        AlarmStyleId.critPanic,
      ]);
      for (final style in alarmStyles) {
        expect(identical(alarmStyleOf(style.id), style), isTrue);
      }
    });
  });
}
