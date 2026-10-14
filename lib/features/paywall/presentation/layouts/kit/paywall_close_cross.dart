import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The one close control of every paywall: the house bare cross, the same
/// size, the same 48 point tap area and the same spoken label whatever the
/// layout draws under it. The frame places it in a top corner and the intro
/// places its own in the same corner, so a layout never draws a cross.
///
/// The cross has no circle behind it. Where the ground under it would lose
/// it, give it another [color] (see `PaywallFrameController.closeInk`), or
/// move the picture.
class PaywallCloseCross extends StatelessWidget {
  const PaywallCloseCross({
    required this.color,
    required this.onPressed,
    super.key,
  });

  /// How far the 48 point box sits in from the side edge. The cross itself
  /// stands where the layouts have always kept room for it, which is
  /// [PaywallLayoutScope.closeCrossInset] in from the edge inside a 44
  /// point box: the extra tap room is taken out of the inset.
  static const double edgeInset =
      PaywallLayoutScope.closeCrossInset -
      (kMinTapTarget - AppDismissCross.hitSize) / 2;

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppDismissCross(
    label: LocaleKeys.paywall_kit_close.tr(),
    color: color,
    tapSize: kMinTapTarget,
    onPressed: onPressed,
  );
}
