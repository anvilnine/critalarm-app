import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:flutter/foundation.dart';

// The rules of the step after a purchase that need no widget, so each one
// has a test. `paywall_thanks.dart` has the contract and the host.

/// Why the step after a purchase is on screen.
enum PaywallThanksKind {
  /// A purchase was confirmed just now. The only kind that gets the show.
  purchase('purchase'),

  /// A restore found the product. A short quiet version: the mascot and
  /// one line.
  restore('restore'),

  /// The product was already held when the paywall opened, or turned out
  /// to be held with no trip to the store. The resting frame, no show.
  owned('owned');

  const PaywallThanksKind(this.wire);

  /// The word analytics carries.
  final String wire;
}

/// What a change of the buy state starts, or null for nothing.
///
/// Only a state that says the product is held starts anything, and only
/// once: a state that was already held starts nothing. So a cancel, a
/// failure, a restore that found nothing and a payment the store is
/// holding all answer null.
///
/// [action] is the trip to the store the buyer last asked for
/// (`PaywallBuyCubit.lastAction`).
PaywallThanksKind? paywallThanksKindFor(
  PaywallBuyState before,
  PaywallBuyState after, {
  required PaywallBuyAction? action,
}) {
  if (after.status != PaywallBuyStatus.done) return null;
  if (before.status == PaywallBuyStatus.done) return null;
  final wasAtStore =
      before.status == PaywallBuyStatus.purchasing ||
      before.status == PaywallBuyStatus.checking;
  if (!wasAtStore) return PaywallThanksKind.owned;
  return action == PaywallBuyAction.restore
      ? PaywallThanksKind.restore
      : PaywallThanksKind.purchase;
}

/// How long the purchase cue (`PaywallCue.bought`) sounds, in seconds. It
/// starts on the frame the purchase is confirmed, which is second zero of
/// the show, and owns the room until it is over: no other sound may start
/// inside it, only a haptic.
const double paywallBoughtCueSeconds = 2.2;

/// The latest second the one button may come on screen.
const double paywallThanksButtonBy = 1.5;

/// The most lines of benefits a product lists.
const int paywallThanksMaxLines = 5;

/// One moment of the show that is felt, and after the purchase cue is
/// over may be heard.
///
/// [PaywallThanksBeat.tap] is a haptic alone, which is what every beat
/// inside the purchase cue is. A beat with a [cue] plays that cue of the
/// palette, sound and haptic together, and belongs after
/// [paywallBoughtCueSeconds]. Nothing here may sound or feel like an
/// alarm: single short beats, no ring.
@immutable
class PaywallThanksBeat {
  const PaywallThanksBeat(this.at, PaywallCue this.cue)
    : haptic = HapticPattern.none;

  /// A haptic with no sound of its own.
  const PaywallThanksBeat.tap(this.at, this.haptic) : cue = null;

  /// Seconds since the purchase was confirmed.
  final double at;

  /// The cue played, or null for a haptic alone.
  final PaywallCue? cue;

  /// The haptic played alone when there is no [cue].
  final HapticPattern haptic;

  /// Whether the beat makes a sound.
  bool get isHeard => cue?.sound != null;

  /// Plays the beat: its cue on [cues], or its haptic alone.
  void play(PaywallCues cues) {
    final cue = this.cue;
    if (cue != null) return cues.play(cue);
    AppHaptics.play(haptic);
  }

  @override
  String toString() => 'PaywallThanksBeat($at, ${cue?.name ?? haptic.name})';
}

/// The beats of [beats] a clock passed going from [from] to [to]: after
/// the first and up to the second. A tap that skips the show moves the
/// clock past the rest, and the caller plays none of what was skipped.
List<PaywallThanksBeat> paywallThanksBeatsBetween(
  List<PaywallThanksBeat> beats,
  double from,
  double to,
) => [
  for (final beat in beats)
    if (beat.at > from && beat.at <= to) beat,
];

/// Whether [beats] may be the beats of a show [seconds] long: in order,
/// inside the show, and silent while the purchase cue sounds.
bool paywallThanksBeatsAreSound(
  List<PaywallThanksBeat> beats, {
  required double seconds,
}) {
  var last = 0.0;
  for (final beat in beats) {
    if (beat.at < last || beat.at > seconds) return false;
    if (beat.isHeard && beat.at < paywallBoughtCueSeconds) return false;
    last = beat.at;
  }
  return true;
}
