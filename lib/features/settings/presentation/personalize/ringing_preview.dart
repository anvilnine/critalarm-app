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
    super.key,
  });

  final BoxFit fit;

  /// The look to draw. Null draws the standard one.
  final AlarmStyle? style;

  /// Holds one still frame whatever the motion setting, for a thumbnail.
  final bool isStill;

  /// The screen the preview is laid out for: this display, with the text
  /// size and motion setting of [context].
  static MediaQueryData screenOf(BuildContext context) {
    final here = MediaQuery.of(context);
    return MediaQueryData.fromView(View.of(context)).copyWith(
      textScaler: here.textScaler,
      disableAnimations: here.disableAnimations,
      boldText: here.boldText,
      highContrast: here.highContrast,
      platformBrightness: here.platformBrightness,
    );
  }

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
    final here = RingingPreview.screenOf(context);
    final screen = widget.isStill
        ? here.copyWith(disableAnimations: true)
        : here;
    final reduce = screen.disableAnimations;
    final style = widget.style ?? alarmStyleOf(null);
    // The canvas is tinted from the app's own colours and the screen from
    // the look's, the same as the alarm route does it.
    final profile = style.ringing.ambient(context.appColors);
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
/// theme, and nothing else in the palette changes. The alarm route is not
/// under this, so the real alarm screen draws as it always has.
class _YellowFace extends StatelessWidget {
  const _YellowFace({required this.child});

  final Widget child;

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
      child: child,
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
    final colors = (style ?? alarmStyleOf(null)).colorsFor(
      AlarmStage.ringing,
      base: context.appColors,
      severity: SeverityMode.crit,
      brightness: Theme.of(context).brightness,
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
    this.picture,
    this.pictureLabel,
    this.pictureHint,
    this.onOpenPicture,
    super.key,
  });

  /// The look the ringing alarm is drawn in. Null draws the standard one.
  final AlarmStyle? style;

  /// Drawn in the frame in place of the ringing alarm: an option being
  /// shown that is not a look of the ringing screen, such as a wake-up
  /// challenge. It is handed the screen it is laid out for. Null draws the
  /// ringing alarm.
  final Widget Function(MediaQueryData screen)? picture;

  /// What a screen reader calls the frame while [picture] is in it, and
  /// what a double tap does.
  final String? pictureLabel;
  final String? pictureHint;

  /// A tap on the frame while [picture] is in it.
  final VoidCallback? onOpenPicture;

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
    if (picture != null) {
      onOpenPicture?.call();
      return;
    }
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
    final screenData = RingingPreview.screenOf(context);
    final screen = screenData.size;
    final picture = this.picture;
    final frame = Semantics(
      button: true,
      image: true,
      label: picture == null
          ? LocaleKeys.personalize_preview_label.tr()
          : pictureLabel,
      hint: picture == null
          ? LocaleKeys.personalize_preview_hint.tr()
          : pictureHint,
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
                  child: RepaintBoundary(
                    child: picture == null
                        ? RingingPreview(style: style)
                        : picture(screenData),
                  ),
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
