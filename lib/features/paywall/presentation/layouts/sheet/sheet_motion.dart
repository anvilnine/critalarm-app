import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

/// Every time in the Sheet layout that is its own, worked out from the
/// clock's one number.
///
/// | From  | What happens |
/// |---|---|
/// | 0     | The scrim comes down. The lit row stays lit. |
/// | 0.12  | The sheet rises and settles. |
/// | 0.5   | The buy block comes in. |
/// | 0.6   | The approved entrance: the mascot pops up over the edge. |
/// | 1.6   | The loop starts on the lead benefit. |
/// | proof | Near the end of the lead's turn the lit row answers. |
abstract final class SheetMotion {
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
