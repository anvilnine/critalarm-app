import 'dart:math' as math;

import 'package:critalarm/core/app_icon/app_icon.dart';

/// How a page of the carousel looks, from how far it is from the centre.
typedef PageLook = ({double scale, double opacity});

/// [distance] is the page's offset from the centred page, in pages (0 when
/// centred, 1 for the next one). Scale falls from 1 to 0.78 and opacity from
/// 1 to 0.5, staying there beyond one page away.
PageLook pageLook(double distance) {
  final d = distance.abs().clamp(0.0, 1.0);
  return (scale: 1 - 0.22 * d, opacity: 1 - 0.5 * d);
}

/// What the one button under the carousel does.
enum IconAction {
  /// An unlocked icon that is not on the home screen yet.
  use,

  /// The icon on the home screen. The button is disabled.
  inUse,

  /// A Pro icon on a device without Pro. Opens the paywall.
  unlock,
}

/// The button's job for [icon], given the plan and the icon in use.
IconAction iconAction(
  AppIcon icon, {
  required bool unlocked,
  required AppIcon current,
}) {
  if (icon.isPro && !unlocked) return IconAction.unlock;
  return icon == current ? IconAction.inUse : IconAction.use;
}

/// The tile size for a carousel [available] logical px wide: 190 on a phone,
/// smaller where the viewport is narrow.
double showcaseTileSize(double available) =>
    math.min(190, math.max(120, available * 0.5));
