import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/lights/lights_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/material.dart';

/// Lights on: the screen goes dark from the button, the mascot pulls a
/// cord and a lamp comes on over it, and each line lights up like a bulb
/// on a sign.
const PaywallThanks lightsThanks = PaywallThanks(
  seconds: LightsTimeline.end,
  cover: LightsTimeline.cover,
  buttonAt: LightsTimeline.button,
  tone: PaywallTone.panel,
  beats: lightsBeats,
  builder: _build,
);

/// What is felt and heard on the way. Under the purchase cue the tug is a
/// haptic alone. The second tug and the bulbs come after it, so they are
/// cues of the palette: one click with a warm chord, then one small note
/// a bulb.
List<PaywallThanksBeat> lightsBeats(int lines) => [
  // The first tug, on the peak.
  const PaywallThanksBeat.tap(LightsTimeline.pull, HapticPattern.medium),
  // The mascot lands.
  const PaywallThanksBeat.tap(LightsTimeline.land, HapticPattern.light),
  const PaywallThanksBeat(LightsTimeline.pullAgain, PaywallCue.cord),
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat(LightsTimeline.bulbAt(i, lines), PaywallCue.bulb),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    LightsThanks(scope: scope);

/// Draws the lights version for the second its scope's clock reads.
class LightsThanks extends StatelessWidget {
  const LightsThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.panel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final lines = thanksLines(scope);
    final count = lines.length;
    final place = LightsStage.of(
      size: scope.size,
      padding: scope.padding,
      lines: count,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final stage = place.stage;
    final headline = thanksHeadline(scope.product);

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - LightsTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? stage.crit,
          stage.crit,
          LightsTimeline.travel(t),
        )!;
        final lit = LightsTimeline.lit(t);
        final lamp = LightsTimeline.lamp(t);
        // The lamp comes down from above the screen.
        final shade = place.shade.shift(
          Offset(0, -(place.shade.bottom + 8) * (1 - lamp)),
        );
        final dark = LightsTimeline.dark(t);

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: LightsTimeline.covered(t),
            ),
            if (lit > 0)
              Positioned.fill(
                child: CustomPaint(
                  painter: _LightPainter(
                    shade: shade,
                    floor: place.floor,
                    edge: place.edge,
                    lit: lit * (1 + 0.5 * LightsTimeline.flare(t)),
                    glow: colors.yellow,
                  ),
                ),
              ),
            ThanksCrit(
              box: box,
              face: LightsTimeline.face(t),
              lift: LightsTimeline.lift(t, lines: count),
              stretch: LightsTimeline.stretch(t),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              bob: math.max(0, rest),
              shadow: LightsTimeline.travel(t) * lit,
            ),
            // The dark: over the paywall as the cover grows and over the
            // mascot until the lamp is on.
            if (dark > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: tone.background.withValues(alpha: 0.6 * dark),
                  ),
                ),
              ),
            if (lamp > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LampPainter(
                      shade: shade,
                      knob:
                          place.knob +
                          Offset(
                            0,
                            shade.bottom -
                                place.shade.bottom +
                                place.edge * 0.14 * LightsTimeline.tug(t),
                          ),
                      edge: place.edge,
                      lit: lit,
                      on: tone.ink,
                      off: tone.muted,
                      glow: colors.yellow,
                    ),
                  ),
                ),
              ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: headline,
              lines: lines,
              headlineIn: LightsTimeline.headlineIn(t),
              lineIn: (i) => LightsTimeline.lineIn(t, i),
              lineStrong: (i) => LightsTimeline.bulb(t, i, count),
              mark: (i) => CustomPaint(
                size: const Size.square(ThanksStage.markSize),
                painter: _BulbPainter(
                  on: LightsTimeline.bulb(t, i, count),
                  off: tone.muted,
                  glow: colors.yellow,
                  glint: colors.onHighlight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The light the lamp throws: a cone from the shade to the floor and a
/// pool on the floor the mascot stands in.
class _LightPainter extends CustomPainter {
  const _LightPainter({
    required this.shade,
    required this.floor,
    required this.edge,
    required this.lit,
    required this.glow,
  });

  final Rect shade;
  final double floor;
  final double edge;

  /// 0 to 1, and a little over one in a flare.
  final double lit;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = shade.center.dx;
    final foot = floor + edge * 0.06;
    final cone = Path()
      ..moveTo(shade.left + edge * 0.04, shade.bottom)
      ..lineTo(shade.right - edge * 0.04, shade.bottom)
      ..lineTo(cx + edge * 0.9, foot)
      ..lineTo(cx - edge * 0.9, foot)
      ..close();
    canvas
      ..drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              glow.withValues(alpha: (0.26 * lit).clamp(0, 1)),
              glow.withValues(alpha: (0.07 * lit).clamp(0, 1)),
            ],
          ).createShader(Rect.fromLTRB(0, shade.bottom, size.width, foot)),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(cx, foot),
          width: edge * 1.8,
          height: edge * 0.3,
        ),
        Paint()..color = glow.withValues(alpha: (0.2 * lit).clamp(0, 1)),
      );
  }

  @override
  bool shouldRepaint(_LightPainter old) =>
      lit != old.lit || shade != old.shade || floor != old.floor;
}

/// The lamp: a wire from the top of the screen, a shade, the bulb under
/// it, and the pull cord with its knob.
class _LampPainter extends CustomPainter {
  const _LampPainter({
    required this.shade,
    required this.knob,
    required this.edge,
    required this.lit,
    required this.on,
    required this.off,
    required this.glow,
  });

  final Rect shade;

  /// The middle of the cord's knob.
  final Offset knob;
  final double edge;
  final double lit;
  final Color on;
  final Color off;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = shade.center.dx;
    final dim = off.withValues(alpha: 0.55);
    final wire = Paint()
      ..color = dim
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(cx, 0), Offset(cx, shade.top + 2), wire)
      // The cord, from under the shade to its knob.
      ..drawLine(
        Offset(knob.dx, shade.bottom - 2),
        knob,
        wire..strokeWidth = 2,
      );
    final bulb = edge * 0.12;
    canvas.drawCircle(
      Offset(cx, shade.bottom - bulb * 0.2),
      bulb,
      Paint()..color = Color.lerp(dim, glow, lit.clamp(0, 1))!,
    );
    final top = shade.width * 0.36;
    final radius = edge * 0.05;
    final cap = Path()
      ..moveTo(cx - top / 2 + radius, shade.top)
      ..lineTo(cx + top / 2 - radius, shade.top)
      ..quadraticBezierTo(
        cx + top / 2,
        shade.top,
        cx + top / 2 + radius * 0.5,
        shade.top + radius,
      )
      ..lineTo(shade.right, shade.bottom - radius)
      ..quadraticBezierTo(
        shade.right + radius * 0.3,
        shade.bottom,
        shade.right - radius,
        shade.bottom,
      )
      ..lineTo(shade.left + radius, shade.bottom)
      ..quadraticBezierTo(
        shade.left - radius * 0.3,
        shade.bottom,
        shade.left,
        shade.bottom - radius,
      )
      ..lineTo(cx - top / 2 - radius * 0.5, shade.top + radius)
      ..quadraticBezierTo(
        cx - top / 2,
        shade.top,
        cx - top / 2 + radius,
        shade.top,
      )
      ..close();
    canvas
      ..drawPath(
        cap,
        Paint()
          ..color = Color.lerp(
            off.withValues(alpha: 0.4),
            on,
            lit.clamp(0, 1),
          )!,
      )
      ..drawCircle(
        knob,
        edge * 0.045,
        Paint()..color = Color.lerp(dim, on, lit.clamp(0, 1))!,
      );
  }

  @override
  bool shouldRepaint(_LampPainter old) =>
      lit != old.lit || shade != old.shade || knob != old.knob;
}

/// The bulb that leads a line of the sign. Off, it is a small dim glass.
/// On, it is lit with a soft halo round it.
class _BulbPainter extends CustomPainter {
  const _BulbPainter({
    required this.on,
    required this.off,
    required this.glow,
    required this.glint,
  });

  /// 0 to 1.
  final double on;
  final Color off;
  final Color glow;
  final Color glint;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final centre = size.center(Offset.zero);
    final lit = on.clamp(0.0, 1.0);
    final pop = AppCurves.easeBack.transform(lit);
    if (lit > 0) {
      canvas.drawCircle(
        centre,
        s * 0.78 * pop,
        Paint()..color = glow.withValues(alpha: 0.2 * lit),
      );
    }
    canvas
      ..drawCircle(
        centre,
        s * (0.3 + 0.06 * pop),
        Paint()..color = Color.lerp(off.withValues(alpha: 0.2), glow, lit)!,
      )
      ..drawCircle(
        centre,
        s * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = off.withValues(alpha: 0.5 * (1 - lit)),
      );
    if (lit > 0) {
      canvas.drawCircle(
        centre - Offset(s * 0.1, s * 0.1),
        s * 0.07,
        Paint()..color = glint.withValues(alpha: 0.75 * lit),
      );
    }
  }

  @override
  bool shouldRepaint(_BulbPainter old) => on != old.on || off != old.off;
}
