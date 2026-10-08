import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/minimal_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';

/// Every look this build can draw, in the order the pickers show them.
/// The standard look is first.
///
/// A look added here is checked by the registry test (complete, its id
/// used once) and the contrast test (both stages, both themes) with no
/// edit to either.
final List<AlarmStyle> alarmStyles = List<AlarmStyle>.unmodifiable([
  standardAlarmStyle,
  minimalAlarmStyle,
]);

/// The look for [id]. An id with no look listed draws the standard one.
AlarmStyle alarmStyleOf(AlarmStyleId? id) {
  for (final style in alarmStyles) {
    if (style.id == id) return style;
  }
  return standardAlarmStyle;
}
