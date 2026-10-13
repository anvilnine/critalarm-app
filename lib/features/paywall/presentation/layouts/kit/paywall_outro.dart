import 'dart:ui' as ui;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';
import 'package:flutter/widgets.dart';

export 'package:critalarm/core/paywall/paywall_outro.dart';
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_rules.dart';

// The step between a confirmed purchase and the step after it. The kit
// README has the contract ("Add an outro"). This file is what an outro is
// built on. The host that plays one is in `paywall_thanks.dart`.

/// What an outro draws with.
@immutable
class PaywallOutroScope {
  const PaywallOutroScope({
    required this.clock,
    required this.size,
    required this.padding,
    required this.product,
    required this.land,
    required this.ground,
    required this.words,
    this.wall,
    this.mascot,
  });

  /// Seconds since the purchase was confirmed. It is the host's one clock:
  /// the end state reads it too, through `paywallThanksSecondAfterOutro`.
  final PaywallClock clock;

  /// The whole screen, safe areas included. An outro draws edge to edge.
  final Size size;

  /// The safe areas, to keep words out of.
  final EdgeInsets padding;

  final PaywallProduct product;

  /// The layout as it was painted on the frame the purchase was
  /// confirmed, with its own mascot patched out. Null when the picture
  /// could not be taken. The host owns it and disposes it: an outro never
  /// does.
  final ui.Image? wall;

  /// Where the layout's mascot stood. Null when it had none on screen
  /// (mid entrance, or a layout without one): the outro then starts its
  /// own mascot at the stage.
  final Rect? mascot;

  /// Where the end state's mascot stands at the swap. The outro's mascot
  /// ends exactly here.
  final Rect land;

  /// The end state's background colour. The outro ends on it.
  final Color ground;

  /// The line the outro writes, in the buyer's language.
  final String words;
}

/// Draws an outro for the second its scope's clock reads.
typedef PaywallOutroBuilder =
    Widget Function(BuildContext context, PaywallOutroScope scope);

/// One success outro: how long it takes, when it lets the end state
/// show, and what draws it.
///
/// Second zero is the frame the purchase is confirmed. The buy block plays
/// the purchase cue on that frame, or the outro's [score] in its place, and
/// that sound owns the room until it is over, so the beats of an outro are
/// haptics alone.
@immutable
class PaywallOutro {
  const PaywallOutro({
    required this.seconds,
    required this.uncover,
    required this.builder,
    this.beats = const [],
    this.score,
    this.scoreSeconds = 0,
  });

  /// The swap. The outro is taken away on this second, with its mascot at
  /// `PaywallOutroScope.land`.
  final double seconds;

  /// From here the end state is built and playing under the outro, which
  /// uncovers it.
  final double uncover;

  /// What is felt on the way. Haptics alone.
  final List<PaywallThanksBeat> beats;

  /// The composed piece that plays from the purchase frame, in place of the
  /// purchase cue. Null plays the purchase cue as it always did. It is a
  /// cue with a sound and no haptic: the beats carry those.
  final PaywallCue? score;

  /// How long the file of [score] is, in seconds. It reaches past
  /// [seconds], and the tail rings under the end state. No sound of the end
  /// state may start before it is over: a second sound cuts the first dead.
  /// Zero with no score.
  final double scoreSeconds;

  final PaywallOutroBuilder builder;

  /// Whether the times are in order, no beat makes a sound and a named
  /// score is a cue with a sound that lasts to the swap. A test asks this
  /// of every registered outro.
  bool get isSound =>
      uncover > 0 &&
      uncover < seconds &&
      beats.every((beat) => !beat.isHeard) &&
      paywallThanksBeatsAreSound(beats, seconds: seconds) &&
      _scoreIsSound;

  bool get _scoreIsSound {
    final score = this.score;
    if (score == null) return scoreSeconds == 0;
    return score.sound != null && scoreSeconds >= seconds;
  }
}
