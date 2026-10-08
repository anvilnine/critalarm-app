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

/// The look the alarm screen has always had, written as a look. Every
/// value here is the one the screen used before looks existed, so it
/// draws exactly what it drew.
final AlarmStyle standardAlarmStyle = AlarmStyle(
  id: AlarmStyleId.standard,
  nameKey: LocaleKeys.alarm_styles_standard,
  keepsThemeFace: true,
  ringing: AlarmRingingLook(
    colors: _severityColors,
    ambient: AmbientAppProfiles.criticalAlarmRinging,
    type: standardRingingType,
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _severityColors,
    ambient: AmbientAppProfiles.criticalAlarmAcknowledged,
    type: standardAcknowledgedType,
  ),
);
