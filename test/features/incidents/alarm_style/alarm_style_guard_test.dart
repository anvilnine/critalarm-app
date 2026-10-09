import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/minimal_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal, with one of its functions swapped for one that throws.
AlarmStyle _broken({
  AlarmStageColors? ringingColors,
  AlarmStageAmbient? ringingAmbient,
  AlarmStageColors? acknowledgedColors,
  AlarmStageAmbient? acknowledgedAmbient,
}) => AlarmStyle(
  id: minimalAlarmStyle.id,
  nameKey: minimalAlarmStyle.nameKey,
  ringing: AlarmRingingLook(
    colors: ringingColors ?? minimalAlarmStyle.ringing.colors,
    ambient: ringingAmbient ?? minimalAlarmStyle.ringing.ambient,
    type: minimalAlarmStyle.ringing.type,
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: acknowledgedColors ?? minimalAlarmStyle.acknowledged.colors,
    ambient: acknowledgedAmbient ?? minimalAlarmStyle.acknowledged.ambient,
    type: minimalAlarmStyle.acknowledged.type,
  ),
);

AppColors _throwingColors(AppColors _, SeverityMode _, Brightness _) =>
    throw StateError('colours');

AmbientProfile _throwingAmbient(AppColors _, Brightness _) =>
    throw StateError('canvas');

AlarmStyle _drawable(AlarmStyle style) => drawableAlarmStyle(
  style,
  base: AppColors.light,
  severity: SeverityMode.crit,
  brightness: Brightness.light,
);

class _ThrowsInPaint extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(const Rect.fromLTWH(0, 0, 1, 1));
    throw StateError('paint');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      throw StateError('repaint');
}

class _Paints extends CustomPainter {
  int painted = 0;

  @override
  void paint(Canvas canvas, Size size) => painted++;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _frame = AlarmBackdropFrame(
  stage: AlarmStage.ringing,
  colors: AppColors.light,
  elapsed: Duration.zero,
  isStill: true,
);

void main() {
  group('a look that throws is drawn as the standard look:', () {
    test('every registered look can be drawn', () {
      for (final style in alarmStyles) {
        expect(_drawable(style), same(style), reason: style.id.id);
      }
    });

    test('ringing colours that throw', () {
      expect(
        _drawable(_broken(ringingColors: _throwingColors)),
        same(standardAlarmStyle),
      );
    });

    test('a ringing canvas that throws', () {
      expect(
        _drawable(_broken(ringingAmbient: _throwingAmbient)),
        same(standardAlarmStyle),
      );
    });

    test('the acknowledged stage is checked while the phone still rings, '
        'so the look does not change at "I\'m up"', () {
      expect(
        _drawable(_broken(acknowledgedColors: _throwingColors)),
        same(standardAlarmStyle),
      );
      expect(
        _drawable(_broken(acknowledgedAmbient: _throwingAmbient)),
        same(standardAlarmStyle),
      );
    });
  });

  group('a background that throws paints nothing:', () {
    test('when making the painter throws', () {
      expect(
        guardedAlarmBackdrop((_) => throw StateError('make'), _frame),
        isNull,
      );
    });

    test('when painting throws, and what it left half done is undone', () {
      final painter = guardedAlarmBackdrop((_) => _ThrowsInPaint(), _frame)!;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final saves = canvas.getSaveCount();
      expect(
        () => painter.paint(canvas, const Size(100, 100)),
        returnsNormally,
      );
      expect(canvas.getSaveCount(), saves);
      recorder.endRecording().dispose();
      // A repaint question that throws means "paint again".
      expect(painter.shouldRepaint(painter), isTrue);
    });

    test('a painter that works is painted as it is', () {
      final inner = _Paints();
      final painter = guardedAlarmBackdrop((_) => inner, _frame)!;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(100, 100));
      recorder.endRecording().dispose();
      expect(inner.painted, 1);
    });
  });
}
