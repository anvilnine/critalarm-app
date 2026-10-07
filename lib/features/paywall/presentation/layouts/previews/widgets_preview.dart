import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the drawn widget shows, in the order the loop plays it.
enum WidgetsPreviewState { ringing, awake, quiet }

/// The loop is this many seconds long.
const double widgetsPreviewLoop = 12;

/// The second a still preview rests on: the quiet widget.
const double widgetsPreviewRestAt = 9;

/// When each state starts, in seconds into the loop. The widget rings, its
/// button is pressed, it is awake, its button is pressed, it goes quiet and
/// stays quiet for the rest of the loop.
const widgetsPreviewPhases = <(WidgetsPreviewState, double)>[
  (WidgetsPreviewState.ringing, 0),
  (WidgetsPreviewState.awake, 2.6),
  (WidgetsPreviewState.quiet, 5.2),
];

/// The seconds the drawn finger lands on the button. Each press comes a
/// tenth of a second before the state it leads to.
const widgetsPreviewTaps = <double>[2.5, 5.1];

/// How far the ringing face rocks either way, in radians: three degrees.
const double widgetsPreviewShake = 3 * math.pi / 180;

/// One frame of the widgets preview.
@immutable
class WidgetsPreviewFrame {
  const WidgetsPreviewFrame({
    required this.state,
    required this.previous,
    required this.enter,
    required this.tilt,
    required this.pulse,
    required this.press,
    required this.tap,
    required this.seconds,
    required this.local,
  });

  final WidgetsPreviewState state;

  /// The state this one is fading in over.
  final WidgetsPreviewState previous;

  /// How far [state] has faded in, 0 to 1.
  final double enter;

  /// The face's rotation in radians. Zero outside the ring, and zero again
  /// before the button is pressed.
  final double tilt;

  /// How strong the rings behind the ringing face are, 0 to 1.
  final double pulse;

  /// How far the button is squeezed, 0 to 1.
  final double press;

  /// The drawn finger over the button.
  final ({double size, double opacity}) tap;

  /// The running time the widget shows, in seconds.
  final int seconds;

  /// Seconds into the loop.
  final double local;
}

/// The frame of the widgets preview at clock second [t].
WidgetsPreviewFrame widgetsPreviewFrameAt(double t) {
  final local = loopT(t, widgetsPreviewLoop);

  var index = 0;
  for (final (i, (_, start)) in widgetsPreviewPhases.indexed) {
    if (local >= start) index = i;
  }
  final (state, start) = widgetsPreviewPhases[index];
  final count = widgetsPreviewPhases.length;
  final previous = widgetsPreviewPhases[(index + count - 1) % count].$1;

  // The ring swells in after the loop starts and is over before the press,
  // so the face is upright when the finger lands.
  final isRinging = state == WidgetsPreviewState.ringing;
  final firstTap = widgetsPreviewTaps.first;
  final ringing = isRinging
      ? phase(local, 0.12, 0.4) *
            (1 - phase(local, firstTap - 0.4, firstTap - 0.15))
      : 0.0;

  var press = 0.0;
  var tap = (size: 1.0, opacity: 0.0);
  for (final at in widgetsPreviewTaps) {
    press = math.max(press, pressAt(local, at));
    final here = tapAt(local, at);
    if (here.opacity > tap.opacity) tap = here;
  }

  return WidgetsPreviewFrame(
    state: state,
    previous: previous,
    enter: phase(local, start, start + 0.12),
    // One rock each way a second, the alarm screen's own cadence.
    tilt: widgetsPreviewShake * math.sin(2 * math.pi * local) * ringing,
    pulse: ringing,
    press: press,
    tap: tap,
    seconds: 42 + (isRinging ? local.floor() : 2),
    local: local,
  );
}

/// The home screen widget stepping through ringing, awake and quiet, with
/// its button pressed between them.
///
/// Small, it is a face over its button. From [extrasPreviewFullEdge] up it
/// is the topic widget as the home screen draws it: face, state, topic,
/// running time and button.
class WidgetsPreview extends StatelessWidget {
  const WidgetsPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return ExtrasPreviewTile(
      size: size,
      color: context.appColors.cream,
      child: ExtrasPreviewClock(
        restAt: widgetsPreviewRestAt,
        builder: (context, t) {
          final frame = widgetsPreviewFrameAt(t);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (frame.enter < 1)
                Opacity(
                  opacity: 1 - frame.enter,
                  child: _Scene(
                    size: size,
                    state: frame.previous,
                    frame: frame,
                    isFront: false,
                  ),
                ),
              Opacity(
                opacity: frame.enter,
                child: _Scene(
                  size: size,
                  state: frame.state,
                  frame: frame,
                  isFront: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The widget in one state. Two are stacked while one state fades into the
/// next, and only the front one carries the finger.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.size,
    required this.state,
    required this.frame,
    required this.isFront,
  });

  final Size size;
  final WidgetsPreviewState state;
  final WidgetsPreviewFrame frame;
  final bool isFront;

  @override
  Widget build(BuildContext context) {
    final u = size.shortestSide;
    final aspect = size.width / size.height;
    if (u < extrasPreviewFullEdge) return _glance(u, isWide: aspect >= 1.6);
    return aspect >= 1.9 ? _medium(context) : _small(context);
  }

  Widget _face(double edge) => _Face(state: state, frame: frame, size: edge);

  Widget _button(double height, {double? width, bool showsLabel = true}) =>
      _Button(
        state: state,
        frame: frame,
        height: height,
        width: width,
        showsLabel: showsLabel,
        showsTap: isFront,
      );

  /// A face and its button, with no words.
  Widget _glance(double u, {required bool isWide}) {
    final face = _face(u * 0.5);
    final button = _button(u * 0.18, width: u * 0.58, showsLabel: false);
    return Center(
      child: isWide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                face,
                SizedBox(width: u * 0.16),
                button,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                face,
                SizedBox(height: u * 0.09),
                button,
              ],
            ),
    );
  }

  /// The small topic widget: face and state on top, the topic and its
  /// running time under them, the button along the bottom.
  Widget _small(BuildContext context) {
    final u = size.shortestSide;
    final isQuiet = state == WidgetsPreviewState.quiet;
    // A tall tile keeps the widget's own shape, in its middle.
    return Center(
      child: Container(
        height: math.min(size.height, u * 1.05),
        padding: EdgeInsets.all(u * 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _face(u * 0.32),
                const Spacer(),
                _StateWord(state: state, fontSize: u * 0.068),
              ],
            ),
            SizedBox(height: u * 0.05),
            Row(
              children: [
                Expanded(child: _TopicName(fontSize: u * 0.088)),
                if (!isQuiet)
                  _RunningTime(seconds: frame.seconds, fontSize: u * 0.075),
              ],
            ),
            const Spacer(),
            // Quiet has nothing left to press: a tick where the button was.
            Align(
              alignment: Alignment.centerLeft,
              widthFactor: isQuiet ? null : 1,
              child: _button(
                u * 0.21,
                width: isQuiet ? u * 0.21 : size.width - u * 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The medium topic widget: one row of face, words and button.
  Widget _medium(BuildContext context) {
    final h = size.height;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h * 0.16),
      child: Row(
        children: [
          _face(h * 0.5),
          SizedBox(width: h * 0.13),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopicName(fontSize: h * 0.15),
                  SizedBox(height: h * 0.05),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StateWord(state: state, fontSize: h * 0.09),
                      if (state != WidgetsPreviewState.quiet) ...[
                        SizedBox(width: h * 0.06),
                        _RunningTime(
                          seconds: frame.seconds,
                          fontSize: h * 0.1,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: h * 0.1),
          _button(h * 0.36),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.state, required this.frame, required this.size});

  final WidgetsPreviewState state;
  final WidgetsPreviewFrame frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isRinging = state == WidgetsPreviewState.ringing;
    final face = FaceWidget(
      state: switch (state) {
        WidgetsPreviewState.ringing => FaceState.alarmed,
        WidgetsPreviewState.awake => FaceState.acked,
        WidgetsPreviewState.quiet => FaceState.calm,
      },
      size: size,
    );
    if (!isRinging) return face;

    return CustomPaint(
      painter: _PulsePainter(
        local: frame.local,
        strength: frame.pulse,
        color: context.appColors.crit,
      ),
      child: Transform.rotate(angle: frame.tilt, child: face),
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
      final grown = rect.inflate(size.shortestSide * 0.3 * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          grown,
          Radius.circular(grown.shortestSide * 0.34),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.shortestSide * 0.07)
          ..color = color.withValues(alpha: (1 - p) * strength * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      local != old.local || strength != old.strength || color != old.color;
}

/// "Ringing", "Awake" or "Quiet" in the state's own colours, as the home
/// screen widget writes it.
class _StateWord extends StatelessWidget {
  const _StateWord({required this.state, required this.fontSize});

  final WidgetsPreviewState state;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (word, fill, ink) = switch (state) {
      WidgetsPreviewState.ringing => (
        LocaleKeys.paywall_previews_extras_widget_ringing.tr(),
        colors.crit,
        colors.inkFixed,
      ),
      WidgetsPreviewState.awake => (
        LocaleKeys.paywall_previews_extras_widget_awake.tr(),
        colors.highlight,
        colors.onHighlight,
      ),
      WidgetsPreviewState.quiet => (
        LocaleKeys.paywall_previews_extras_widget_quiet.tr(),
        colors.hairline,
        colors.ink3,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.75,
          vertical: fontSize * 0.32,
        ),
        child: Text(
          word.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          style: AppTypography.label(ink, fontSize: fontSize).copyWith(
            letterSpacing: fontSize * 0.06,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TopicName extends StatelessWidget {
  const _TopicName({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'prod-db', // l10n-ok: a made-up topic name, the same in every language
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: AppTypography.monoBold(
        context.appColors.ink,
        fontSize: fontSize,
      ).copyWith(height: 1.2),
    );
  }
}

class _RunningTime extends StatelessWidget {
  const _RunningTime({required this.seconds, required this.fontSize});

  final int seconds;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '0:$seconds',
      maxLines: 1,
      softWrap: false,
      style: AppTypography.mono(
        context.appColors.ink3,
        fontSize: fontSize,
      ).copyWith(height: 1.2),
    );
  }
}

/// The widget's one button: "I'm up" while it rings, "Done" once someone is
/// awake, and a tick where the button was once it is quiet.
class _Button extends StatelessWidget {
  const _Button({
    required this.state,
    required this.frame,
    required this.height,
    required this.showsLabel,
    required this.showsTap,
    this.width,
  });

  final WidgetsPreviewState state;
  final WidgetsPreviewFrame frame;
  final double height;

  /// Null sizes the capsule to its label.
  final double? width;
  final bool showsLabel;
  final bool showsTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isQuiet = state == WidgetsPreviewState.quiet;
    final (fill, ink) = switch (state) {
      WidgetsPreviewState.ringing => (colors.crit, colors.inkFixed),
      WidgetsPreviewState.awake => (colors.highlight, colors.onHighlight),
      WidgetsPreviewState.quiet => (null, colors.ink),
    };

    Widget? label;
    if (isQuiet) {
      // Too small to draw a tick: the empty capsule says it.
      if (height >= 9) {
        label = AppGlyph(
          GlyphType.check,
          size: height * 0.55,
          color: ink,
          strokeWidth: 3,
        );
      }
    } else if (showsLabel) {
      label = Text(
        state == WidgetsPreviewState.ringing
            ? LocaleKeys.paywall_previews_extras_widget_im_up.tr()
            : LocaleKeys.paywall_previews_extras_widget_done.tr(),
        maxLines: 1,
        softWrap: false,
        style: AppTypography.title(
          ink,
          fontSize: height * 0.44,
        ).copyWith(height: 1),
      );
    }

    final capsule = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: showsLabel && !isQuiet ? height * 0.45 : 0,
      ),
      decoration: ShapeDecoration(
        color: fill,
        shape: StadiumBorder(
          side: isQuiet
              ? BorderSide(
                  color: colors.ink.withValues(alpha: 0.42),
                  width: math.max(1, height * 0.07),
                )
              : BorderSide.none,
        ),
      ),
      child: label == null
          ? null
          : FittedBox(fit: BoxFit.scaleDown, child: label),
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.scale(scale: 1 - 0.12 * frame.press, child: capsule),
        if (showsTap)
          Positioned(
            child: ExtrasPreviewTap(
              tap: frame.tap,
              diameter: height * (showsLabel ? 0.9 : 1.5),
            ),
          ),
      ],
    );
  }
}
