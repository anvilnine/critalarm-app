import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:flutter/widgets.dart';

/// How much the system has grown the text: 1 is the default size.
///
/// Read off a 16 point sample, so a phone that scales large text in steps
/// (Android 14 and later) answers for the sizes a screen mostly uses.
double setupTextScaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16;

/// The size of the face on a setup step at the current text size and screen
/// height, or 0 when it should not be drawn. See [setupFaceSizeFor].
double setupFaceSizeOf(BuildContext context, {double base = 80}) =>
    setupFaceSizeFor(
      textScale: setupTextScaleOf(context),
      viewportHeight: MediaQuery.sizeOf(context).height,
      base: base,
    );

/// The smallest a setup title is scaled down to before one of its words may
/// break. Lower than the default, because at the largest system sizes the
/// scale brings it back up.
const double setupTitleMinFontSize = 12;
