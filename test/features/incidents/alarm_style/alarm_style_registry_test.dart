import 'dart:convert';
import 'dart:io';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/minimal_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three families the app bundles. A look ships no font of its own.
const Set<String> _bundledFamilies = {
  AppTypography.fontDisplay,
  AppTypography.fontBody,
  AppTypography.fontMono,
};

/// The button treatments a look may give the ringing buttons: the ones
/// `alarmButtonColors` knows and that keep the pill a full-size target.
const Set<AppButtonVariant> _ringingButtons = {
  AppButtonVariant.primary,
  AppButtonVariant.ink,
  AppButtonVariant.ghost,
  AppButtonVariant.tinted,
  AppButtonVariant.paper,
  AppButtonVariant.crit,
  AppButtonVariant.cream,
};

const Map<Brightness, AppColors> _themes = {
  Brightness.light: AppColors.light,
  Brightness.dark: AppColors.dark,
};

void main() {
  group('the registry', () {
    test('every id has exactly one look, and the standard one is first', () {
      expect(
        alarmStyles.map((style) => style.id).toList(),
        AlarmStyleId.values,
      );
      expect(alarmStyles.first.id, AlarmStyleId.standard);
    });

    test('an id with no look draws the standard one', () {
      expect(alarmStyleOf(null), standardAlarmStyle);
      expect(alarmStyleOf(AlarmStyleId.minimal), minimalAlarmStyle);
    });

    test('every look has a name in the strings', () {
      final strings =
          jsonDecode(File('assets/translations/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final names = <String>{};
      for (final style in alarmStyles) {
        Object? node = strings;
        for (final part in style.nameKey.split('.')) {
          node = node is Map<String, dynamic> ? node[part] : null;
        }
        expect(node, isA<String>(), reason: style.nameKey);
        expect((node! as String).trim(), isNotEmpty, reason: style.nameKey);
        names.add(node as String);
      }
      expect(names.length, alarmStyles.length, reason: 'two looks, one name');
    });
  });

  for (final style in alarmStyles) {
    group('${style.id.id} is complete:', () {
      test('its type uses bundled families and has a size', () {
        for (final text in [
          ...style.ringing.type.all,
          ...style.acknowledged.type.all,
        ]) {
          expect(_bundledFamilies, contains(text.fontFamily));
          expect(text.fontSize, isNotNull);
          expect(text.fontSize, greaterThanOrEqualTo(12));
        }
      });

      test('each stage has a canvas with three shapes, and the pinned '
          'buttons are backed by that canvas', () {
        for (final MapEntry(key: brightness, value: base) in _themes.entries) {
          for (final stage in AlarmStage.values) {
            final profile = style.lookOf(stage).ambient(base);
            expect(profile.shapes, hasLength(3));
            expect(profile.canvas.a, 1, reason: 'a see-through canvas');
            if (style.keepsThemeFace) continue;
            // A look with its own canvas says so in both places.
            final colors = style.colorsFor(
              stage,
              base: base,
              severity: SeverityMode.crit,
              brightness: brightness,
            );
            expect(
              colors.canvas,
              profile.canvas,
              reason: '${stage.name} ${brightness.name}',
            );
          }
        }
      });

      test('the face may only be capped, never left out', () {
        expect(style.ringing.maxFace, greaterThanOrEqualTo(64));
        expect(style.acknowledged.maxFace, greaterThanOrEqualTo(64));
      });

      test('the ringing buttons use a treatment the checks know', () {
        expect(_ringingButtons, contains(style.ringing.acknowledgeButton));
        expect(_ringingButtons, contains(style.ringing.quietButton));
        expect(
          style.ringing.acknowledgeButton,
          isNot(style.ringing.quietButton),
          reason: '"I\'m up" must not look like the quiet buttons',
        );
      });

      test('a background that moves has a painter', () {
        if (style.backdropMoves) expect(style.backdrop, isNotNull);
      });

      test('the face is yellow in both themes and both stages', () {
        if (style.keepsThemeFace) return;
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
    });
  }

  group('the standard look is the alarm screen as it was:', () {
    test('it is the only look that keeps the theme face', () {
      expect(
        alarmStyles.where((style) => style.keepsThemeFace).toList(),
        [standardAlarmStyle],
      );
      expect(
        standardAlarmStyle.facePaletteFor(Brightness.dark),
        AppColors.dark,
      );
      expect(
        standardAlarmStyle.facePaletteFor(Brightness.light),
        AppColors.light,
      );
    });

    test('its colours are the severity palette, untouched', () {
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        for (final severity in SeverityMode.values) {
          final ringing = standardAlarmStyle.colorsFor(
            AlarmStage.ringing,
            base: base,
            severity: severity,
            brightness: brightness,
          );
          expect(ringing.canvas, base.withSeverity(severity).canvas);
          expect(ringing.faceFill, base.faceFill);
          expect(ringing.highlight, base.highlight);
          // A severity that retints nothing hands the app's palette back.
          if (severity == SeverityMode.none) {
            expect(identical(ringing, base), isTrue);
          }
          // The acknowledged stage is the acknowledged palette whatever
          // the incident's severity.
          final acknowledged = standardAlarmStyle.colorsFor(
            AlarmStage.acknowledged,
            base: base,
            severity: severity,
            brightness: brightness,
          );
          expect(acknowledged.canvas, base.ackCanvas);
          expect(acknowledged.onCanvas, base.ackText);
        }
      }
    });

    test('its canvases are the two alarm profiles', () {
      for (final base in _themes.values) {
        expect(
          standardAlarmStyle.ringing.ambient(base),
          AmbientAppProfiles.criticalAlarmRinging(base),
        );
        expect(
          standardAlarmStyle.acknowledged.ambient(base),
          AmbientAppProfiles.criticalAlarmAcknowledged(base),
        );
      }
    });

    test('it changes nothing else', () {
      expect(standardAlarmStyle.ringing.showsPulseRing, isTrue);
      expect(standardAlarmStyle.ringing.maxFace, double.infinity);
      expect(standardAlarmStyle.acknowledged.maxFace, double.infinity);
      expect(
        standardAlarmStyle.ringing.acknowledgeButton,
        AppButtonVariant.primary,
      );
      expect(standardAlarmStyle.ringing.quietButton, AppButtonVariant.tinted);
      expect(standardAlarmStyle.backdrop, isNull);
      expect(standardAlarmStyle.ringing.type.word.fontSize, 56);
      expect(standardAlarmStyle.ringing.type.topic.fontSize, 17);
      expect(standardAlarmStyle.ringing.type.time.fontSize, 15);
      expect(standardAlarmStyle.ringing.type.messageTitle.fontSize, 22);
      expect(standardAlarmStyle.acknowledged.type.title.fontSize, 56);
    });
  });

  group('Minimal takes things away:', () {
    test('no shapes, no pulse ring, a small face, large topic and time', () {
      for (final base in _themes.values) {
        for (final stage in AlarmStage.values) {
          final profile = minimalAlarmStyle.lookOf(stage).ambient(base);
          expect(profile.shapes.every((shape) => shape.opacity == 0), isTrue);
        }
      }
      expect(minimalAlarmStyle.ringing.showsPulseRing, isFalse);
      expect(minimalAlarmStyle.ringing.maxFace, lessThan(100));
      expect(
        minimalAlarmStyle.ringing.type.topic.fontSize,
        greaterThan(standardAlarmStyle.ringing.type.topic.fontSize!),
      );
      expect(
        minimalAlarmStyle.ringing.type.time.fontSize,
        greaterThan(standardAlarmStyle.ringing.type.time.fontSize!),
      );
    });

    test('the canvas is near-white in the light theme and near-black in '
        'the dark one', () {
      final light = minimalAlarmStyle.ringing.ambient(AppColors.light).canvas;
      final dark = minimalAlarmStyle.ringing.ambient(AppColors.dark).canvas;
      expect(light.computeLuminance(), greaterThan(0.85));
      expect(dark.computeLuminance(), lessThan(0.02));
    });
  });
}
