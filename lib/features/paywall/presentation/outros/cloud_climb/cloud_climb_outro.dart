import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/widgets.dart';

typedef _T = CloudClimbTimeline;

/// Cloud climb: a cloud puffs up under the mascot, the paywall falls away
/// as the ground, and he sleeps while the cloud floats up through the
/// night. The moon comes down to meet him and fills the screen. He wakes
/// and the end state takes over. One continuous climb, no cuts.
const PaywallOutro cloudClimb = PaywallOutro(
  seconds: CloudClimbTimeline.end,
  uncover: CloudClimbTimeline.uncover,
  beats: cloudClimbBeats,
  builder: _build,
);

/// Four light taps, felt and not heard.
const List<PaywallThanksBeat> cloudClimbBeats = [
  PaywallThanksBeat.tap(0, HapticPattern.light),
  PaywallThanksBeat.tap(1.25, HapticPattern.light),
  PaywallThanksBeat.tap(2.6, HapticPattern.light),
  PaywallThanksBeat.tap(3.6, HapticPattern.light),
];

Widget _build(BuildContext context, PaywallOutroScope scope) =>
    CloudClimb(scope: scope);

/// Draws the Cloud climb for the second its scope's clock reads.
class CloudClimb extends StatelessWidget {
  const CloudClimb({required this.scope, super.key});

  final PaywallOutroScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = scope.size;
    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final box = _T.critBox(
          t,
          size: size,
          mascot: scope.mascot,
          land: scope.land,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // Everything under him fades out over the hand over, so the end
            // state shows through. He stays whole until the swap.
            Opacity(
              opacity: 1 - _T.fadeOut(t),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _layer(
                    CloudClimbGroundPainter(
                      t,
                      ground: scope.ground,
                      wall: scope.wall,
                    ),
                  ),
                  _layer(
                    CloudClimbSkyPainter(
                      t,
                      night: colors.panel,
                      star: colors.canvasAlt,
                      cream: colors.cream,
                    ),
                  ),
                  _words(context, t, colors.cream),
                  _layer(
                    CloudClimbMoonPainter(
                      t,
                      ground: scope.ground,
                      ring: colors.canvasAlt,
                    ),
                  ),
                ],
              ),
            ),
            _layer(CloudClimbTrailPainter(t, box: box, color: colors.cream)),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ThanksCrit(
                  box: box,
                  face: _T.face(t),
                  stretch: _T.stretch(t),
                  angle: _T.angle(t),
                  shadow: 0,
                ),
              ],
            ),
            _layer(
              CloudClimbCloudPainter(
                t,
                box: box,
                cloud: colors.cream,
                ground: scope.ground,
                ink: colors.inkFixed,
                dots: colors.yellow,
              ),
            ),
            _layer(CloudClimbNearPainter(t, color: colors.cream)),
          ],
        );
      },
    );
  }

  Widget _layer(CustomPainter painter) => RepaintBoundary(
    child: CustomPaint(painter: painter, size: Size.infinite),
  );

  Widget _words(BuildContext context, double t, Color color) {
    final alpha = _T.wordsAlpha(t);
    if (alpha <= 0) return const SizedBox.shrink();
    final (first, second) = _T.splitWords(scope.words);
    final style = TextStyle(
      fontFamily: AppTypography.fontDisplay,
      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -1.3,
      color: color,
    );
    final drop = _T.wordsDrop(t);
    return Positioned.fill(
      child: RepaintBoundary(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Opacity(
            opacity: alpha,
            child: Stack(
              children: [
                for (final (row, y) in [(first, 110.0), (second, 158.0)])
                  if (row.isNotEmpty)
                    Positioned(
                      left: 64,
                      right: 16,
                      top: y - 36 + drop,
                      child: Text(
                        row,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: style,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
