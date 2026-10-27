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

/// Why the busy fill of the standard look is on the list below.
const String _standardBusy =
    'the off fill (ash) is close to the canvas in this theme. The standard '
    'look is the alarm screen as it shipped and is not changed here.';

/// Why a look with outlined quiet buttons is on the list below.
const String _outlined =
    'the quiet buttons are outlines in the colour of the words. Weighed '
    'by its stroke, an outline in that colour stands off the canvas as far '
    'as any fill can, so no fill outweighs it by this number. The look '
    'shipped with a filled "I\'m up" over two outlines and is not changed '
    'here.';

const String _restCanvas =
    '"I\'m up" against the quiet buttons, over the canvas';
const String _restBar =
    '"I\'m up" against the quiet buttons, over the bar backing';
const String _busyCanvas =
    '"I\'m up" while it spins against the quiet buttons, over the canvas';
const String _busyBar =
    '"I\'m up" while it spins against the quiet buttons, over the bar '
    'backing';
const String _busyFillCanvas =
    'the fill of "I\'m up" while it spins against what is behind it, over '
    'the canvas';
const String _busyFillBar =
    'the fill of "I\'m up" while it spins against what is behind it, over '
    'the bar backing';

/// The four weight lines of a look with outlined quiet buttons, with the
/// number "I'm up" reaches at rest and while it spins. The outline it is
/// weighed against is in [against].
Map<String, String> _outlinedMisses(
  String rest,
  String busy,
  String against,
) => {
  _restCanvas: '$rest against an outline at $against: $_outlined',
  _restBar: '$rest against an outline at $against: $_outlined',
  _busyCanvas: '$busy against an outline at $against: $_outlined',
  _busyBar: '$busy against an outline at $against: $_outlined',
};

/// Lines a fixed look does not reach, reported and not enforced.
///
/// Each look here shipped before the line it misses was measured, and is
/// not changed to meet it. Each miss is written down with its number and
/// held: the test fails if one is fixed without being taken off this
/// list, and if a new one appears. The person's own look has no entry
/// and may never have one: its own test holds it to every line.
///
/// Keyed by look, then `stage theme` for every severity or
/// `stage theme severity` for one, then the name of the line.
final Map<String, Map<String, Map<String, String>>> _reportedMisses = {
  'standard': {
    'ringing dark none': {
      _busyFillCanvas: '1.12: $_standardBusy',
      _busyFillBar: '1.24: $_standardBusy',
    },
    'ringing dark high': {
      _busyBar:
          '1.00: the off fill (ash) is as dark as the high canvas that backs '
          'the bar in the dark theme, and the quiet wash is at 1.03. The app '
          'rings in critical or none today, never in high.',
      _busyFillCanvas: '1.12: $_standardBusy',
      _busyFillBar: '1.00: $_standardBusy',
      'the fill of "I\'m up" against what is behind it, over the bar '
              'backing':
          '1.92: cobalt on the high canvas that backs the bar in the dark '
          'theme. The app rings in critical or none today, never in high.',
    },
    'ringing dark crit': {
      _busyFillCanvas: '1.12: $_standardBusy',
      _busyFillBar: '1.12: $_standardBusy',
    },
    'ringing light none': {
      _busyFillBar: '1.34: $_standardBusy',
    },
    'acknowledged dark ack': {
      'detail label on its row':
          '4.23: the faint label of a details row on its inset row, dark '
          'theme. The same row and label as everywhere else in the app.',
    },
  },
  'minimal': {
    'ringing dark': _outlinedMisses('17.62', '3.27', '17.62'),
    'ringing light': _outlinedMisses('16.49', '3.49', '16.49'),
  },
  'terminal': {
    'ringing dark': _outlinedMisses('14.01', '3.07', '14.01'),
    'ringing light': _outlinedMisses('14.01', '3.07', '14.01'),
  },
  'red_alert': {
    'ringing dark': _outlinedMisses('11.27', '2.82', '15.68'),
    'ringing light': _outlinedMisses('6.25', '4.25', '8.69'),
  },
  'crit_panic': {
    'ringing dark': _outlinedMisses('11.88', '7.12', '11.88'),
    'ringing light': _outlinedMisses('11.88', '2.06', '11.88'),
  },
};

/// What is on the list for one look, stage, theme and severity.
Map<String, String> _missesOf(
  AlarmStyle style,
  AlarmStage stage,
  Brightness brightness,
  SeverityMode severity,
) {
  final look = _reportedMisses[style.id.id] ?? const {};
  return {
    ...?look['${stage.name} ${brightness.name}'],
    ...?look[_key(stage, brightness, severity)],
  };
}

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
            final known = _missesOf(style, stage, brightness, severity);
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

  test('every miss on the list names a real line and its number, and the '
      'own look is not on it', () {
    expect(_reportedMisses.keys, isNot(contains(AlarmStyleId.own.id)));
    for (final style in alarmStyles) {
      for (final stage in AlarmStage.values) {
        for (final brightness in Brightness.values) {
          for (final severity in _severitiesOf(stage)) {
            final report = alarmStyleContrast(
              style,
              stage,
              brightness: brightness,
              severity: severity,
            );
            final misses = _missesOf(style, stage, brightness, severity);
            for (final MapEntry(key: what, value: why) in misses.entries) {
              final number =
                  report.line(what)?.ratio ?? report.weight(what)?.heavy;
              final where =
                  '${style.id.id} '
                  '${_key(stage, brightness, severity)}: $what';
              expect(number, isNotNull, reason: where);
              expect(
                why,
                startsWith(number!.toStringAsFixed(2)),
                reason: where,
              );
            }
          }
        }
      }
    }
    // Nothing on the list is keyed for a stage and theme that is never
    // measured.
    for (final MapEntry(key: id, value: byWhere) in _reportedMisses.entries) {
      final style = alarmStyles.firstWhere((style) => style.id.id == id);
      for (final where in byWhere.keys) {
        final parts = where.split(' ');
        final stage = AlarmStage.values.byName(parts[0]);
        expect(Brightness.values.map((b) => b.name), contains(parts[1]));
        if (parts.length == 3) {
          expect(
            _severitiesOf(stage).map((s) => s.name),
            contains(parts[2]),
            reason: '${style.id.id} $where',
          );
        }
      }
    }
  });

  test('the fill of "I\'m up" has a floor of its own, which a see-through '
      'quiet button cannot lower', () {
    expect(alarmStyleMinFillContrast, 2);
    for (final style in alarmStyles) {
      final report = alarmStyleContrast(
        style,
        AlarmStage.ringing,
        brightness: Brightness.light,
      );
      for (final where in ['the canvas', 'the bar backing']) {
        expect(
          report.line(
            'the fill of "I\'m up" against what is behind it, over $where',
          ),
          isNotNull,
        );
        expect(
          report
              .line(
                'the fill of "I\'m up" while it spins against what is '
                'behind it, over $where',
              )!
              .min,
          alarmStyleMinFillContrast,
        );
      }
    }
  });

  test('an outlined quiet button is weighed by its stroke, a filled or '
      'washed one by its fill', () {
    const colors = AppColors.light;
    const behind = Color(0xFF202020);
    final outlined = alarmButtonColors(AppButtonVariant.ghost, colors);
    expect(
      alarmQuietButtonWeight(AppButtonVariant.ghost, outlined, behind),
      ColorContrast.contrastRatio(colors.onCanvas, behind),
    );
    final washed = alarmButtonColors(AppButtonVariant.tinted, colors);
    expect(
      alarmQuietButtonWeight(AppButtonVariant.tinted, washed, behind),
      ColorContrast.contrastRatio(
        Color.alphaBlend(washed.fill, behind),
        behind,
      ),
    );
    // A see-through fill is not "no shape": the outline counts.
    expect(
      alarmQuietButtonWeight(AppButtonVariant.ghost, outlined, behind),
      greaterThan(1),
    );
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
