import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/look_pass_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../incidents/alarm_style/synthetic_photos.dart';

const Map<Brightness, AppColors> _themes = {
  Brightness.light: AppColors.light,
  Brightness.dark: AppColors.dark,
};

void main() {
  // Every look in the registry, plus the person's own, so a look added to
  // `alarmStyles` is covered with no edit here.
  final photo = syntheticPhotos().first;
  final own = buildOwnAlarmStyle(
    photo: OwnLookPhoto(null),
    measure: measureOwnPhoto(photo.rgba, photo.width, photo.height),
    accent: ownLookAccents.first,
  );
  final looks = <AlarmStyle>[...alarmStyles, own];

  for (final style in looks) {
    for (final MapEntry(key: brightness, value: base) in _themes.entries) {
      test('${style.id.id}, ${brightness.name}: the text reads on the ground '
          'at 4.5 to 1 or more', () {
        final tone = lookPassToneFor(style, brightness, base);
        expect(
          ColorContrast.contrastRatio(tone.onGround, tone.ground),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test("the ground is the look's own ringing canvas", () {
    for (final style in looks) {
      for (final MapEntry(key: brightness, value: base) in _themes.entries) {
        final colors = style.colorsFor(
          AlarmStage.ringing,
          base: base,
          severity: SeverityMode.crit,
          brightness: brightness,
        );
        final tone = lookPassToneFor(style, brightness, base);
        expect(tone.ground, colors.canvas);
        expect(tone.onGround, colors.onCanvas);
      }
    }
  });

  test('the value takes the text colour on every look', () {
    for (final style in looks) {
      final tone = lookPassToneFor(style, Brightness.light, AppColors.light);
      expect(tone.valueFor(isOn: true), tone.onGround);
      expect(tone.valueFor(isOn: false), tone.onGround);
    }
  });

  test('the standard look is alarm red in the light theme', () {
    final tone = lookPassToneFor(
      alarmStyles.first,
      Brightness.light,
      AppColors.light,
    );
    expect(tone.ground, AppColors.light.critCanvas);
  });
}
