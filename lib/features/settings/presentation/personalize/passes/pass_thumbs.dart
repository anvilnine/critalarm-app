import 'dart:math' as math;

import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/presentation/app_icon_screen.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge/challenge_tile_art.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumb_motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
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

  /// The Wake-up challenge pass: the art of the chosen kind, or the word
  /// "default" in the muted colour when none is chosen.
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

/// The Wake-up challenge thumbnail, still. With a challenge chosen it is the
/// art of that challenge's tile on the Wake-up challenge page, drawn small.
/// With none chosen it is the word "default" in the muted colour.
class PassChallengeThumb extends StatelessWidget {
  const PassChallengeThumb({required this.tone, this.kind, super.key});

  static const double height = 64;

  /// The width the tile art is drawn at before it is scaled down to the 62
  /// point slot. It is a little narrower than a tile on the page, so the sum
  /// and the code stay as large as they can while still clear of the edges.
  static const double _artWidth = 160;

  final PassTone tone;
  final ChallengeKind? kind;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    final mark = kind == null
        ? _DefaultWord(color: tone.valueMuted)
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // The hairline keeps a tile whose ground matches the card, the
            // typed name on the dark card, readable as a picture.
            child: FittedBox(
              child: SizedBox(
                width: _artWidth,
                height: kChallengeArtHeight,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8 * _artWidth / 62),
                    border: Border.all(
                      color: tone.edge,
                      width: _artWidth / 62,
                    ),
                  ),
                  child: ChallengeTileArt(kind: kind),
                ),
              ),
            ),
          );
    // A thumbnail does not grow with the text size.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: SizedBox(
          width: kPassThumbWidth,
          height: height,
          child: Align(alignment: Alignment.topRight, child: mark),
        ),
      ),
    );
  }
}

/// "default", in the mono type, shrunk to fit the slot.
class _DefaultWord extends StatelessWidget {
  const _DefaultWord({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kPassThumbWidth,
    height: 40,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        LocaleKeys.personalize_passes_root_thumb_default.tr(),
        maxLines: 1,
        style: AppTypography.monoBold(color, fontSize: 22),
      ),
    ),
  );
}

/// The home screen widget, small: the yellow face and the red button, and no
/// words. At 62 points a name or a time would be 5 points tall and could not
/// be read, so the picture keeps the two shapes that say what the widget is
/// for: a face that is ringing and a button to answer it.
class WidgetMiniature extends StatelessWidget {
  const WidgetMiniature({required this.size, super.key});

  /// The edge of the picture.
  final double size;

  static const double _face = 40;
  static const double _button = 16;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _YellowFace(size: _face),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.crit,
              borderRadius: BorderRadius.circular(_button / 2),
            ),
            child: const SizedBox(width: double.infinity, height: _button),
          ),
        ],
      ),
    ),
  );
}
