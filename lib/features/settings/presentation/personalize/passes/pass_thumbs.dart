import 'dart:math' as math;

import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/widgets_preview.dart';
import 'package:critalarm/features/settings/presentation/app_icon_screen.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumb_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// The thumbnails on the Personalize root, one per pass, each 62 points wide.
// They are drawn in code from the same parts as the screens they stand for.
// The Look and Sound thumbnails move, on one clock, and the rest stand still
// (the exception written in the motion skill).

/// Owns the one clock the moving thumbnails run on.
///
/// Place it above the stack. It builds [builder] once and ticks a
/// [ValueListenable] of seconds, so only the two moving thumbnails redraw on a
/// tick. The clock stops while the route is covered by a pass page and while
/// the app is not resumed, and holds at zero under reduce motion.
class PassThumbClock extends StatefulWidget {
  const PassThumbClock({required this.builder, super.key});

  final Widget Function(BuildContext context, ValueListenable<double> clock)
  builder;

  @override
  State<PassThumbClock> createState() => _PassThumbClockState();
}

class _PassThumbClockState extends PaywallClockState<PassThumbClock> {
  final _clock = ValueNotifier<double>(0);

  @override
  double get restAt => 0;

  // A tick tells the two thumbnails and rebuilds nothing else.
  @override
  void onTick() => _clock.value = t;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _clock);
}

bool _isStill(BuildContext context) =>
    context.reduceMotion || PaywallStill.of(context);

/// The thumbnails, as the builders a pass card takes.
abstract final class PassThumbs {
  /// The Look pass: a mini phone in the look's ground with a yellow face,
  /// rocking about its bottom centre.
  static WidgetBuilder look({
    required PassTone tone,
    required ValueListenable<double> clock,
  }) =>
      (context) => PassLookThumb(tone: tone, clock: clock);

  /// The Sound pass: eight bars from the sound's peaks.
  static WidgetBuilder sound({
    required PassTone tone,
    required ValueListenable<double> clock,
    List<double>? peaks,
  }) =>
      (context) => PassSoundThumb(tone: tone, clock: clock, peaks: peaks);

  /// The Wake-up challenge pass: the art of the chosen kind, or the first
  /// kind's art at 60% while the challenge is Off.
  static WidgetBuilder challenge({
    required PassTone tone,
    ChallengeKind? kind,
  }) =>
      (context) => PassChallengeThumb(tone: tone, kind: kind);

  /// The Widgets pass: the widget as the phone draws it, small.
  static WidgetBuilder widgets() =>
      (context) => const WidgetMiniature(size: kPassThumbWidth);

  /// The App icon pass: the icon showing now.
  static WidgetBuilder appIcon(AppIcon icon) =>
      (context) => AppIconPreview(icon: icon, size: kPassThumbWidth);
}

/// The Look thumbnail. 62 by 118 points, a phone drawn as a 3 point outline
/// in the text colour, with the face on it. The face is yellow in every
/// theme.
class PassLookThumb extends StatelessWidget {
  const PassLookThumb({required this.tone, required this.clock, super.key});

  static const double height = 118;

  final PassTone tone;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final still = _isStill(context);
    final phone = DecoratedBox(
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.onGround, width: 3),
      ),
      child: const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: _YellowFace(size: 40),
        ),
      ),
    );
    return RepaintBoundary(
      child: SizedBox(
        width: kPassThumbWidth,
        height: height,
        child: still
            ? phone
            : ValueListenableBuilder<double>(
                valueListenable: clock,
                child: phone,
                builder: (context, t, child) => Transform.rotate(
                  angle: passThumbRock(t) * math.pi / 180,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
      ),
    );
  }
}

/// A face that is yellow with an ink outline in light and in dark, the way a
/// face always is.
class _YellowFace extends StatelessWidget {
  const _YellowFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => FaceWidget(
    state: FaceState.alarmed,
    size: size,
    overrideFillColor: AppColors.light.faceFill,
    overrideStrokeColor: AppColors.light.faceStroke,
    overrideInkColor: AppColors.light.faceInk,
  );
}

/// The Sound thumbnail: eight bars in the text colour. They rise and fall on
/// the clock when the sound has real peaks, and are flat and still when it
/// has none.
class PassSoundThumb extends StatelessWidget {
  const PassSoundThumb({
    required this.tone,
    required this.clock,
    this.peaks,
    super.key,
  });

  static const double height = 64;
  static const double _barWidth = 5;

  final PassTone tone;
  final ValueListenable<double> clock;
  final List<double>? peaks;

  @override
  Widget build(BuildContext context) {
    final heights = passBarHeights(peaks);
    final moves = passBarsMove(peaks) && !_isStill(context);
    Widget bars(double t) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < passBarCount; i++)
          SizedBox(
            width: _barWidth,
            height: height * heights[i] * passBarScale(i, t, isStill: !moves),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.onGround,
                borderRadius: BorderRadius.circular(_barWidth / 2),
              ),
            ),
          ),
      ],
    );
    return RepaintBoundary(
      child: SizedBox(
        width: kPassThumbWidth,
        height: height,
        child: moves
            ? ValueListenableBuilder<double>(
                valueListenable: clock,
                builder: (context, t, _) => bars(t),
              )
            : bars(0),
      ),
    );
  }
}

/// The Wake-up challenge thumbnail: a still mark of the chosen challenge.
/// With none chosen it is the first challenge's mark at 60%.
class PassChallengeThumb extends StatelessWidget {
  const PassChallengeThumb({required this.tone, this.kind, super.key});

  static const double height = 64;

  final PassTone tone;
  final ChallengeKind? kind;

  @override
  Widget build(BuildContext context) {
    final shown = kind ?? ChallengeKind.typeTopicName;
    final accent = tone.valueOn;
    final quiet = tone.valueMuted;
    final mark = switch (shown) {
      ChallengeKind.typeTopicName => _MonoMark(
        typed: 'pro',
        rest: 'd-db',
        typedColor: accent,
        restColor: quiet,
      ),
      ChallengeKind.typeAlertTitle => _TitleMark(accent: accent, quiet: quiet),
      ChallengeKind.opsMath => _MonoMark(
        typed: '7+5',
        rest: '=?',
        typedColor: accent,
        restColor: quiet,
      ),
      ChallengeKind.scratchCard => _ScratchMark(accent: accent, quiet: quiet),
      ChallengeKind.shake => const _YellowFace(size: 44),
    };
    return ExcludeSemantics(
      child: SizedBox(
        width: kPassThumbWidth,
        height: height,
        child: Opacity(
          opacity: kind == null ? 0.6 : 1,
          child: Align(alignment: Alignment.topRight, child: mark),
        ),
      ),
    );
  }
}

class _MonoMark extends StatelessWidget {
  const _MonoMark({
    required this.typed,
    required this.rest,
    required this.typedColor,
    required this.restColor,
  });

  final String typed;
  final String rest;
  final Color typedColor;
  final Color restColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kPassThumbWidth,
    height: 40,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: typed,
              style: TextStyle(color: typedColor),
            ),
            TextSpan(
              text: rest,
              style: TextStyle(color: restColor),
            ),
          ],
        ),
        style: AppTypography.monoBold(restColor, fontSize: 22),
        maxLines: 1,
      ),
    ),
  );
}

class _TitleMark extends StatelessWidget {
  const _TitleMark({required this.accent, required this.quiet});

  final Color accent;
  final Color quiet;

  @override
  Widget build(BuildContext context) {
    Widget line(double width, Color color) => Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 8),
        line(54, accent),
        const SizedBox(height: 6),
        line(36, quiet),
      ],
    );
  }
}

class _ScratchMark extends StatelessWidget {
  const _ScratchMark({required this.accent, required this.quiet});

  final Color accent;
  final Color quiet;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kPassThumbWidth,
    height: 40,
    child: CustomPaint(painter: _ScratchPainter(accent, quiet)),
  );
}

class _ScratchPainter extends CustomPainter {
  const _ScratchPainter(this.accent, this.quiet);

  final Color accent;
  final Color quiet;

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas
      ..save()
      ..clipRRect(card);
    final hatch = Paint()
      ..color = quiet
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatch,
      );
    }
    canvas
      ..restore()
      ..drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
  }

  @override
  bool shouldRepaint(_ScratchPainter old) =>
      old.accent != accent || old.quiet != quiet;
}

/// The home screen widget as the phone draws it, small: the same drawing the
/// paywall shows large, scaled down. It holds its resting frame, the ringing
/// widget.
class WidgetMiniature extends StatelessWidget {
  const WidgetMiniature({required this.size, super.key});

  /// The edge of the picture.
  final double size;

  /// The edge the widget is laid out at before it is scaled down: large
  /// enough for it to be drawn as the widget and not as a mark.
  static const double _drawnAt = 132;

  @override
  Widget build(BuildContext context) {
    // The face on the widget is the yellow one in both themes.
    final theme = Theme.of(context);
    final colors = context.appColors.copyWith(
      faceFill: AppColors.light.faceFill,
      faceInk: AppColors.light.faceInk,
      faceStroke: AppColors.light.faceStroke,
    );
    return SizedBox.square(
      dimension: size,
      child: FittedBox(
        child: Theme(
          data: theme.copyWith(
            extensions: [
              ...theme.extensions.values.where((ext) => ext is! AppColors),
              colors,
            ],
          ),
          child: _picture(context),
        ),
      ),
    );
  }

  Widget _picture(BuildContext context) {
    return MediaQuery(
      // A picture of a widget: its words do not follow the text size.
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
        disableAnimations: true,
      ),
      child: const ExcludeSemantics(
        child: IgnorePointer(
          child: WidgetsPreview(size: Size.square(_drawnAt)),
        ),
      ),
    );
  }
}
