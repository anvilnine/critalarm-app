import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_player.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/widgets.dart';

/// One small pip per turn, following a [HeroPlayer]. The pip of the turn
/// on the stage is longer and fills as the turn plays.
///
/// It is a row drawn from the left edge of the box it is given, 5 points
/// thick and centred in the box's height. Put it in the gap under a stage
/// or under a reel. It comes in with the entrance and is left out of
/// semantics, because the lines say the same thing.
class HeroPips extends StatelessWidget {
  const HeroPips({
    required this.player,
    required this.count,
    required this.color,
    super.key,
  });

  final HeroPlayer player;

  /// How many pips: the number of turns.
  final int count;

  /// The ink of the surface they sit on.
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: PaywallClockBuilder(
      clock: player.clock,
      builder: (context, t, _) => CustomPaint(
        painter: HeroPipsPainter(
          count: count,
          frame: player.frameAt(t),
          show: player.isStill
              ? 1
              : phase(t - player.loop.prelude, 0.5, heroEntranceSeconds),
          color: color,
        ),
      ),
    ),
  );
}

/// Paints the pips for one frame. Plain ink, thick enough to be found at a
/// glance and no louder than that. [HeroPips] is the widget.
class HeroPipsPainter extends CustomPainter {
  const HeroPipsPainter({
    required this.count,
    required this.frame,
    required this.show,
    required this.color,
  });

  final int count;
  final HeroFrame frame;

  /// How far in the pips are during the entrance, 0 to 1.
  final double show;
  final Color color;

  static const double _thick = 5;
  static const double _long = 26;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (show <= 0) return;
    final grow = AppCurves.easeOut.transform(frame.cardEnter);
    final leaving = frame.previous?.index;
    final top = (size.height - _thick) / 2;
    final track = Paint()..color = color.withValues(alpha: 0.3 * show);
    final fill = Paint()..color = color.withValues(alpha: 0.82 * show);

    var x = 0.0;
    for (var i = 0; i < count; i++) {
      final isActive = i == frame.activeIndex;
      // The pip of the benefit that just left shortens as the new one
      // lengthens, so the row keeps its width.
      final stretch = isActive
          ? (leaving == null || leaving == i ? 1.0 : grow)
          : (i == leaving ? 1 - grow : 0.0);
      final width = _thick + (_long - _thick) * stretch;
      final pip = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, width, _thick),
        const Radius.circular(_thick),
      );
      canvas.drawRRect(pip, track);
      if (isActive) {
        canvas
          ..save()
          ..clipRRect(pip)
          ..drawRect(
            Rect.fromLTWH(x, top, width * frame.progress, _thick),
            fill,
          )
          ..restore();
      }
      x += width + _gap;
    }
  }

  @override
  bool shouldRepaint(HeroPipsPainter old) =>
      count != old.count ||
      show != old.show ||
      color != old.color ||
      frame.activeIndex != old.frame.activeIndex ||
      frame.previous?.index != old.frame.previous?.index ||
      frame.cardEnter != old.frame.cardEnter ||
      frame.progress != old.frame.progress;
}
