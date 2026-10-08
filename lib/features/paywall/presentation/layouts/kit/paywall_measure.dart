import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How tall [text] is in [style], [width] wide, at the text size under
/// [context]. For a layout that has to know what fits before it draws.
double paywallTextHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(0, width));
  final height = painter.height;
  painter.dispose();
  return height;
}
