import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/crit_panic_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/minimal_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/red_alert_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/terminal_alarm_style.dart';
import 'package:flutter/material.dart';

/// Every look this build can draw, in the order the pickers show them.
/// The standard look is first.
///
/// A look added here is checked by the registry test (complete, its id
/// used once) and the contrast test (both stages, both themes) with no
/// edit to either.
final List<AlarmStyle> alarmStyles = List<AlarmStyle>.unmodifiable([
  standardAlarmStyle,
  minimalAlarmStyle,
  terminalAlarmStyle,
  redAlertAlarmStyle,
  critPanicAlarmStyle,
]);

/// The look for [id]. An id with no look listed draws the standard one.
AlarmStyle alarmStyleOf(AlarmStyleId? id) {
  for (final style in alarmStyles) {
    if (style.id == id) return style;
  }
  return standardAlarmStyle;
}

/// [style] when it can be drawn, else the standard look.
///
/// A look is data with a few functions in it. One that throws must never
/// take the alarm screen down, so the owner of an alarm screen asks this
/// before it draws: it runs the look's colours and its canvas for both
/// stages with the values the screen is about to use, and a look that
/// throws on any of them is swapped whole for the standard one, so the
/// canvas, the colours and the buttons still belong together.
AlarmStyle drawableAlarmStyle(
  AlarmStyle style, {
  required AppColors base,
  required SeverityMode severity,
  required Brightness brightness,
}) {
  if (identical(style, standardAlarmStyle)) return style;
  try {
    for (final stage in AlarmStage.values) {
      style.colorsFor(
        stage,
        base: base,
        severity: severity,
        brightness: brightness,
      );
      style.lookOf(stage).ambient(base, brightness);
    }
    return style;
  } on Object catch (_) {
    return standardAlarmStyle;
  }
}
