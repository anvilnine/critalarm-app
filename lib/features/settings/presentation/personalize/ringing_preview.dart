import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
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
class RingingPreview extends StatefulWidget {
  const RingingPreview({this.fit = BoxFit.contain, super.key});

  final BoxFit fit;

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
    final screen = RingingPreview.screenOf(context);
    final reduce = screen.disableAnimations;
    // The canvas is tinted from the app's own colours and the screen from
    // the severity's, the same as the alarm route does it.
    final profile = AmbientAppProfiles.criticalAlarmRinging(context.appColors);
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
                        child: SeverityScope(
                          mode: SeverityMode.crit,
                          child: Builder(
                            builder: (context) => RingingScreen(
                              state: sampleRingingState(isLive: !reduce),
                              colors: context.appColors,
                              ackButtonKey: _ackButtonKey,
                              onAcknowledge: _nothing,
                              onSilence: _nothing,
                              onReadMessage: _nothing,
                              onSelectAlarm: _nothingFor,
                            ),
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

/// The preview on the whole screen, with a bare x to close it.
class RingingPreviewPage extends StatelessWidget {
  const RingingPreviewPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    fullscreenDialog: true,
    pageBuilder: (context, _, _) => const RingingPreviewPage(),
    transitionsBuilder: (context, animation, _, child) =>
        MediaQuery.of(context).disableAnimations
        ? child
        : FadeTransition(opacity: animation, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors.withSeverity(SeverityMode.crit);
    return Material(
      color: colors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: LocaleKeys.personalize_preview_label.tr(),
            child: const RingingPreview(fit: BoxFit.fill),
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
/// button on its corner. A tap on the frame opens it full screen.
class RingingPreviewFrame extends StatelessWidget {
  const RingingPreviewFrame({
    required this.isPlaying,
    required this.onPlay,
    required this.maxHeight,
    super.key,
  });

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
      ).push(RingingPreviewPage.route()),
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
                  child: const RepaintBoundary(child: RingingPreview()),
                ),
              );
            },
          ),
        ),
      ),
    );
    final framed = Stack(
      clipBehavior: Clip.none,
      children: [
        frame,
        PositionedDirectional(
          end: -AppPreviewButton.size / 2,
          bottom: Spacing.s3,
          child: AppPreviewButton(
            isPlaying: isPlaying,
            onPressed: onPlay,
            playLabel: LocaleKeys.personalize_play_label.tr(),
            stopLabel: LocaleKeys.sound_picker_stop_aria_label.tr(),
          ),
        ),
      ],
    );
    final aspect = screen.width / screen.height;
    return LayoutBuilder(
      builder: (context, box) {
        // Room at the end for the half of the play button that hangs out.
        final maxWidth = box.maxWidth - AppPreviewButton.size;
        final height = maxHeight * aspect <= maxWidth
            ? maxHeight
            : maxWidth / aspect;
        return Center(
          child: SizedBox(
            width: height * aspect,
            height: height,
            child: framed,
          ),
        );
      },
    );
  }
}
