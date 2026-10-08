import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_contrast.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/crit_panic_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/red_alert_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/terminal_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The most a light on the alarm screen may change in one second.
const int _mostChangesASecond = 3;

/// The most times [isOn] changes inside any one second of [over], read
/// every millisecond.
int _mostChangesInASecond(
  bool Function(Duration elapsed) isOn, {
  Duration over = const Duration(seconds: 15),
}) {
  final changes = <int>[];
  var was = isOn(Duration.zero);
  for (var ms = 1; ms <= over.inMilliseconds; ms++) {
    final now = isOn(Duration(milliseconds: ms));
    if (now != was) changes.add(ms);
    was = now;
  }
  var most = 0;
  var from = 0;
  for (var to = 0; to < changes.length; to++) {
    while (changes[to] - changes[from] >= 1000) {
      from++;
    }
    if (to - from + 1 > most) most = to - from + 1;
  }
  return most;
}

AppColors _colors(AlarmStyle style, AlarmStage stage, Brightness brightness) =>
    style.colorsFor(
      stage,
      base: brightness == Brightness.dark ? AppColors.dark : AppColors.light,
      severity: SeverityMode.crit,
      brightness: brightness,
    );

AlarmBackdropFrame _frame(
  AlarmStyle style, {
  AlarmStage stage = AlarmStage.ringing,
  Duration elapsed = Duration.zero,
  bool isStill = false,
  Brightness brightness = Brightness.light,
}) => AlarmBackdropFrame(
  stage: stage,
  colors: _colors(style, stage, brightness),
  // The engine hands a still frame zero. A painter must not need that.
  elapsed: elapsed,
  isStill: isStill,
);

CustomPainter _painter(
  AlarmStyle style, {
  AlarmStage stage = AlarmStage.ringing,
  Duration elapsed = Duration.zero,
  bool isStill = false,
  Brightness brightness = Brightness.light,
}) => style.backdrop!(
  _frame(
    style,
    stage: stage,
    elapsed: elapsed,
    isStill: isStill,
    brightness: brightness,
  ),
);

Duration _ms(int ms) => Duration(milliseconds: ms);

/// The looks that paint a background.
final List<AlarmStyle> _painted = [
  terminalAlarmStyle,
  redAlertAlarmStyle,
  critPanicAlarmStyle,
];

void main() {
  test('the three looks are in the registry, after Minimal, and each '
      'paints a background that moves', () {
    expect(alarmStyles.map((style) => style.id).toList().sublist(2), [
      AlarmStyleId.terminal,
      AlarmStyleId.redAlert,
      AlarmStyleId.critPanic,
    ]);
    expect(alarmStyles.sublist(2), _painted);
    for (final style in _painted) {
      expect(style.backdrop, isNotNull, reason: style.id.id);
      expect(style.backdropMoves, isTrue, reason: style.id.id);
      expect(style.keepsThemeFace, isFalse, reason: style.id.id);
    }
  });

  for (final style in _painted) {
    group('${style.id.id} background:', () {
      test('a still frame is one picture, whatever the clock says', () {
        for (final stage in AlarmStage.values) {
          final rest = _painter(style, stage: stage, isStill: true);
          for (final ms in [1, 16, 250, 450, 899, 1200, 4200, 60000]) {
            final later = _painter(
              style,
              stage: stage,
              isStill: true,
              elapsed: _ms(ms),
            );
            expect(
              later.shouldRepaint(rest),
              isFalse,
              reason: '${stage.name} at $ms ms',
            );
          }
        }
      });

      test('it paints at every size, moving and still, and leaves the '
          'canvas as it found it', () {
        for (final size in const [
          Size(390, 844),
          Size(375, 667),
          Size(1024, 768),
          Size(60, 130),
          Size.zero,
        ]) {
          for (final stage in AlarmStage.values) {
            for (final brightness in Brightness.values) {
              for (final ms in [0, 100, 700, 950, 2100]) {
                for (final isStill in [false, true]) {
                  final recorder = ui.PictureRecorder();
                  final canvas = Canvas(recorder);
                  final saves = canvas.getSaveCount();
                  _painter(
                    style,
                    stage: stage,
                    elapsed: _ms(ms),
                    isStill: isStill,
                    brightness: brightness,
                  ).paint(canvas, size);
                  expect(canvas.getSaveCount(), saves);
                  recorder.endRecording().dispose();
                }
              }
            }
          }
        }
      });

      test('a change of stage that changes the picture is painted', () {
        final ringing = _painter(style, isStill: true);
        final acknowledged = _painter(
          style,
          isStill: true,
          stage: AlarmStage.acknowledged,
          brightness: Brightness.dark,
        );
        // Terminal is the same console on both stages and in both themes.
        expect(
          acknowledged.shouldRepaint(ringing),
          style.id != AlarmStyleId.terminal,
        );
      });
    });
  }

  group('Terminal cursor:', () {
    test('it is on, then off, once every blink', () {
      expect(terminalCursorIsOn(Duration.zero, isStill: false), isTrue);
      expect(terminalCursorIsOn(_ms(699), isStill: false), isTrue);
      expect(terminalCursorIsOn(_ms(700), isStill: false), isFalse);
      expect(terminalCursorIsOn(_ms(1199), isStill: false), isFalse);
      expect(terminalCursorIsOn(_ms(1200), isStill: false), isTrue);
      expect(terminalCursorIsOn(_ms(1200 * 1500 + 800), isStill: false), false);
      expect(terminalCursorOnFor, lessThan(terminalBlinkPeriod));
    });

    test('it never changes more than three times in a second', () {
      final most = _mostChangesInASecond(
        (elapsed) => terminalCursorIsOn(elapsed, isStill: false),
      );
      expect(most, lessThanOrEqualTo(_mostChangesASecond));
      expect(most, 2);
    });

    test('still, it is on and stays on', () {
      for (final ms in [0, 700, 900, 1199, 5000]) {
        expect(terminalCursorIsOn(_ms(ms), isStill: true), isTrue);
      }
    });

    test('the background is painted again only when the cursor changes', () {
      final on = _painter(terminalAlarmStyle);
      expect(
        _painter(terminalAlarmStyle, elapsed: _ms(16)).shouldRepaint(on),
        false,
      );
      expect(
        _painter(terminalAlarmStyle, elapsed: _ms(699)).shouldRepaint(on),
        false,
      );
      final off = _painter(terminalAlarmStyle, elapsed: _ms(700));
      expect(off.shouldRepaint(on), isTrue);
      expect(
        _painter(terminalAlarmStyle, elapsed: _ms(1100)).shouldRepaint(off),
        false,
      );
      // The acknowledged stage is the same console.
      expect(
        _painter(
          terminalAlarmStyle,
          stage: AlarmStage.acknowledged,
        ).shouldRepaint(on),
        isFalse,
      );
    });
  });

  group('Red Alert sweep:', () {
    test('the bar goes from above the top edge to below the bottom one, '
        'downwards, once per sweep', () {
      const perSweep = 126; // 4.2 seconds at 30 places a second.
      expect(
        redAlertSweepPeriod.inMilliseconds * redAlertStepsPerSecond / 1000,
        perSweep,
      );
      expect(redAlertBarCentre(0), -redAlertBarHeight / 2);
      for (var step = 1; step < perSweep; step++) {
        expect(
          redAlertBarCentre(step),
          greaterThan(redAlertBarCentre(step - 1)),
        );
      }
      expect(
        redAlertBarCentre(perSweep - 1),
        lessThan(1 + redAlertBarHeight / 2),
      );
      expect(redAlertBarCentre(perSweep), redAlertBarCentre(0));
      expect(redAlertBarCentre(perSweep * 400 + 7), redAlertBarCentre(7));
    });

    test('it is drawn at 30 places a second and no more', () {
      expect(redAlertSweepStep(Duration.zero), 0);
      expect(redAlertSweepStep(_ms(33)), 0);
      expect(redAlertSweepStep(_ms(34)), 1);
      expect(redAlertSweepStep(_ms(1000)), 30);
      expect(redAlertSweepStep(const Duration(minutes: 30)), 54000);
    });

    test('no point on the screen is lit and unlit more than three times in '
        'a second', () {
      for (final y in [0.0, 0.05, 0.3, 0.5, 0.77, 1.0]) {
        final most = _mostChangesInASecond(
          (elapsed) => redAlertIsLit(y, elapsed),
        );
        expect(most, lessThanOrEqualTo(_mostChangesASecond), reason: '$y');
        // It goes on and off once per sweep.
        expect(most, 2, reason: '$y');
      }
      // A point stays lit for most of a second: a bar, not a flash.
      var lit = 0;
      for (var ms = 0; ms < redAlertSweepPeriod.inMilliseconds; ms++) {
        if (redAlertIsLit(0.5, _ms(ms))) lit++;
      }
      expect(lit, greaterThan(600));
      expect(lit, lessThan(1000));
    });

    test('the background is painted again only when the bar moves a '
        'place', () {
      final first = _painter(redAlertAlarmStyle);
      expect(
        _painter(redAlertAlarmStyle, elapsed: _ms(16)).shouldRepaint(first),
        isFalse,
      );
      expect(
        _painter(redAlertAlarmStyle, elapsed: _ms(34)).shouldRepaint(first),
        isTrue,
      );
    });

    test('still, the bar rests on screen', () {
      expect(redAlertRestCentre, inInclusiveRange(0.1, 0.9));
      expect(
        _painter(redAlertAlarmStyle, isStill: true).shouldRepaint(
          _painter(redAlertAlarmStyle, isStill: true, elapsed: _ms(2000)),
        ),
        isFalse,
      );
    });

    test('acknowledged, nothing moves', () {
      final rest = _painter(redAlertAlarmStyle, stage: AlarmStage.acknowledged);
      for (final ms in [16, 34, 500, 2100, 4200, 9000]) {
        expect(
          _painter(
            redAlertAlarmStyle,
            stage: AlarmStage.acknowledged,
            elapsed: _ms(ms),
          ).shouldRepaint(rest),
          isFalse,
          reason: '$ms ms',
        );
      }
    });
  });

  group('Crit Panic jolt:', () {
    test('one beat is one ring of the pulse ring', () {
      expect(critPanicBeat, AppDurations.ring);
      expect(critPanicJoltFor, lessThan(critPanicBeat));
    });

    test('it is thrown at the start of a beat, eases back, and rests for '
        'the remainder', () {
      double kick(int ms) => critPanicKick(_ms(ms), isStill: false);
      expect(kick(0), 1);
      var last = 1.0;
      for (var ms = 1; ms < critPanicJoltFor.inMilliseconds; ms++) {
        expect(kick(ms), inExclusiveRange(0, 1));
        expect(kick(ms), lessThan(last));
        last = kick(ms);
      }
      for (
        var ms = critPanicJoltFor.inMilliseconds;
        ms < critPanicBeat.inMilliseconds;
        ms++
      ) {
        expect(kick(ms), 0);
      }
      expect(kick(critPanicBeat.inMilliseconds), 1);
      expect(kick(critPanicBeat.inMilliseconds * 2000 + 500), 0);
    });

    test('it never starts or stops more than three times in a second', () {
      final most = _mostChangesInASecond(
        (elapsed) => critPanicKick(elapsed, isStill: false) > 0,
      );
      expect(most, lessThanOrEqualTo(_mostChangesASecond));
      // One jolt a beat: it starts once and stops once, and in the widest
      // second a third change, the start of the next jolt, fits.
      expect(most, 3);
      expect(critPanicBeat.inMilliseconds, greaterThanOrEqualTo(667));
    });

    test('still, the burst is at rest', () {
      for (final ms in [0, 1, 100, 900, 1800]) {
        expect(critPanicKick(_ms(ms), isStill: true), 0);
      }
    });

    test('the background is painted again only during a jolt', () {
      final rest = _painter(critPanicAlarmStyle, elapsed: _ms(300));
      expect(
        _painter(critPanicAlarmStyle, elapsed: _ms(600)).shouldRepaint(rest),
        isFalse,
      );
      expect(
        _painter(critPanicAlarmStyle, elapsed: _ms(899)).shouldRepaint(rest),
        isFalse,
      );
      expect(
        _painter(critPanicAlarmStyle, elapsed: _ms(900)).shouldRepaint(rest),
        isTrue,
      );
      expect(
        _painter(critPanicAlarmStyle, elapsed: _ms(950)).shouldRepaint(rest),
        isTrue,
      );
    });

    test('acknowledged, nothing moves', () {
      final rest = _painter(
        critPanicAlarmStyle,
        stage: AlarmStage.acknowledged,
      );
      for (final ms in [1, 100, 900, 950, 1800]) {
        expect(
          _painter(
            critPanicAlarmStyle,
            stage: AlarmStage.acknowledged,
            elapsed: _ms(ms),
          ).shouldRepaint(rest),
          isFalse,
          reason: '$ms ms',
        );
      }
    });
  });

  group('what a background puts behind the words still lets them read:', () {
    // The contrast test measures the words on the flat canvas. A painted
    // background adds its own colours under them, so each look lists the
    // flat colours it can put there, and the words are measured on each.
    List<Color> tones(AlarmStyle style, AlarmStage stage, AppColors colors) =>
        switch (style.id) {
          AlarmStyleId.terminal => terminalBackdropTones(colors),
          AlarmStyleId.redAlert => redAlertBackdropTones(colors, stage),
          AlarmStyleId.critPanic => critPanicBackdropTones(colors),
          AlarmStyleId.standard || AlarmStyleId.minimal => const [],
        };

    for (final style in _painted) {
      for (final stage in AlarmStage.values) {
        for (final brightness in Brightness.values) {
          test('${style.id.id}, ${stage.name}, ${brightness.name} theme', () {
            final colors = _colors(style, stage, brightness);
            final behind = tones(style, stage, colors);
            expect(behind, isNotEmpty);
            expect(behind.first, colors.canvas);
            final ratios = [
              for (final tone in behind)
                ColorContrast.contrastRatio(colors.onCanvas, tone),
            ];
            // Printed so the numbers are in the test log.
            // ignore: avoid_print
            print(
              '${style.id.id} ${stage.name} ${brightness.name}: words on '
              'each background tone '
              '${ratios.map((r) => r.toStringAsFixed(2)).join(', ')}',
            );
            for (final ratio in ratios) {
              expect(ratio, greaterThanOrEqualTo(alarmStyleMinContrast));
            }
          });
        }
      }
    }
  });
}
