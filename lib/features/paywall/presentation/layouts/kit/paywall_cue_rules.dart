import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:flutter/foundation.dart';

// When a layout is heard and felt. A layout writes its moments as a list
// of beats, each a clock second and a cue, and `PaywallCueScore` plays
// them as the clock passes. The rules are here, with no widget in them.

/// Whether a clock that read [before] and now reads [now] has just passed
/// the moment [at]. A cue is played on the frame this turns true, once.
bool paywallReached(double before, double now, double at) =>
    before < at && now >= at;

/// One moment of a layout that is heard or felt: the clock second it
/// happens and the cue played then.
@immutable
class PaywallCueBeat {
  const PaywallCueBeat(this.at, this.cue);

  final double at;
  final PaywallCue cue;

  @override
  bool operator ==(Object other) =>
      other is PaywallCueBeat && other.at == at && other.cue == cue;

  @override
  int get hashCode => Object.hash(at, cue);

  @override
  String toString() => 'PaywallCueBeat($at, ${cue.name})';
}

/// The cues of [beats] a clock passed going from [before] to [now], in the
/// order they are listed.
///
/// - Each plays once: on the tick the clock passes its second.
/// - A clock that stood still or went backwards passed none. One that
///   starts again from zero plays them again.
/// - When nothing may move ([isStill]) none plays: reduce motion keeps the
///   frame's entrance cue and nothing else.
/// - A beat before [quietUntil] is left out. After an intro that is how
///   long the intro's last sound still has the room.
List<PaywallCue> paywallCuesBetween(
  List<PaywallCueBeat> beats,
  double before,
  double now, {
  bool isStill = false,
  double quietUntil = 0,
}) {
  if (isStill || now <= before) return const [];
  return [
    for (final beat in beats)
      if (beat.at >= quietUntil && paywallReached(before, now, beat.at))
        beat.cue,
  ];
}

/// Whether the loop's own moments are heard and felt at clock second [t]:
/// only through the first pass, and never once the hand has taken over. A
/// screen left open does not keep sounding, and a touch has its own cue.
///
/// [entranceEnd] and [period] are the loop's.
bool paywallLoopCues(
  double t, {
  required double entranceEnd,
  required double period,
  required bool touched,
}) => !touched && t >= entranceEnd && t < entranceEnd + period;

/// Whether a change of benefit the loop made by itself is heard.
///
/// [began] is the clock second the turn on stage began and [was] the one
/// seen on the tick before. Only the turns of the first pass count, the
/// first of all is the entrance's and is left out, and so is every turn
/// once the hand has taken over.
bool paywallTurnCues({
  required double began,
  required double? was,
  required double entranceEnd,
  required double period,
  required bool touched,
}) {
  if (touched || was == null || began <= was) return false;
  return began > entranceEnd && began < entranceEnd + period;
}

/// How long after an intro hands over a layout keeps its own entrance
/// quiet, unless the intro says otherwise: the intro's last cue is still
/// sounding.
const double paywallQuietAfterIntro = 0.5;

/// How long the last part of an intro's score takes, in seconds from the
/// reveal: a pickup of 0.4, the chord it lands on, and that chord ringing
/// until it is all but gone. A layout under an intro with a score keeps
/// its own entrance quiet until then, so the intro says
/// `reveal + paywallIntroArrivalSeconds - handover` as its quiet.
const double paywallIntroArrivalSeconds = 1.25;

/// Whether a paywall that is leaving plays the close cue, the small let
/// down sound for a paywall left without buying.
///
/// - Leaving with the product in hand is not a dismissal: after a purchase,
///   a restore that worked, the step after either, or when the product was
///   held before the paywall opened, nothing plays.
/// - A thumbnail ([isMuted]) never plays it, so a picker's tiles can come
///   and go in silence.
bool paywallSaysClose({
  required PaywallBuyStatus status,
  required bool isMuted,
}) => !isMuted && status != PaywallBuyStatus.done;
