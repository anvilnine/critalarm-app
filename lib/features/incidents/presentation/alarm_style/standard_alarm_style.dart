import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

/// A colour that is never drawn: every style below gets its colour from
/// the stage's palette before it reaches the screen.
const Color _unset = Color(0x00000000);

/// The type the ringing stage has always had. Another look starts from
/// this and changes the lines it wants to.
final AlarmRingingType standardRingingType = AlarmRingingType(
  word: AppTypography.display(_unset),
  topic: const TextStyle(
    fontFamily: AppTypography.fontMono,
    fontFamilyFallback: AppTypography.fontMonoFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: 17,
  ),
  time: const TextStyle(
    fontFamily: AppTypography.fontBody,
    fontFamilyFallback: AppTypography.fontBodyFallbacks,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  ),
  messageTitle: const TextStyle(
    fontFamily: AppTypography.fontDisplay,
    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.2,
  ),
  messageBody: const TextStyle(
    fontFamily: AppTypography.fontBody,
    fontFamilyFallback: AppTypography.fontBodyFallbacks,
    fontSize: 14,
    height: 1.4,
  ),
  messageMeta: const TextStyle(
    fontFamily: AppTypography.fontMono,
    fontFamilyFallback: AppTypography.fontMonoFallbacks,
    fontSize: 12,
  ),
);

/// The type the acknowledged stage has always had.
final AlarmAcknowledgedType standardAcknowledgedType = AlarmAcknowledgedType(
  title: AppTypography.display(_unset),
  line: const TextStyle(
    fontFamily: AppTypography.fontBody,
    fontFamilyFallback: AppTypography.fontBodyFallbacks,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  ),
);

AppColors _severityColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) => base.withSeverity(severity);

AmbientProfile _ringingCanvas(AppColors appColors, Brightness brightness) =>
    AmbientAppProfiles.criticalAlarmRinging(appColors);

AmbientProfile _acknowledgedCanvas(
  AppColors appColors,
  Brightness brightness,
) => AmbientAppProfiles.criticalAlarmAcknowledged(appColors);

/// The edge of the two quiet buttons. In the dark theme the wash is the
/// dark card colour over a dark canvas and cannot be told from it (1.01
/// to 1), so the buttons read as loose text. A faint line in the colour
/// of the words gives them their shape back. The light theme's wash is
/// white on a strong colour and needs none.
Color? _quietButtonEdge(AppColors colors, Brightness brightness) =>
    brightness == Brightness.dark
    ? colors.onCanvas.withValues(alpha: 0.4)
    : null;

/// The look the alarm screen has always had, written as a look. The
/// canvas, the type and the buttons are the ones the screen used before
/// looks existed. The face is the yellow one in both themes, as in every
/// look: in the dark theme it used to be the theme's dark face.
final AlarmStyle standardAlarmStyle = AlarmStyle(
  id: AlarmStyleId.standard,
  nameKey: LocaleKeys.alarm_styles_standard,
  ringing: AlarmRingingLook(
    colors: _severityColors,
    ambient: _ringingCanvas,
    type: standardRingingType,
    quietButtonEdge: _quietButtonEdge,
    // The first shape of the ringing profile is the disc behind the face.
    faceShape: 0,
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _severityColors,
    ambient: _acknowledgedCanvas,
    type: standardAcknowledgedType,
  ),
);
