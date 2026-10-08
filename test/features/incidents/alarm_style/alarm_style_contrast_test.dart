import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_contrast.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [style] with the fill of "I'm up" set to the colour of the canvas
/// behind it, in both themes. A look like this must never ship.
AlarmStyle _acknowledgeHidden(AlarmStyle style) => AlarmStyle(
  id: style.id,
  nameKey: style.nameKey,
  keepsThemeFace: style.keepsThemeFace,
  ringing: AlarmRingingLook(
    colors: (base, severity, brightness) {
      final colors = style.ringing.colors(base, severity, brightness);
      final canvas = style.ringing.ambient(base).canvas;
      return colors.copyWith(highlight: canvas);
    },
    ambient: style.ringing.ambient,
    type: style.ringing.type,
    showsPulseRing: style.ringing.showsPulseRing,
    maxFace: style.ringing.maxFace,
    // The filled treatment, which takes its fill from `highlight`.
    quietButton: style.ringing.quietButton,
  ),
  acknowledged: style.acknowledged,
);

/// [style] with the message text set to the colour of its card.
AlarmStyle _messageHidden(AlarmStyle style) => AlarmStyle(
  id: style.id,
  nameKey: style.nameKey,
  keepsThemeFace: style.keepsThemeFace,
  ringing: AlarmRingingLook(
    colors: (base, severity, brightness) {
      final colors = style.ringing.colors(base, severity, brightness);
      return colors.copyWith(ink2: colors.surface);
    },
    ambient: style.ringing.ambient,
    type: style.ringing.type,
    showsPulseRing: style.ringing.showsPulseRing,
    maxFace: style.ringing.maxFace,
    acknowledgeButton: style.ringing.acknowledgeButton,
    quietButton: style.ringing.quietButton,
  ),
  acknowledged: style.acknowledged,
);

/// The severities a stage is drawn in. The ringing stage takes the
/// incident's, which is never the acknowledged one. The acknowledged stage
/// is always drawn in the acknowledged one.
List<SeverityMode> _severitiesOf(AlarmStage stage) => switch (stage) {
  AlarmStage.ringing => const [
    SeverityMode.none,
    SeverityMode.high,
    SeverityMode.crit,
  ],
  AlarmStage.acknowledged => const [SeverityMode.ack],
};

void main() {
  // The check itself. It runs over the registry, so a look added later is
  // checked with no edit here, and one that fails it fails the build.
  for (final style in alarmStyles) {
    for (final stage in AlarmStage.values) {
      for (final brightness in Brightness.values) {
        for (final severity in _severitiesOf(stage)) {
          test('${style.id.id}, ${stage.name}, ${brightness.name} theme, '
              '${severity.name}: "I\'m up" and the text read at '
              '$alarmStyleMinContrast to 1', () {
            final report = alarmStyleContrast(
              style,
              stage,
              brightness: brightness,
              severity: severity,
            );
            // Printed so the numbers are in the test log.
            // ignore: avoid_print
            print(
              '${style.id.id} ${stage.name} ${brightness.name} '
              '${severity.name}: ${report.lines.join(', ')}'
              '${report.acknowledgeStandsOut == null ? '' : ', '
                        '"I\'m up" off the canvas '
                        '${report.acknowledgeStandsOut!.toStringAsFixed(2)}'
                        ', quiet buttons off the canvas '
                        '${report.quietStandsOut!.toStringAsFixed(2)}'}',
            );
            expect(report.failures, isEmpty);
            expect(
              report.lines.where((line) => line.isRequired),
              isNotEmpty,
            );
          });
        }
      }
    }
  }

  group('the check catches a look that must not ship:', () {
    for (final style in alarmStyles) {
      for (final brightness in Brightness.values) {
        test('${style.id.id}, ${brightness.name} theme, "I\'m up" filled '
            'with the canvas colour', () {
          final report = alarmStyleContrast(
            _acknowledgeHidden(style),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(report.passes, isFalse);
          expect(report.acknowledgeStandsOut, 1);
          expect(report.acknowledgeIsMostVisible, isFalse);
        });

        test('${style.id.id}, ${brightness.name} theme, the message body '
            'in the colour of its card', () {
          final report = alarmStyleContrast(
            _messageHidden(style),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(report.passes, isFalse);
          expect(
            report.failures.single,
            contains('message body on the card 1.00'),
          );
        });
      }
    }

    test('an outlined "I\'m up" is not the most visible button', () {
      final style = alarmStyles.first;
      final outlined = AlarmStyle(
        id: style.id,
        nameKey: style.nameKey,
        ringing: AlarmRingingLook(
          colors: style.ringing.colors,
          ambient: style.ringing.ambient,
          type: style.ringing.type,
          acknowledgeButton: AppButtonVariant.ghost,
        ),
        acknowledged: style.acknowledged,
      );
      final report = alarmStyleContrast(
        outlined,
        AlarmStage.ringing,
        brightness: Brightness.light,
      );
      expect(report.acknowledgeIsMostVisible, isFalse);
      expect(report.passes, isFalse);
    });
  });

  group('alarmButtonColors follows AppButton', () {
    test('for the treatments the alarm screen uses', () {
      const colors = AppColors.light;
      expect(
        alarmButtonColors(AppButtonVariant.primary, colors),
        (fill: colors.highlight, label: colors.onHighlight),
      );
      expect(
        alarmButtonColors(AppButtonVariant.ink, colors),
        (fill: colors.ink, label: colors.canvas),
      );
      expect(
        alarmButtonColors(AppButtonVariant.ghost, colors).label,
        colors.onCanvas,
      );
      expect(
        alarmButtonColors(AppButtonVariant.tinted, colors),
        (fill: colors.surface.withValues(alpha: 0.22), label: colors.onCanvas),
      );
      expect(
        alarmButtonColors(AppButtonVariant.paper, colors),
        (fill: colors.surface, label: colors.ink),
      );
    });
  });
}
