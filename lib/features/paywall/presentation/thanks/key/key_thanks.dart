import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_atmosphere.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/key/key_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/material.dart';

/// Key: the pressed button becomes a key, the mascot turns it in one big
/// lock, the lock falls open and what was bought comes out of it.
const PaywallThanks keyThanks = PaywallThanks(
  seconds: KeyTimeline.end,
  cover: KeyTimeline.cover,
  buttonAt: KeyTimeline.button,
  tone: PaywallTone.surface,
  beats: keyBeats,
  builder: _build,
);

/// What is felt and heard on the way. Under the purchase cue every beat is
/// a haptic alone. The second turn and the fall come after it, so they
/// are cues of the palette, each one short click.
List<PaywallThanksBeat> keyBeats(int lines) => [
  // The mascot has the key.
  const PaywallThanksBeat.tap(KeyTimeline.caught, HapticPattern.light),
  // The first quarter turn, on the peak.
  const PaywallThanksBeat.tap(KeyTimeline.turn, HapticPattern.medium),
  // The shackle springs.
  const PaywallThanksBeat.tap(KeyTimeline.spring, HapticPattern.light),
  // The mascot lands.
  const PaywallThanksBeat.tap(KeyTimeline.landed, HapticPattern.light),
  const PaywallThanksBeat(KeyTimeline.secondTurn, PaywallCue.key),
  const PaywallThanksBeat(KeyTimeline.fall, PaywallCue.lock),
  // Each token lands in its mark.
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(KeyTimeline.tokenLands(i, lines), HapticPattern.tick),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    KeyThanks(scope: scope);

/// Draws the key version for the second its scope's clock reads.
class KeyThanks extends StatelessWidget {
  const KeyThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.surface;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final lines = thanksLines(scope);
    final count = lines.length;
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1);
    final place = KeyStage.of(
      size: scope.size,
      padding: scope.padding,
      lines: count,
      textScale: textScale,
    );
    final stage = place.stage;
    final unit = place.unit;
    final headline = thanksHeadline(scope.product);
    final origin = scope.origin;
    // How wide the widest line is written, to know where its mark is.
    var widest = 0.0;
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: AppTypography.small(
            tone.ink,
            fontSize: stage.lineSize,
          ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
        ),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final centre = Offset(
      (place.body.left + stage.crit.right) / 2,
      place.floor - unit * 0.62,
    );

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - KeyTimeline.end;
        final reach = KeyTimeline.reach(t);
        final lift = KeyTimeline.lift(t, lines: count);
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? stage.crit,
          stage.crit.shift(Offset(-unit * 0.1 * reach, 0)),
          KeyTimeline.travel(t),
        )!;
        final dropped = KeyTimeline.dropped(t);
        final keyhole = place.keyhole(dropped);
        final hand =
            place.hand - Offset(unit * 0.1 * reach, lift * stage.crit.width);
        final thrown = KeyTimeline.thrown(t);
        final seat = KeyTimeline.seat(t);
        final key = t < KeyTimeline.push
            ? Offset.lerp(scope.source, hand, thrown)! -
                  Offset(0, unit * 0.5 * thanksArc(thrown))
            : Offset.lerp(hand, keyhole, seat)!;
        final ring = KeyTimeline.ring(t);
        final pressed = KeyTimeline.pressed(t);

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: KeyTimeline.covered(t),
            ),
            Positioned.fromRect(
              rect: Rect.fromCircle(
                center: centre,
                radius: unit * 0.92 * KeyTimeline.disc(t),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HeroAtmosphereColors.of(context, _tone).disc,
                ),
              ),
            ),
            // One ring leaves the lock as it falls open, and is gone.
            if (ring > 0 && ring < 1)
              Positioned.fromRect(
                rect: Rect.fromCircle(
                  center: centre,
                  radius: unit * (0.92 + 0.5 * ring),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.ink.withValues(alpha: 0.2 * (1 - ring)),
                      width: 3,
                    ),
                  ),
                ),
              ),
            if (KeyTimeline.covered(t) > 0.5)
              Positioned.fill(
                child: CustomPaint(
                  painter: _LockPainter(
                    body: place.body,
                    hang: unit * KeyStage.hang * (1 - dropped),
                    lifted:
                        unit *
                        (0.12 * KeyTimeline.sprung(t) +
                            KeyStage.hang * dropped),
                    angle: KeyTimeline.shake(t),
                    keyhole: keyhole,
                    alpha: phase(KeyTimeline.covered(t), 0.5, 0.9),
                    ink: tone.ink,
                    plate: tone.background,
                    shadow: colors.inkFixed,
                  ),
                ),
              ),
            // The pressed button, drawing in to the key.
            if (origin != null && pressed > 0)
              Positioned.fromRect(
                rect: origin,
                child: Transform.scale(
                  scaleX: pressed,
                  scaleY: 0.3 + 0.7 * pressed,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.cobalt,
                      borderRadius: BorderRadius.circular(origin.height / 2),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _KeyPainter(
                  at: key,
                  unit: unit * KeyTimeline.forge(t),
                  angle: t < KeyTimeline.push
                      ? KeyTimeline.spin(t)
                      : KeyTimeline.turned(t) * math.pi / 2 +
                            KeyTimeline.shake(t),
                  into: seat,
                  fill: colors.yellow,
                  stroke: colors.faceStroke,
                ),
              ),
            ),
            ThanksCrit(
              box: box,
              face: KeyTimeline.face(t),
              lift: lift,
              stretch: KeyTimeline.stretch(t),
              angle: -0.09 * reach,
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              bob: math.max(0, rest),
              shadow: KeyTimeline.travel(t),
            ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: headline,
              lines: lines,
              headlineIn: KeyTimeline.headlineIn(t),
              lineIn: (i) => KeyTimeline.lineIn(t, i),
              lineStrong: (i) => KeyTimeline.held(t, i, count),
              mark: (i) => _Token(
                on: KeyTimeline.held(t, i, count),
                ring: tone.ink,
                fill: colors.yellow,
                ink: colors.faceInk,
              ),
            ),
            // The tokens in the air, from the lock to their lines.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TokensPainter(
                    from: keyhole,
                    to: [
                      for (var i = 0; i < count; i++)
                        place.mark(i, widest: widest, textScale: textScale),
                    ],
                    gone: [
                      for (var i = 0; i < count; i++)
                        KeyTimeline.token(t, i, count),
                    ],
                    arc: unit * 0.3,
                    fill: colors.yellow,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The mark that leads a line: an empty ring while the line is a promise,
/// and a token with a check once it is held.
class _Token extends StatelessWidget {
  const _Token({
    required this.on,
    required this.ring,
    required this.fill,
    required this.ink,
  });

  final double on;
  final Color ring;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    const size = ThanksStage.markSize;
    final pop = AppCurves.easeBack.transform(on.clamp(0, 1).toDouble());
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (on < 1)
            Container(
              width: size - 4,
              height: size - 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ring.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
          if (on > 0)
            Transform.scale(
              scale: 0.7 + 0.3 * pop,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
                child: Opacity(
                  opacity: on.clamp(0, 1).toDouble(),
                  child: AppGlyph(
                    GlyphType.check,
                    size: size * 0.56,
                    color: ink,
                    strokeWidth: 3.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One big padlock: a body with a keyhole plate and a shackle that lifts
/// straight up out of it on one side. It ends upright.
class _LockPainter extends CustomPainter {
  const _LockPainter({
    required this.body,
    required this.hang,
    required this.lifted,
    required this.angle,
    required this.keyhole,
    required this.alpha,
    required this.ink,
    required this.plate,
    required this.shadow,
  });

  /// The body at rest, on the floor.
  final Rect body;

  /// How far over the floor the body is.
  final double hang;

  /// How far the shackle has come up out of the body.
  final double lifted;
  final double angle;
  final Offset keyhole;
  final double alpha;
  final Color ink;
  final Color plate;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    final u = body.width;
    final near = 1 - (hang / u * 3).clamp(0.0, 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(body.center.dx, body.bottom + u * 0.02),
        width: u * 0.86 * near,
        height: u * 0.07,
      ),
      Paint()..color = shadow.withValues(alpha: 0.12 * alpha * near),
    );
    final at = body.shift(Offset(0, -hang));
    canvas
      ..save()
      ..translate(at.center.dx, at.bottom)
      ..rotate(angle)
      ..translate(-at.center.dx, -at.bottom);
    final color = ink.withValues(alpha: alpha);
    final left = at.left + u * 0.26;
    final right = at.left + u * 0.74;
    final top = at.top - u * 0.1 - lifted;
    final legs = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.13
      ..strokeCap = StrokeCap.round;
    // The right leg stays in the body. The left one comes out of it, on
    // the side the mascot does not stand in front of.
    final shackle = Path()
      ..moveTo(right, at.top + u * 0.2)
      ..lineTo(right, top)
      ..arcToPoint(
        Offset(left, top),
        radius: Radius.circular((right - left) / 2),
        clockwise: false,
      )
      ..lineTo(left, at.top + u * 0.05 - lifted);
    canvas
      ..drawPath(shackle, legs)
      ..drawRRect(
        RRect.fromRectAndRadius(at, Radius.circular(u * 0.17)),
        Paint()..color = color,
      )
      ..drawCircle(
        keyhole,
        u * 0.2,
        Paint()..color = plate.withValues(alpha: alpha),
      )
      ..drawCircle(
        keyhole - Offset(0, u * 0.03),
        u * 0.055,
        Paint()..color = color,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: keyhole + Offset(0, u * 0.045),
            width: u * 0.05,
            height: u * 0.13,
          ),
          Radius.circular(u * 0.02),
        ),
        Paint()..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      hang != old.hang ||
      lifted != old.lifted ||
      angle != old.angle ||
      alpha != old.alpha ||
      body != old.body ||
      ink != old.ink;
}

/// The key. From the side it is a round bow with a shaft and two teeth,
/// pointing left. [into] of the way into the keyhole the shaft is gone and
/// the bow is seen from its edge: an upright bar, which a turn lays flat.
class _KeyPainter extends CustomPainter {
  const _KeyPainter({
    required this.at,
    required this.unit,
    required this.angle,
    required this.into,
    required this.fill,
    required this.stroke,
  });

  /// The middle of the bow.
  final Offset at;
  final double unit;
  final double angle;
  final double into;
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (unit <= 0) return;
    final u = unit;
    final r = u * 0.13;
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.035
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()..color = fill;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle);
    final shaft = u * 0.34 * (1 - into);
    if (shaft > u * 0.02) {
      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(-r - shaft, -u * 0.035, -r * 0.6, u * 0.035),
            Radius.circular(u * 0.02),
          ),
        )
        ..addRect(
          Rect.fromLTWH(-r - shaft + u * 0.02, u * 0.03, u * 0.05, u * 0.07),
        );
      if (shaft > u * 0.2) {
        path.addRect(
          Rect.fromLTWH(-r - shaft + u * 0.11, u * 0.03, u * 0.05, u * 0.05),
        );
      }
      canvas
        ..drawPath(path, body)
        ..drawPath(path, line);
    }
    final bow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: 2 * r * (1 - 0.6 * into),
        height: 2 * r,
      ),
      Radius.circular(r * (1 - 0.6 * into)),
    );
    canvas
      ..drawRRect(bow, body)
      ..drawRRect(bow, line);
    if (into < 0.6) {
      canvas.drawCircle(
        Offset(r * 0.3, 0),
        r * 0.28,
        Paint()..color = stroke.withValues(alpha: 1 - into / 0.6),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeyPainter old) =>
      at != old.at ||
      unit != old.unit ||
      angle != old.angle ||
      into != old.into;
}

/// The tokens that are in the air: each leaves the lock, rises a little
/// and comes down on its line's mark.
class _TokensPainter extends CustomPainter {
  const _TokensPainter({
    required this.from,
    required this.to,
    required this.gone,
    required this.arc,
    required this.fill,
  });

  final Offset from;
  final List<Offset> to;

  /// How far each is on its way, 0 to 1. Drawn only in between.
  final List<double> gone;
  final double arc;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < to.length; i++) {
      final p = gone[i];
      if (p <= 0 || p >= 1) continue;
      final at =
          Offset.lerp(from, to[i], Curves.easeIn.transform(p))! -
          Offset(0, arc * thanksArc(p));
      canvas.drawCircle(
        at,
        ThanksStage.markSize / 2 * (0.5 + 0.5 * p),
        Paint()..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_TokensPainter old) => true;
}
