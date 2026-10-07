import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// What a paywall surface is painted on. It decides the text colours that
/// read on it, in the light and the dark theme.
enum PaywallTone {
  /// The app's own canvas: yellow in light, near black in dark.
  canvas,

  /// A white card or sheet.
  surface,

  /// The ink panel, as the tab bar and the code blocks are.
  panel,

  /// Cobalt, the acknowledged canvas.
  cobalt,

  /// Red, the critical canvas. Only for a layout that draws a ringing
  /// alarm.
  crit,
}

/// The colours of one [PaywallTone] in the current theme.
@immutable
class PaywallToneColors {
  const PaywallToneColors({
    required this.background,
    required this.ink,
    required this.note,
    required this.muted,
  });

  factory PaywallToneColors.of(BuildContext context, PaywallTone tone) {
    final c = context.appColors;
    return switch (tone) {
      PaywallTone.canvas => PaywallToneColors(
        background: c.canvas,
        ink: c.onCanvas,
        note: c.onCanvasMuted,
        muted: c.onCanvasMuted,
      ),
      PaywallTone.surface => PaywallToneColors(
        background: c.surface,
        ink: c.ink,
        note: c.ink2,
        muted: c.ink3,
      ),
      PaywallTone.panel => PaywallToneColors(
        background: c.panel,
        ink: c.onPanel,
        note: c.onPanelMuted,
        muted: c.onPanelMuted,
      ),
      PaywallTone.cobalt => PaywallToneColors(
        background: c.ackCanvas,
        ink: c.ackText,
        note: c.ackTextMuted,
        muted: c.ackTextMuted,
      ),
      // Muted text on the red is under 4.5:1, so both are the full ink.
      PaywallTone.crit => PaywallToneColors(
        background: c.critCanvas,
        ink: c.onCanvas,
        note: c.onCanvas,
        muted: c.onCanvas,
      ),
    };
  }

  final Color background;

  /// Headings and anything that must be read.
  final Color ink;

  /// A second line that still has to be read: the line under a plan's
  /// price, the own-server promise.
  final Color note;

  /// The legal lines and the links.
  final Color muted;
}

/// The button that reads as the one action on [tone].
AppButtonVariant paywallButtonVariantFor(PaywallTone tone) => switch (tone) {
  PaywallTone.canvas ||
  PaywallTone.surface ||
  PaywallTone.panel ||
  PaywallTone.crit => AppButtonVariant.primary,
  // Cobalt on cobalt would vanish.
  PaywallTone.cobalt => AppButtonVariant.cream,
};
