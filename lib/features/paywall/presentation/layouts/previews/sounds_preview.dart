import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The steps of the loop, in order.
enum SoundsPreviewPhase {
  /// The recorder waits, its line flat.
  idle,

  /// The record button is down and the waveform draws itself.
  recording,

  /// The take becomes a named row at the top of the list of sounds.
  saved,

  /// The row plays back, with no sound.
  playing,

  /// The row rests, ready to play.
  resting,
}

/// The loop is this many seconds long.
const double soundsPreviewLoop = 9;

/// The second a still preview rests on: the recorded sound as a named row
/// with its play mark, first in the list.
const double soundsPreviewRestAt = 7;

/// When each step starts, in seconds into the loop.
const soundsPreviewPhases = <(SoundsPreviewPhase, double)>[
  (SoundsPreviewPhase.idle, 0),
  (SoundsPreviewPhase.recording, 0.6),
  (SoundsPreviewPhase.saved, 2.7),
  (SoundsPreviewPhase.playing, 3.8),
  (SoundsPreviewPhase.resting, 5.8),
];

/// The second [phase] starts.
double soundsPreviewStart(SoundsPreviewPhase phase) =>
    soundsPreviewPhases.firstWhere((entry) => entry.$1 == phase).$2;

/// The seconds the drawn finger lands: on record, on stop, on play. Each
/// comes a tenth of a second before the step it leads to.
const soundsPreviewTaps = <double>[0.5, 2.6, 3.7];

/// How long the row takes to go back to the recorder before the loop ends.
const double soundsPreviewReset = 0.3;

/// How long a bar takes to stand up once the recording reaches it.
const double soundsPreviewBarPop = 0.16;

/// The take, as peaks from 0 to 1: a crow that rises, holds and falls away.
const soundsPreviewPeaks = <double>[
  0.16, 0.3, 0.52, 0.4, 0.7, 0.92, 0.66, 0.84, 1, 0.74, 0.9, 0.6, //
  0.78, 0.5, 0.64, 0.38, 0.5, 0.28, 0.36, 0.2, 0.26, 0.14,
];

/// One frame of the alarm sounds preview.
@immutable
class SoundsPreviewFrame {
  const SoundsPreviewFrame({
    required this.phase,
    required this.peaks,
    required this.recorded,
    required this.saved,
    required this.played,
    required this.press,
    required this.tap,
    required this.tapIndex,
    required this.fade,
  });

  final SoundsPreviewPhase phase;

  /// The bars as drawn now: zero where the recording has not reached.
  final List<double> peaks;

  /// How much of the take is recorded, 0 to 1.
  final double recorded;

  /// How far the take has become a row in the list, 0 to 1.
  final double saved;

  /// How far playback is through the row, 0 to 1. Zero when not playing.
  final double played;

  /// How far the button under the finger is squeezed, 0 to 1.
  final double press;

  /// The drawn finger, and which of [soundsPreviewTaps] it belongs to.
  final ({double size, double opacity}) tap;
  final int tapIndex;

  /// How visible the bars are. They fade as the loop goes round, so the
  /// flat line comes back without a jump.
  final double fade;

  /// The recorder is live: the button is a stop square.
  bool get isRecording => phase == SoundsPreviewPhase.recording;

  bool get isPlaying => phase == SoundsPreviewPhase.playing;
}

/// The frame of the alarm sounds preview at clock second [t].
SoundsPreviewFrame soundsPreviewFrameAt(double t) {
  final local = loopT(t, soundsPreviewLoop);
  var current = soundsPreviewPhases.first.$1;
  for (final (step, start) in soundsPreviewPhases) {
    if (local >= start) current = step;
  }

  final recordAt = soundsPreviewStart(SoundsPreviewPhase.recording);
  final savedAt = soundsPreviewStart(SoundsPreviewPhase.saved);
  final playAt = soundsPreviewStart(SoundsPreviewPhase.playing);
  final restAt = soundsPreviewStart(SoundsPreviewPhase.resting);
  // The last bar is drawn a moment before the stop.
  final recordEnd = soundsPreviewTaps[1] - soundsPreviewBarPop;
  final kept =
      1 -
      phase(local, soundsPreviewLoop - soundsPreviewReset, soundsPreviewLoop);

  final count = soundsPreviewPeaks.length;
  final each = (recordEnd - recordAt) / count;
  final peaks = [
    for (final (i, peak) in soundsPreviewPeaks.indexed)
      peak *
          AppCurves.easeBack.transform(
            phase(
              local,
              recordAt + i * each,
              recordAt + i * each + soundsPreviewBarPop,
            ),
          ),
  ];

  var press = 0.0;
  var tap = (size: 1.0, opacity: 0.0);
  var tapIndex = 0;
  for (final (i, at) in soundsPreviewTaps.indexed) {
    final squeeze = pressAt(local, at);
    if (squeeze > press) {
      press = squeeze;
      tapIndex = i;
    }
    final here = tapAt(local, at);
    if (here.opacity > tap.opacity) {
      tap = here;
      tapIndex = i;
    }
  }

  return SoundsPreviewFrame(
    phase: current,
    peaks: peaks,
    recorded: phase(local, recordAt, recordEnd),
    saved: phase(local, savedAt, savedAt + 0.4) * kept,
    played: current == SoundsPreviewPhase.playing
        ? phase(local, playAt, restAt)
        : 0,
    press: press,
    tap: tap,
    tapIndex: tapIndex,
    fade: kept,
  );
}

/// Your own alarm sound: one is recorded, and it becomes a named sound in
/// the list.
///
/// Small, it is a waveform on the shared tile. As a scene the record
/// button is pressed, the waveform draws itself bar by bar, and the take
/// settles into a row with a play mark, first in the list of sounds. It
/// then plays back. Nothing here makes a sound.
class SoundsPreview extends StatelessWidget {
  const SoundsPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    if (size.shortestSide < paywallPreviewSceneMinEdge) {
      return PreviewGlyphTile.mark(PreviewMark.soundWave, size: size);
    }
    final u = size.shortestSide;
    return ExtrasPreviewTile(
      size: size,
      color: context.appColors.cream,
      child: PaywallPreviewClock.seconds(
        restAt: soundsPreviewRestAt,
        builder: (context, t) => Center(
          child: SizedBox.square(
            dimension: u,
            child: _Scene(u: u, frame: soundsPreviewFrameAt(t)),
          ),
        ),
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({required this.u, required this.frame});

  final double u;
  final SoundsPreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWords = u >= paywallPreviewLargeMinEdge;
    final saved = AppCurves.easeSpring.transform(frame.saved);
    final recorder = 1 - phase(frame.saved, 0, 0.5);

    // The row the take becomes, and the two quiet rows of the list under
    // it.
    final row = Rect.fromLTWH(u * 0.08, u * 0.12, u * 0.84, u * 0.3);
    final play = u * 0.19;
    final playAt = Offset(row.left + u * 0.05, row.center.dy - play / 2);
    final waveLeft = playAt.dx + play + u * 0.05;
    final rowWave = hasWords
        ? Rect.fromLTRB(
            waveLeft,
            row.top + u * 0.15,
            row.right - u * 0.06,
            row.bottom - u * 0.055,
          )
        : Rect.fromLTRB(
            waveLeft,
            row.top + u * 0.07,
            row.right - u * 0.06,
            row.bottom - u * 0.07,
          );

    // The recorder: the waveform wide across the tile, the button under
    // it.
    final recordWave = Rect.fromLTWH(u * 0.12, u * 0.2, u * 0.76, u * 0.3);
    final button = u * 0.26;
    final buttonAt = Offset(u * 0.5 - button / 2, u * 0.62);

    final wave = Rect.lerp(recordWave, rowWave, saved)!;
    final bar = colors.ink;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (i, top) in [u * 0.47, u * 0.69].indexed)
          Positioned(
            left: row.left,
            top: top + u * 0.04 * (1 - _rise(frame.saved, i)),
            width: row.width,
            height: u * 0.17,
            child: Opacity(
              opacity: _rise(frame.saved, i),
              child: _QuietRow(u: u, short: i == 1),
            ),
          ),
        Positioned.fromRect(
          rect: row,
          child: Opacity(
            opacity: phase(frame.saved, 0.2, 0.8),
            child: Transform.scale(
              scale: 0.94 + 0.06 * saved,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(u * 0.07),
                  boxShadow: AppShadows.shadowSm(isDark: isDark),
                ),
              ),
            ),
          ),
        ),
        if (hasWords)
          Positioned(
            left: waveLeft,
            top: row.top + u * 0.05,
            right: u - row.right + u * 0.04,
            child: Opacity(
              opacity: phase(frame.saved, 0.5, 1),
              child: Text(
                LocaleKeys.paywall_previews_extras_sound_name.tr(),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: AppTypography.title(
                  colors.ink,
                  fontSize: u * 0.07,
                ).copyWith(height: 1.1),
              ),
            ),
          ),
        Positioned.fromRect(
          rect: wave,
          child: Opacity(
            opacity: frame.fade,
            child: CustomPaint(
              painter: WaveformBarsPainter(
                peaks: frame.peaks,
                progress: frame.played,
                activeColor: colors.highlight,
                idleColor: bar,
                barGap: math.max(1, u * 0.012),
              ),
            ),
          ),
        ),
        Positioned(
          left: playAt.dx,
          top: playAt.dy,
          child: Opacity(
            opacity: phase(frame.saved, 0.4, 0.9),
            child: _RoundButton(
              diameter: play,
              press: frame.tapIndex == 2 ? frame.press : 0,
              tap: frame.tapIndex == 2 ? frame.tap : null,
              fill: colors.ink,
              child: AppGlyph(
                frame.isPlaying ? GlyphType.stop : GlyphType.play,
                size: play * 0.5,
                color: colors.cream,
              ),
            ),
          ),
        ),
        if (recorder > 0)
          Positioned(
            left: buttonAt.dx,
            top: buttonAt.dy + u * 0.08 * (1 - recorder),
            child: Opacity(
              opacity: recorder,
              child: _RoundButton(
                diameter: button,
                press: frame.tapIndex < 2 ? frame.press : 0,
                tap: frame.tapIndex < 2 ? frame.tap : null,
                fill: colors.surface,
                stroke: colors.ink,
                child: _RecordDot(
                  size: button,
                  isRecording: frame.isRecording,
                  recorded: frame.recorded,
                  color: colors.crit,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// How far in quiet row [index] is: each a little after the one above.
  static double _rise(double saved, int index) => AppCurves.easeOut.transform(
    phase(saved, 0.35 + 0.15 * index, 0.85 + 0.15 * index),
  );
}

/// A round button that is squeezed under the drawn finger.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.diameter,
    required this.press,
    required this.tap,
    required this.fill,
    required this.child,
    this.stroke,
  });

  final double diameter;
  final double press;
  final ({double size, double opacity})? tap;
  final Color fill;
  final Color? stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Transform.scale(
        scale: 1 - 0.12 * press,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: stroke == null
                ? null
                : Border.all(
                    color: stroke!,
                    width: math.max(1.5, diameter * 0.07),
                  ),
          ),
          child: child,
        ),
      ),
      if (tap case final tap?)
        Positioned.fill(
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: ExtrasPreviewTap(tap: tap, diameter: diameter * 0.8),
          ),
        ),
    ],
  );
}

/// The mark in the record button: a dot at rest, a square while it
/// records, with a ring that closes as the take runs.
class _RecordDot extends StatelessWidget {
  const _RecordDot({
    required this.size,
    required this.isRecording,
    required this.recorded,
    required this.color,
  });

  final double size;
  final bool isRecording;
  final double recorded;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RecordDotPainter(
      isRecording: isRecording,
      recorded: recorded,
      color: color,
    ),
  );
}

class _RecordDotPainter extends CustomPainter {
  const _RecordDotPainter({
    required this.isRecording,
    required this.recorded,
    required this.color,
  });

  final bool isRecording;
  final double recorded;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final s = size.shortestSide;
    final mark = Rect.fromCenter(
      center: centre,
      width: s * (isRecording ? 0.3 : 0.46),
      height: s * (isRecording ? 0.3 : 0.46),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        mark,
        Radius.circular(isRecording ? s * 0.07 : s),
      ),
      Paint()..color = color,
    );
    if (!isRecording) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: s * 0.31),
      -math.pi / 2,
      2 * math.pi * recorded,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.06)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RecordDotPainter old) =>
      isRecording != old.isRecording ||
      recorded != old.recorded ||
      color != old.color;
}

/// One of the sounds already in the list: a mark and a line, with no
/// words, so the eye stays on the new one.
class _QuietRow extends StatelessWidget {
  const _QuietRow({required this.u, required this.short});

  final double u;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(u * 0.055),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: u * 0.05),
        child: Row(
          children: [
            Container(
              width: u * 0.085,
              height: u * 0.085,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.ink.withValues(alpha: 0.2),
              ),
            ),
            SizedBox(width: u * 0.05),
            Container(
              width: u * (short ? 0.26 : 0.38),
              height: u * 0.04,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: colors.ink.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
