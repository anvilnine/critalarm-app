import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_contrast.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Lines the standard look does not reach today. It is the alarm screen
/// as it shipped and is not changed here, so each miss is written down
/// with its number and held: the test fails if one is fixed without being
/// taken off this list, and if a new one appears. No other look may have
/// an entry.
///
/// Keyed `stage theme severity`, then the name of the line.
const Map<String, Map<String, String>> _standardMisses = {
  'ringing dark high': {
    '"I\'m up" while it spins against the quiet buttons, over the bar '
            'backing':
        '1.00: the off fill (ash) is as dark as the high canvas that backs '
        'the bar in the dark theme, and the quiet wash is at 1.03. The app '
        'rings in critical or none today, never in high.',
  },
  'acknowledged dark ack': {
    'detail label on its row':
        '4.23: the faint label of a details row on its inset row, dark '
        'theme. The same row and label as everywhere else in the app.',
  },
};

String _key(AlarmStage stage, Brightness brightness, SeverityMode severity) =>
    '${stage.name} ${brightness.name} ${severity.name}';

/// [style] with one of the ringing colours changed after the look has
/// made its own.
AlarmStyle _with(
  AlarmStyle style, {
  required AppColors Function(AppColors colors, Color canvas) change,
  AppButtonVariant? acknowledgeButton,
}) => AlarmStyle(
  id: style.id,
  nameKey: style.nameKey,
  keepsThemeFace: style.keepsThemeFace,
  ringing: AlarmRingingLook(
    colors: (base, severity, brightness) => change(
      style.ringing.colors(base, severity, brightness),
      style.ringing.ambient(base, brightness).canvas,
    ),
    ambient: style.ringing.ambient,
    type: style.ringing.type,
    showsPulseRing: style.ringing.showsPulseRing,
    maxFace: style.ringing.maxFace,
    acknowledgeButton: acknowledgeButton ?? style.ringing.acknowledgeButton,
    quietButton: style.ringing.quietButton,
  ),
  acknowledged: style.acknowledged,
);

void main() {
  // The check itself. It runs over the registry, so a look added later is
  // checked with no edit here, and one that fails it fails the build.
  for (final style in alarmStyles) {
    for (final stage in AlarmStage.values) {
      for (final brightness in Brightness.values) {
        for (final severity in _severitiesOf(stage)) {
          test('${style.id.id}, ${stage.name}, ${brightness.name} theme, '
              '${severity.name}: the buttons and the text read', () {
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
              '${severity.name}: '
              '${[...report.lines, ...report.weights].join('; ')}',
            );
            final known = style.id == AlarmStyleId.standard
                ? (_standardMisses[_key(stage, brightness, severity)] ??
                      const <String, String>{})
                : const <String, String>{};
            expect(
              report.failed.toSet(),
              known.keys.toSet(),
              reason: report.failures.join('\n'),
            );
            expect(report.lines.where((line) => line.isRequired), isNotEmpty);
          });
        }
      }
    }
  }

  test('only the standard look has misses written down, and each names a '
      'real line', () {
    for (final MapEntry(key: where, value: misses) in _standardMisses.entries) {
      final [stageName, themeName, severityName] = where.split(' ');
      final report = alarmStyleContrast(
        alarmStyleOf(AlarmStyleId.standard),
        AlarmStage.values.byName(stageName),
        brightness: Brightness.values.byName(themeName),
        severity: SeverityMode.values.byName(severityName),
      );
      for (final MapEntry(key: what, value: why) in misses.entries) {
        final number = report.line(what)?.ratio ?? report.weight(what)?.heavy;
        expect(number, isNotNull, reason: '$where: $what');
        expect(why, startsWith(number!.toStringAsFixed(2)));
      }
    }
  });

  group('the check catches a look that must not ship:', () {
    for (final style in alarmStyles) {
      for (final brightness in Brightness.values) {
        final where = '${style.id.id}, ${brightness.name} theme';

        test('$where, "I\'m up" filled with the canvas colour', () {
          final report = alarmStyleContrast(
            _with(
              style,
              // The filled treatment, which takes its fill from
              // `highlight`.
              acknowledgeButton: AppButtonVariant.primary,
              change: (colors, canvas) => colors.copyWith(highlight: canvas),
            ),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(report.passes, isFalse);
          final weight = report.weight(
            '"I\'m up" against the quiet buttons, over the canvas',
          )!;
          expect(weight.heavy, 1);
          expect(weight.passes, isFalse);
        });

        test('$where, the message body in the colour of its card', () {
          final report = alarmStyleContrast(
            _with(
              style,
              change: (colors, _) => colors.copyWith(ink2: colors.surface),
            ),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(report.failed, contains('message body on the card'));
          expect(report.line('message body on the card')!.ratio, 1);
        });

        test('$where, "I\'m up" vanishing into the canvas while the '
            'acknowledge is on its way', () {
          final report = alarmStyleContrast(
            _with(
              style,
              change: (colors, canvas) => colors.copyWith(ash: canvas),
            ),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(
            report.failed,
            contains(
              '"I\'m up" while it spins against the quiet buttons, '
              'over the canvas',
            ),
          );
        });

        test('$where, a spinner in the colour of the busy fill', () {
          final report = alarmStyleContrast(
            _with(
              style,
              change: (colors, _) => colors.copyWith(ash: colors.ink2),
            ),
            AlarmStage.ringing,
            brightness: brightness,
          );
          expect(
            report.failed,
            contains('the spinner in "I\'m up" on its fill, over the canvas'),
          );
        });
      }
    }

    test('an outlined "I\'m up" is not the most visible button', () {
      final report = alarmStyleContrast(
        _with(
          alarmStyles.first,
          acknowledgeButton: AppButtonVariant.ghost,
          change: (colors, _) => colors,
        ),
        AlarmStage.ringing,
        brightness: Brightness.light,
      );
      expect(
        report.failed,
        contains('"I\'m up" against the quiet buttons, over the canvas'),
      );
    });

    test('a bar backing the buttons vanish into is caught, though the '
        'canvas at rest is fine', () {
      final style = alarmStyleOf(AlarmStyleId.minimal);
      final report = alarmStyleContrast(
        _with(
          style,
          // The palette's canvas is what backs the pinned bar. Here it is
          // the colour of the label on the outlined buttons.
          change: (colors, _) => colors.copyWith(canvas: colors.onCanvas),
        ),
        AlarmStage.ringing,
        brightness: Brightness.light,
      );
      expect(
        report.failed,
        contains('quiet button label on its fill, over the bar backing'),
      );
      expect(
        report.failed,
        isNot(contains('quiet button label on its fill, over the canvas')),
      );
    });
  });

  group('the button colours follow AppButton', () {
    test('at rest, for the treatments the alarm screen uses', () {
      const colors = AppColors.light;
      expect(alarmButtonColors(AppButtonVariant.primary, colors), (
        fill: colors.highlight,
        label: colors.onHighlight,
      ));
      expect(alarmButtonColors(AppButtonVariant.ink, colors), (
        fill: colors.ink,
        label: colors.canvas,
      ));
      expect(
        alarmButtonColors(AppButtonVariant.ghost, colors).label,
        colors.onCanvas,
      );
      expect(alarmButtonColors(AppButtonVariant.tinted, colors), (
        fill: colors.surface.withValues(alpha: 0.22),
        label: colors.onCanvas,
      ));
      expect(alarmButtonColors(AppButtonVariant.paper, colors), (
        fill: colors.surface,
        label: colors.ink,
      ));
    });

    test('while off or loading, a filled button is ash with an ink2 '
        'spinner', () {
      const colors = AppColors.dark;
      for (final variant in [
        AppButtonVariant.primary,
        AppButtonVariant.ink,
        AppButtonVariant.paper,
      ]) {
        expect(alarmButtonOffColors(variant, colors), (
          fill: colors.ash,
          label: colors.ink2,
        ));
      }
    });
  });
}
