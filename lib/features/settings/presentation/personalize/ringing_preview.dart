import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/incidents/presentation/widgets/ringing_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The made-up alarm the preview rings: a sample topic and message, in the
/// words the real screen uses for a critical alarm. It names no incident,
/// so nothing on it can reach one.
CriticalAlarmState sampleRingingState({required bool isLive}) =>
    CriticalAlarmState(
      status: CriticalAlarmStatus.ringing,
      topic: LocaleKeys.personalize_sample_topic.tr(),
      word: LocaleKeys.critical_alarm_stage_word_critical.tr(),
      subtext: LocaleKeys.critical_alarm_stage_sub_ringing.tr(
        namedArgs: {
          'duration': formatRingDuration(const Duration(seconds: 12)),
        },
      ),
      title: LocaleKeys.personalize_sample_title.tr(),
      body: LocaleKeys.personalize_sample_body.tr(),
      meta: '07:00 / ${LocaleKeys.personalize_sample_tag.tr()}',
      severityMode: SeverityMode.crit,
      faceState: FaceState.alarmed,
      isLive: isLive,
      isPreview: true,
    );

/// The ringing alarm screen as a picture: the real [RingingScreen] on the
/// real ringing canvas, laid out for this phone's own screen and scaled to
/// whatever room it is given.
///
/// It is inert. It takes no touch, no keyboard focus and no screen reader
/// stop, its buttons call nothing, it joins no hero flight, and it sits
/// under an ambient scope with no controller, so it cannot retint the app
/// behind it. It has no cubit and no incident. Sound is the page's job.
///
/// Under reduce motion it is one still frame: the face holds, the pulse
/// rings are not drawn and the canvas does not drift.
///
/// It draws in [style], through the same `AlarmStyleStage` the alarm route
/// uses, so a look shown here is the look that rings.
class RingingPreview extends StatefulWidget {
  const RingingPreview({
    this.fit = BoxFit.contain,
    this.style,
    this.isStill = false,
    this.screenSize,
    super.key,
  });

  final BoxFit fit;

  /// The screen to lay the picture out for, when it is not this display's.
  /// A phone drawn upright on a display that is wider than tall asks for a
  /// portrait one. Null lays it out for this display.
  final Size? screenSize;

  /// The look to draw. Null draws the standard one.
  final AlarmStyle? style;

  /// Holds one still frame whatever the motion setting, for a thumbnail.
  /// The face in it is always [thumbnailFace], so a row of thumbnails
  /// differs by look and never by mood.
  final bool isStill;

  /// The one expression every thumbnail wears.
  static const RingingStyle thumbnailFace = RingingStyle.classic;

  /// The screen the preview is laid out for: this display, with the text
  /// size and motion setting of [context].
  ///
  /// With [size] the screen is that size instead, upright, with the insets
  /// of a phone held that way.
  static MediaQueryData screenOf(BuildContext context, {Size? size}) {
    final here = MediaQuery.of(context);
    final view = MediaQueryData.fromView(View.of(context));
    final base = size == null
        ? view
        : view.copyWith(
            size: size,
            padding: const EdgeInsets.only(top: _uprightTop, bottom: 16),
            viewPadding: const EdgeInsets.only(top: _uprightTop, bottom: 16),
            viewInsets: EdgeInsets.zero,
          );
    return base.copyWith(
      textScaler: here.textScaler,
      disableAnimations: here.disableAnimations,
      boldText: here.boldText,
      highContrast: here.highContrast,
      platformBrightness: here.platformBrightness,
    );
  }

  /// The top inset of an upright phone, for a picture laid out upright on a
  /// display that is not.
  static const double _uprightTop = 28;

  @override
  State<RingingPreview> createState() => _RingingPreviewState();
}

class _RingingPreviewState extends State<RingingPreview> {
  /// The real screen puts a screen reader on this. Nothing reads it here.
  final GlobalKey _ackButtonKey = GlobalKey();

  static void _nothing() {}
  static void _nothingFor(String _) {}

  @override
  Widget build(BuildContext context) {
    final here = RingingPreview.screenOf(context, size: widget.screenSize);
    final screen = widget.isStill
        ? here.copyWith(disableAnimations: true)
        : here;
    final reduce = screen.disableAnimations;
    final brightness = Theme.of(context).brightness;
    // A look that cannot be drawn shows as the standard one, as it would
    // on the alarm route.
    final style = drawableAlarmStyle(
      widget.style ?? alarmStyleOf(null),
      base: context.appColors,
      severity: SeverityMode.crit,
      brightness: brightness,
    );
    // The canvas is tinted from the app's own colours and the screen from
    // the look's, the same as the alarm route does it.
    final profile = style.ringing.ambient(context.appColors, brightness);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ExcludeFocus(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox.fromSize(
              size: screen.size,
              child: MediaQuery(
                data: screen,
                child: HeroMode(
                  enabled: false,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AmbientCanvas(
                        profile: profile,
                        variant: AmbientMotionVariant.drift,
                        direction: AmbientDirection.push,
                        reduceMotion: reduce,
                      ),
                      AmbientScope(
                        child: AlarmStyleStage(
                          style: style,
                          stage: AlarmStage.ringing,
                          severity: SeverityMode.crit,
                          isStill: reduce,
                          child: Builder(
                            builder: (context) {
                              // The screen's own colours, as the alarm
                              // route hands them over.
                              final colors = context.appColors;
                              return _YellowFace(
                                pin: widget.isStill
                                    ? RingingPreview.thumbnailFace
                                    : null,
                                child: RingingScreen(
                                  state: sampleRingingState(isLive: !reduce),
                                  colors: colors,
                                  ackButtonKey: _ackButtonKey,
                                  onAcknowledge: _nothing,
                                  onSilence: _nothing,
                                  onReadMessage: _nothing,
                                  onSelectAlarm: _nothingFor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins Crit's face to yellow in both themes, on this page only.
///
/// The ringing face takes its fill and its ink from the theme, and the
/// dark theme's are dark. Here the two are the light theme's whatever the
/// theme, and nothing else in the palette changes. The head also keeps
/// its fill through every expression, so a style that flushes it never
/// turns it orange here. The alarm route is not under this, so the real
/// alarm screen draws as it always has.
///
/// With [pin] the face holds that one expression.
class _YellowFace extends StatelessWidget {
  const _YellowFace({required this.child, this.pin});

  final Widget child;
  final RingingStyle? pin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors.copyWith(
      faceFill: AppColors.light.faceFill,
      faceInk: AppColors.light.faceInk,
    );
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((ext) => ext is! AppColors),
          colors,
        ],
      ),
      child: RingingFaceFill(
        keepsFill: true,
        child: pin == null ? child : RingingFacePin(style: pin!, child: child),
      ),
    );
  }
}

/// The preview on the whole screen, with a bare x to close it.
class RingingPreviewPage extends StatelessWidget {
  const RingingPreviewPage({this.style, super.key});

  /// The look to draw. Null draws the standard one.
  final AlarmStyle? style;

  static Route<void> route({AlarmStyle? style}) => PageRouteBuilder<void>(
    fullscreenDialog: true,
    pageBuilder: (context, _, _) => RingingPreviewPage(style: style),
    transitionsBuilder: (context, animation, _, child) =>
        MediaQuery.of(context).disableAnimations
        ? child
        : FadeTransition(opacity: animation, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors =
        drawableAlarmStyle(
          style ?? alarmStyleOf(null),
          base: context.appColors,
          severity: SeverityMode.crit,
          brightness: brightness,
        ).colorsFor(
          AlarmStage.ringing,
          base: context.appColors,
          severity: SeverityMode.crit,
          brightness: brightness,
        );
    return Material(
      color: colors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: LocaleKeys.personalize_preview_label.tr(),
            child: RingingPreview(fit: BoxFit.fill, style: style),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.s1),
                child: AppDismissCross(
                  onPressed: () => Navigator.of(context).pop(),
                  label: LocaleKeys.common_close.tr(),
                  color: colors.onCanvas,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The preview in its rounded frame on the Personalize page, with the play
/// button outside its bottom corner. A tap on the frame opens it full
/// screen.
class RingingPreviewFrame extends StatelessWidget {
  const RingingPreviewFrame({
    required this.isPlaying,
    required this.onPlay,
    required this.maxHeight,
    this.playBelow = false,
    this.style,
    super.key,
  });

  /// The look the ringing alarm is drawn in. Null draws the standard one.
  final AlarmStyle? style;

  /// The edge of the square that takes a tap on the play button.
  static const double playTarget = 44;

  /// Puts the play button under the frame instead of beside it.
  final bool playBelow;

  /// The tallest the frame may be. It is also never wider than the room
  /// it is given, and keeps the shape of this phone's screen.
  final double maxHeight;

  final bool isPlaying;
  final VoidCallback onPlay;

  void _open(BuildContext context) {
    unawaited(
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(RingingPreviewPage.route(style: style)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screen = RingingPreview.screenOf(context).size;
    final frame = Semantics(
      button: true,
      image: true,
      label: LocaleKeys.personalize_preview_label.tr(),
      hint: LocaleKeys.personalize_preview_hint.tr(),
      onTap: () => _open(context),
      child: GestureDetector(
        onTap: () => _open(context),
        child: AspectRatio(
          aspectRatio: screen.width / screen.height,
          child: LayoutBuilder(
            builder: (context, box) {
              // The corner follows the frame's size, as a phone's does.
              final radius = BorderRadius.circular(box.maxWidth * 0.14);
              return DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: colors.inkFixed, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: RepaintBoundary(child: RingingPreview(style: style)),
                ),
              );
            },
          ),
        ),
      ),
    );
    // A 44 point target around the 40 point button.
    final play = SizedBox.square(
      dimension: playTarget,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlay,
        child: Center(
          child: AppPreviewButton(
            isPlaying: isPlaying,
            onPressed: onPlay,
            playLabel: LocaleKeys.personalize_play_label.tr(),
            stopLabel: LocaleKeys.sound_picker_stop_aria_label.tr(),
          ),
        ),
      ),
    );
    final aspect = screen.width / screen.height;
    return LayoutBuilder(
      builder: (context, box) {
        // The play button sits outside the frame, so it covers none of
        // the preview: beside its bottom corner, or under it where the
        // page has no width to spare. Beside, the same room is kept on
        // the other side so the frame stays in the middle.
        const beside = playTarget + Spacing.s2;
        final maxWidth = box.maxWidth - (playBelow ? 0 : 2 * beside);
        final height = maxHeight * aspect <= maxWidth
            ? maxHeight
            : maxWidth / aspect;
        final sized = SizedBox(
          width: height * aspect,
          height: height,
          child: frame,
        );
        if (playBelow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sized,
              const SizedBox(height: Spacing.s2),
              play,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: beside),
            sized,
            const SizedBox(width: Spacing.s2),
            play,
          ],
        );
      },
    );
  }
}
