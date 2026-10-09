import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:flutter/material.dart';

/// The colours of the Look pass for [style]: the ground and the text of that
/// look's own ringing screen.
///
/// The ground is the look's ringing canvas, drawn as it rings for a critical
/// topic, and the text is the colour of the words on it. A look added to
/// `alarmStyles` has a pass colour with no edit here. The value takes the
/// text colour on every look: yellow would fail on the standard look's red.
///
/// The root's card, the Look page and its deck read this one function, so the
/// card and the page it opens into are the same colour. [base] is the palette
/// of the theme in use (`context.appColors`) and [brightness] that theme's
/// brightness.
PassTone lookPassToneFor(
  AlarmStyle style,
  Brightness brightness,
  AppColors base,
) {
  final colors = style.colorsFor(
    AlarmStage.ringing,
    base: base,
    severity: SeverityMode.crit,
    brightness: brightness,
  );
  return PassTone(ground: colors.canvas, onGround: colors.onCanvas);
}
