import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:flutter/material.dart';

/// One turn's picture on the Proof stage: the benefit's own preview, made
/// to wait on its Free frame for the first beat.
///
/// A preview that Free does not have at all waits grey behind a small
/// lock. At the lift the lock goes, the colour comes back and it plays.
/// When nothing may move it is the preview's resting frame, in colour.
class ProofScene extends StatelessWidget {
  const ProofScene({
    required this.scene,
    required this.count,
    required this.size,
    required this.playFrom,
    required this.clock,
    super.key,
  });

  final HeroScene scene;

  /// How many turns the loop has.
  final int count;
  final Size size;

  /// The clock second the loop cues this turn at. Null plays freely.
  final double? playFrom;
  final PaywallClock clock;

  @override
  Widget build(BuildContext context) {
    final preview = scene.preview;
    if (preview == null) return SizedBox.fromSize(size: size);
    final turn = proofTurnFor(preview, count: count);
    final cue = playFrom;

    return PaywallClockBuilder(
      clock: clock,
      builder: (context, t, _) {
        // How far into its turn this picture is. The cue is the turn's
        // start less the script's lead, and it waits when the loop does.
        final seconds = cue == null ? 0.0 : t - cue - turn.script.lead;
        final lock = clock.isStill || cue == null
            ? 0.0
            : proofLockAt(turn, seconds);
        final picture = PaywallPreview(
          preview,
          sizeClass: PaywallPreviewClass.large,
          size: size,
          playFrom: cue == null
              ? null
              : proofCueAt(t, playFrom: cue, from: turn.from),
        );
        if (lock <= 0) return picture;

        return Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturation(1 - lock)),
              child: picture,
            ),
            _LockBadge(amount: lock, size: size.shortestSide * 0.24),
          ],
        );
      },
    );
  }
}

/// A colour matrix that keeps [amount] of the colour: 0 is grey, 1 is
/// unchanged.
List<double> _saturation(double amount) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final keep = amount.clamp(0.0, 1.0);
  final lose = 1 - keep;
  return [
    r * lose + keep, g * lose, b * lose, 0, 0, //
    r * lose, g * lose + keep, b * lose, 0, 0, //
    r * lose, g * lose, b * lose + keep, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// A padlock on an ink disc, in the middle of a locked preview. It grows a
/// little and fades as the lock opens.
class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.amount, required this.size});

  /// How locked, 1 to 0.
  final double amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Opacity(
      opacity: amount.clamp(0, 1),
      child: Transform.scale(
        scale: 1 + 0.25 * (1 - amount),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.onCanvas,
            shape: BoxShape.circle,
            border: Border.all(color: colors.canvas, width: 2),
          ),
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: _PadlockPainter(colors.canvas)),
          ),
        ),
      ),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  const _PadlockPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final centre = size.center(Offset.zero);
    final body = Rect.fromCenter(
      center: centre.translate(0, unit * 0.09),
      width: unit * 0.4,
      height: unit * 0.3,
    );
    final shackle = Rect.fromCenter(
      center: Offset(centre.dx, body.top),
      width: unit * 0.24,
      height: unit * 0.3,
    );
    canvas
      ..drawArc(
        shackle,
        3.14159265,
        3.14159265,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.065
          ..strokeCap = StrokeCap.round,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(unit * 0.06)),
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_PadlockPainter old) => color != old.color;
}
