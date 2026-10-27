import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge/challenge_tile_art.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The steps of the loop, in order.
enum ChallengePreviewPhase {
  /// The alarm rings, the challenge is up and the button under it is
  /// locked.
  ringing,

  /// A line runs over the challenge, as the answer is read.
  scanning,

  /// A tick lands on the challenge: it is done.
  found,

  /// The lock on the button opens.
  unlocking,

  /// The alarm has stopped.
  stopped,
}

/// The loop is this many seconds long.
const double challengePreviewLoop = 9;

/// The second a still preview rests on: the alarm ringing behind its
/// locked button, the first challenge waiting. The ring has not started to
/// swell, so the face is upright, and no line is out.
const double challengePreviewRestAt = 0.12;

/// When each step starts, in seconds into the loop.
const challengePreviewPhases = <(ChallengePreviewPhase, double)>[
  (ChallengePreviewPhase.ringing, 0),
  (ChallengePreviewPhase.scanning, 0.7),
  (ChallengePreviewPhase.found, 1.7),
  (ChallengePreviewPhase.unlocking, 2.1),
  (ChallengePreviewPhase.stopped, 2.5),
];

/// The second [phase] starts.
double challengePreviewStart(ChallengePreviewPhase phase) =>
    challengePreviewPhases.firstWhere((entry) => entry.$1 == phase).$2;

/// How long the picture takes to go back to ringing before the loop ends.
const double challengePreviewReset = 0.3;

/// The challenges the loop shows, one for each pass, in this order. They
/// are the pictures the Wake-up challenge shelf draws. The shake is left
/// out: its picture is a face, and the alarm already has one.
const challengePreviewKinds = <ChallengeKind>[
  ChallengeKind.typeTopicName,
  ChallengeKind.opsMath,
  ChallengeKind.typeAlertTitle,
  ChallengeKind.scratchCard,
];

/// The challenge shown on pass [pass] of the loop, counted from zero.
ChallengeKind challengePreviewKindOf(int pass) =>
    challengePreviewKinds[pass % challengePreviewKinds.length];

/// How far the ringing face rocks either way, in radians: three degrees.
const double challengePreviewShake = 3 * math.pi / 180;

/// One frame of the wake-up challenge preview.
@immutable
class ChallengePreviewFrame {
  const ChallengePreviewFrame({
    required this.phase,
    required this.tilt,
    required this.pulse,
    required this.scan,
    required this.scanOpacity,
    required this.found,
    required this.unlock,
    required this.stopped,
    required this.local,
    this.pass = 0,
    this.change = 0,
  });

  final ChallengePreviewPhase phase;

  /// The face's rotation in radians. Zero once the alarm has stopped.
  final double tilt;

  /// How strong the rings around the ringing face are, 0 to 1.
  final double pulse;

  /// Where the line is down the challenge, 0 at its top and 1 at its foot.
  final double scan;

  /// How visible the scan line is, 0 to 1.
  final double scanOpacity;

  /// How far the viewfinder has closed on the code, 0 to 1.
  final double found;

  /// How far the lock has opened, 0 to 1.
  final double unlock;

  /// How far the screen has gone from ringing to stopped, 0 to 1.
  final double stopped;

  /// Seconds into the loop.
  final double local;

  /// How many loops have gone by, counted from zero. It picks the
  /// challenge the screen shows.
  final int pass;

  /// How far the screen has gone over to the next loop's challenge, 0 to 1.
  /// It is 0 for all of the loop but its last moments, which are also when
  /// everything else goes back.
  final double change;
}

/// The frame of the wake-up challenge preview at clock second [t].
ChallengePreviewFrame challengePreviewFrameAt(double t) {
  final local = loopT(t, challengePreviewLoop);
  var current = challengePreviewPhases.first.$1;
  for (final (step, start) in challengePreviewPhases) {
    if (local >= start) current = step;
  }

  final scanStart = challengePreviewStart(ChallengePreviewPhase.scanning);
  final foundAt = challengePreviewStart(ChallengePreviewPhase.found);
  final unlockAt = challengePreviewStart(ChallengePreviewPhase.unlocking);
  final stopAt = challengePreviewStart(ChallengePreviewPhase.stopped);

  // Everything done goes back in the last moment, so the loop starts on
  // the ringing screen without a jump.
  final kept =
      1 -
      phase(
        local,
        challengePreviewLoop - challengePreviewReset,
        challengePreviewLoop,
      );

  // The alarm rings on through the scan: that is the point. It stops only
  // once the lock is open.
  final ringing = phase(local, 0.12, 0.4) * (1 - phase(local, 2.3, stopAt));

  // The line goes down the code and back up, once.
  final sweep = phase(local, scanStart, foundAt);
  final scanOpacity =
      phase(local, scanStart, scanStart + 0.12) *
      (1 - phase(local, foundAt - 0.12, foundAt));

  return ChallengePreviewFrame(
    phase: current,
    tilt: challengePreviewShake * math.sin(2 * math.pi * local) * ringing,
    pulse: ringing,
    scan: 1 - (2 * sweep - 1).abs(),
    scanOpacity: scanOpacity,
    found: phase(local, foundAt, foundAt + 0.3) * kept,
    unlock: phase(local, unlockAt, unlockAt + 0.3) * kept,
    stopped: phase(local, stopAt, stopAt + 0.3) * kept,
    local: local,
    pass: math.max(0, t ~/ challengePreviewLoop),
    change: 1 - kept,
  );
}

/// A wake-up challenge: an alarm whose button stays locked until a
/// challenge is done.
///
/// Small, it is a text box with a caret on the shared tile. As a scene it
/// is one alarm screen in miniature: the ringing face, the picture of a
/// challenge the app draws on its Wake-up challenge shelf, and the locked
/// button under it. A line runs over the challenge, a tick lands on it,
/// the lock opens and the screen goes from ringing to stopped. The next
/// loop shows the next challenge. The red and the blue are the alarm
/// screen's own and stay inside the miniature.
class ChallengePreview extends StatelessWidget {
  const ChallengePreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    if (size.shortestSide < paywallPreviewSceneMinEdge) {
      return PreviewGlyphTile.mark(PreviewMark.challenge, size: size);
    }
    return ExtrasPreviewTile(
      size: size,
      color: context.appColors.cream,
      child: PaywallPreviewClock.seconds(
        restAt: challengePreviewRestAt,
        builder: (context, t) => Center(
          child: _Screen(
            u: size.shortestSide,
            frame: challengePreviewFrameAt(t),
          ),
        ),
      ),
    );
  }
}

/// The alarm screen in miniature.
class _Screen extends StatelessWidget {
  const _Screen({required this.u, required this.frame});

  /// The short side of the tile. Every measure is a share of it.
  final double u;
  final ChallengePreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasWords = u >= paywallPreviewLargeMinEdge;
    final stopped = Curves.easeInOut.transform(frame.stopped);
    final fill = Color.lerp(colors.crit, colors.highlight, stopped)!;
    final ink = Color.lerp(colors.inkFixed, colors.onHighlight, stopped)!;

    final width = u * 0.6;
    final height = u * 0.86;
    final pad = u * 0.05;
    final inner = width - pad * 2;
    final face = u * 0.19;
    final button = u * 0.125;
    final edge = math.max(1.5, u * 0.012);
    final isStopped = frame.stopped >= 0.5;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(u * 0.09),
        border: Border.all(color: colors.ink, width: edge),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: face,
            child: Row(
              mainAxisAlignment: hasWords
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                CustomPaint(
                  painter: _PulsePainter(
                    local: frame.local,
                    strength: frame.pulse,
                    color: colors.inkFixed,
                  ),
                  child: Transform.rotate(
                    angle: frame.tilt,
                    child: FaceWidget(
                      state: isStopped ? FaceState.acked : FaceState.alarmed,
                      size: face,
                    ),
                  ),
                ),
                if (hasWords) ...[
                  SizedBox(width: u * 0.035),
                  Expanded(
                    child: Text(
                      'prod-db', // l10n-ok: a made-up topic name
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: AppTypography.monoBold(
                        ink,
                        fontSize: u * 0.05,
                      ).copyWith(height: 1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _Task(width: inner, frame: frame),
          _StopButton(
            u: u,
            height: button,
            frame: frame,
            hasWords: hasWords,
          ),
        ],
      ),
    );
  }
}

/// The two rings that leave a ringing face, half a beat apart.
class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.local,
    required this.strength,
    required this.color,
  });

  final double local;
  final double strength;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final beat = AppDurations.ring.inMilliseconds / 1000;
    final rect = Offset.zero & size;
    for (final offset in [0.0, 0.5]) {
      final p = AppCurves.easeOut.transform(
        loopT(local + offset * beat, beat) / beat,
      );
      final grown = rect.inflate(size.shortestSide * 0.22 * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          grown,
          Radius.circular(grown.shortestSide * 0.34),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.shortestSide * 0.06)
          ..color = color.withValues(alpha: (1 - p) * strength * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      local != old.local || strength != old.strength || color != old.color;
}

/// The picture of the challenge on the screen, as the Wake-up challenge
/// shelf draws it, with the line that reads it and the tick that says it
/// is done. As the loop ends it gives way to the next challenge.
class _Task extends StatelessWidget {
  const _Task({required this.width, required this.frame});

  final double width;
  final ChallengePreviewFrame frame;

  /// The box the shelf draws a picture in, 175 by 104.
  static const double _artWidth = 175;

  @override
  Widget build(BuildContext context) {
    final height = width * kChallengeArtHeight / _artWidth;
    Widget art(ChallengeKind kind, double opacity) => Opacity(
      opacity: opacity,
      child: FittedBox(
        child: SizedBox(
          width: _artWidth,
          height: kChallengeArtHeight,
          child: ChallengeTileArt(kind: kind),
        ),
      ),
    );

    final colors = context.appColors;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            art(challengePreviewKindOf(frame.pass), 1),
            if (frame.change > 0)
              art(challengePreviewKindOf(frame.pass + 1), frame.change),
            CustomPaint(
              painter: _CheckPainter(
                frame: frame,
                mark: colors.yellow,
                badge: colors.highlight,
                paper: colors.onHighlight,
                tick: colors.onHighlight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is drawn over the challenge: the line that reads it, and the badge
/// with a tick that lands on it once it is done.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.frame,
    required this.mark,
    required this.badge,
    required this.paper,
    required this.tick,
  });

  final ChallengePreviewFrame frame;
  final Color mark;
  final Color badge;
  final Color paper;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & size;

    if (frame.scanOpacity > 0) {
      final y = rect.top + rect.height * frame.scan;
      canvas
        ..drawRect(
          Rect.fromLTRB(rect.left, y - s * 0.3, rect.right, y),
          Paint()..color = mark.withValues(alpha: 0.28 * frame.scanOpacity),
        )
        ..drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          Paint()
            ..color = mark.withValues(alpha: frame.scanOpacity)
            ..strokeWidth = math.max(1.5, s * 0.07)
            ..strokeCap = StrokeCap.round,
        );
    }

    // Done: a ticked badge lands on the challenge.
    final found = AppCurves.easeBack.transform(frame.found);
    if (found > 0) {
      final radius = s * 0.3 * found;
      final center = rect.center;
      canvas
        ..drawCircle(center, radius + s * 0.045, Paint()..color = paper)
        ..drawCircle(center, radius, Paint()..color = badge)
        ..drawPath(
          Path()
            ..moveTo(center.dx - radius * 0.45, center.dy)
            ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.36)
            ..lineTo(center.dx + radius * 0.48, center.dy - radius * 0.34),
          Paint()
            ..color = tick
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.26
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      frame.found != old.frame.found ||
      frame.scan != old.frame.scan ||
      frame.scanOpacity != old.frame.scanOpacity ||
      mark != old.mark ||
      badge != old.badge ||
      paper != old.paper ||
      tick != old.tick;
}

/// The stop button. Locked, it is a quiet capsule with a padlock. The
/// padlock opens, the capsule fills, and once the alarm has stopped it
/// carries a tick.
class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.u,
    required this.height,
    required this.frame,
    required this.hasWords,
  });

  final double u;
  final double height;
  final ChallengePreviewFrame frame;
  final bool hasWords;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final open = AppCurves.easeBack.transform(frame.unlock);
    final isStopped = frame.stopped >= 0.5;
    final fill = Color.lerp(
      colors.inkFixed.withValues(alpha: 0.22),
      isStopped ? colors.onHighlight : colors.inkFixed,
      frame.unlock,
    )!;
    final ink = isStopped
        ? colors.inkFixed
        : Color.lerp(colors.inkFixed, colors.onHighlight, frame.unlock)!;
    // The capsule lands a little past its size as the lock opens.
    final pop = math.sin(math.pi * frame.unlock) * 0.06;

    return Transform.scale(
      scale: 1 + pop,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStopped)
              AppGlyph(
                GlyphType.check,
                size: height * 0.52,
                color: ink,
                strokeWidth: 3.2,
              )
            else
              CustomPaint(
                size: Size.square(height * 0.62),
                painter: _PadlockPainter(open: open, color: ink),
              ),
            if (hasWords) ...[
              SizedBox(width: height * 0.22),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isStopped
                        ? LocaleKeys.paywall_previews_extras_challenge_stopped
                              .tr()
                        : LocaleKeys.paywall_previews_extras_challenge_locked
                              .tr(),
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.title(
                      ink,
                      fontSize: height * 0.42,
                    ).copyWith(height: 1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A padlock whose shackle lifts and swings clear as it opens.
class _PadlockPainter extends CustomPainter {
  const _PadlockPainter({required this.open, required this.color});

  /// 0 shut, 1 open. It may pass 1 for a moment as the shackle springs.
  final double open;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 11, 14, 10),
          const Radius.circular(2.6),
        ),
        Paint()..color = color,
      )
      // The shackle turns about its left leg, which stays in the body.
      ..save()
      ..translate(8, 11 - 2.2 * open)
      ..rotate(-0.6 * open)
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, -3.2)
          ..arcToPoint(const Offset(8, -3.2), radius: const Radius.circular(4))
          ..lineTo(8, 0),
        line,
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_PadlockPainter old) =>
      open != old.open || color != old.color;
}
