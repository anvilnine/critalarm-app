// The two states of the connect step, Crit Alarm Cloud and your own server,
// share one layout. This is the arithmetic of how that layout changes from
// one to the other: how the spare room is shared, and how tall the pinned bar
// is part of the way across.
//
// "own" is how far the step has moved from the Cloud state (0) to the own
// server state (1).

/// How the room left over after the fixed parts is shared.
typedef ConnectMorphSplit = ({double hero, double tail});

/// Shares [leftover] between the picture and the empty room under the form.
///
/// In the Cloud state the picture takes all of it, so the card sits at the
/// bottom within reach of the thumb. In the own server state the form sits
/// right under the picture and the room is left under it. Part of the way
/// across, the two share it in proportion.
///
/// [heroBase] is the height the picture keeps whatever the room is: 0 in the
/// Cloud state, its own height in the own server state. The picture is
/// [heroBase] plus its share, so its height moves smoothly in between.
ConnectMorphSplit connectMorphSplit({
  required double own,
  required double leftover,
  required double heroBase,
}) {
  final spare = leftover < 0 ? 0.0 : leftover;
  final t = own.clamp(0.0, 1.0);
  return (hero: heroBase + (1 - t) * spare, tail: t * spare);
}

/// The height of the picture's own base [full] part of the way across.
double connectMorphHeroBase({required double own, required double full}) =>
    full * own.clamp(0.0, 1.0);

/// The height of the buttons in the pinned bar part of the way across, from
/// [cloud] (the toggle and the way out) to [ownServer] (Connect and the
/// toggle).
double connectMorphBarButtons({
  required double own,
  required double cloud,
  required double ownServer,
}) => cloud + (ownServer - cloud) * own.clamp(0.0, 1.0);

/// Whether a switch should be acted out. Only a switch the user asked for
/// plays. A form restored from the last visit comes up already open.
bool connectMorphPlays({
  required bool userAsked,
  required bool reduceMotion,
}) => userAsked && !reduceMotion;

/// How much of each face of the card shows [own] of the way across.
///
/// The Cloud card is gone by the time the switch is under half way, and the
/// own server form comes in after it starts to leave, so the two never print
/// over each other. They meet at the edges only.
({double cloud, double own}) connectMorphFades(double own) {
  final t = own.clamp(0.0, 1.0);
  return (
    cloud: (1 - t / 0.45).clamp(0.0, 1.0),
    own: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
  );
}
