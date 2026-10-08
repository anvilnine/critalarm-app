import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

/// Every time in the Sheet layout that is its own, worked out from the
/// clock's one number.
///
/// | From  | What happens |
/// |---|---|
/// | 0     | The scrim comes down. The lit row stays lit. |
/// | 0.12  | The sheet rises, and carries the mascot up on its edge. |
/// | 0.5   | The buy block comes in. |
/// | 0.56  | The sheet lands. The mascot is bumped into a hop. |
/// | 0.6   | The approved entrance for the preview and the words. |
/// | 1.6   | The loop starts on the lead benefit. |
/// | proof | Near the end of the lead's turn the lit row answers. |
///
/// The mascot comes on with the sheet: it stands astride the sheet's top
/// edge, so the first of it over the foot of the screen is its eyes.
abstract final class SheetMotion {
  /// How the stage in the sheet moves. Bubbles rise up the sheet, as the
  /// sheet rose. The mascot looks over the foot of the screen first and
  /// leans toward the preview while it waits. The preview changes with the
  /// approved fade.
  static const HeroMotion stage = HeroMotion(
    atmosphere: HeroAtmosphereStyle.bubbles,
    entrance: HeroEntranceStyle.peek,
    idle: HeroIdleStyle.lean,
  );

  /// After an intro the preview and the words come with the sheet: the
  /// intro has already been the wait.
  static const double preludeAfterIntro = 0.2;

  /// The loop's prelude, alone or after an intro.
  static double preludeFor({required bool followsIntro}) =>
      followsIntro ? preludeAfterIntro : prelude;

  /// The second the sheet reaches its seat, how long the mascot's hop off
  /// it lasts, and how high it goes against the hop of a reaction.
  static const double landAt = 0.56;
  static const double landSeconds = 0.4;
  static const double landHopHeight = 1.3;

  /// How high the mascot is in the hop the landing gives it, 0 to
  /// [landHopHeight]. It is level before the sheet lands and after.
  static double landingHop(double t) {
    final p = phase(t, landAt, landAt + landSeconds);
    return landHopHeight * 4 * p * (1 - p);
  }

  /// Whether the lit row's answer is felt and heard at clock second [t]:
  /// only through the loop's first pass, and never once the hand has taken
  /// over. A sheet left open does not keep tapping.
  static bool cuesAt(
    double t, {
    required double entranceEnd,
    required double period,
    required bool touched,
  }) => !touched && t >= entranceEnd && t < entranceEnd + period;

  /// How long the sheet has to itself before the approved entrance starts:
  /// the loop's `prelude`.
  static const double prelude = 0.6;

  /// The second a still sheet rests on: every entrance is over and the row
  /// behind still shows the limit the user hit.
  static const double restAt = prelude + heroEntranceSeconds;

  /// The buy block comes in from this second, as the sheet lands.
  static const double buyBlockAt = 0.5;

  /// How long the lit row takes to answer.
  static const double proofSeconds = 0.3;

  /// How dark the scrim is, 0 to 1 of its full strength.
  static double scrim(double t) =>
      AppCurves.easeOut.transform(phase(t, 0, 0.5));

  /// How far up the sheet is: 0 below the screen, 1 in its seat. It passes
  /// 1 a little before it settles.
  static double rise(double t) =>
      AppCurves.easeSpring.transform(phase(t, 0.12, 0.82));

  /// The second of the lead's turn at which the lit row answers: when the
  /// feature has done its job on the stage and the mascot hops. A script
  /// with no such beat answers 70 percent of the way through.
  static double proofAt(HeroScript script) {
    for (final beat in script.beats.reversed) {
      if (beat.isReaction) return beat.at;
    }
    return script.seconds * 0.7;
  }

  /// How far the lit row has answered, 0 to 1: 0 is the limit the user
  /// hit, 1 is the limit lifted.
  ///
  /// The lead is turn 0 of the loop. While it plays, the row waits for
  /// [proofAt]. While another benefit plays, the row stays answered. When
  /// the lead comes round again the row shows the limit again and answers
  /// again. When nothing may move it is the limit, always.
  static double proof({
    required int activeIndex,
    required double sceneSeconds,
    required HeroScript lead,
    required bool isStill,
  }) {
    if (isStill) return 0;
    if (activeIndex != 0) return 1;
    final at = proofAt(lead);
    return phase(sceneSeconds, at, at + proofSeconds);
  }

  /// [proof] for one frame of a loop whose first turn is the lead.
  static double proofFor(
    HeroLoop loop,
    HeroFrame frame, {
    bool isStill = false,
  }) {
    if (loop.scenes.isEmpty || frame.entrance < 1) return 0;
    return proof(
      activeIndex: frame.activeIndex,
      sceneSeconds: frame.sceneSeconds,
      lead: loop.scenes.first.script,
      isStill: isStill,
    );
  }
}
