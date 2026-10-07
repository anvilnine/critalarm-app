import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_chapters.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the small face beside the tracker can look like. A step picks one
/// of these and never draws a face of its own up there.
enum TravellingFaceMood {
  /// Nothing going on. What every step shows unless it says otherwise.
  calm,

  /// A server is being connected.
  watching,

  /// A permission was refused.
  worried,

  /// The real alarm is being sent.
  alarmed,

  /// Setup is behind the user.
  acknowledged;

  FaceState get face => switch (this) {
    TravellingFaceMood.calm => FaceState.calm,
    TravellingFaceMood.watching => FaceState.watching,
    TravellingFaceMood.worried => FaceState.worried,
    TravellingFaceMood.alarmed => FaceState.alarmed,
    TravellingFaceMood.acknowledged => FaceState.acked,
  };
}

/// What a screen reader says for the tracker: the chapter and which part of
/// the three it is, or that all three are done.
String setupTrackerLabel(OnboardingTrackerFill fill) {
  final chapter = fill.chapter;
  if (chapter == null) return LocaleKeys.onboarding_tracker_all_done.tr();
  return LocaleKeys.onboarding_tracker_part.tr(
    namedArgs: {
      'chapter': switch (chapter) {
        OnboardingChapter.meet => LocaleKeys.onboarding_tracker_meet.tr(),
        OnboardingChapter.setUp => LocaleKeys.onboarding_tracker_set_up.tr(),
        OnboardingChapter.hearIt => LocaleKeys.onboarding_tracker_hear_it.tr(),
      },
      'part': '${chapter.index + 1}',
    },
  );
}

/// Where the user is in setup: one small face and three bars, one bar per
/// chapter.
///
/// The setup shell draws it once and keeps it mounted from step to step, so
/// a bar fills in place when the step changes. It holds no text, so the
/// system text size does not move it. Under reduce motion the bars and the
/// face change at once and the face holds still.
class SetupTracker extends StatelessWidget {
  const SetupTracker({required this.fill, required this.mood, super.key});

  final OnboardingTrackerFill fill;
  final TravellingFaceMood mood;

  /// How wide the tracker is drawn in the top bar.
  static const double width = 132;

  static const double _faceSize = 26;
  static const double _barHeight = 6;
  static const double _barGap = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final face = mood.face;
    return Semantics(
      container: true,
      label: setupTrackerLabel(fill),
      child: ExcludeSemantics(
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: context.motion(AppDurations.base),
              switchInCurve: AppCurves.easeOut,
              switchOutCurve: AppCurves.easeOut,
              child: FaceWidget(
                key: ValueKey(face),
                state: face,
                size: _faceSize,
                isLive: !context.reduceMotion,
              ),
            ),
            const SizedBox(width: Spacing.s2),
            Expanded(
              // One number runs from 0 to 3, so a change that fills more
              // than one bar fills them one after the other.
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fill.position),
                duration: context.motion(AppDurations.slow),
                curve: AppCurves.easeOut,
                builder: (context, position, _) => Row(
                  children: [
                    for (var i = 0; i < fill.bars.length; i++) ...[
                      if (i > 0) const SizedBox(width: _barGap),
                      Expanded(
                        child: _TrackerBar(
                          fill: (position - i).clamp(0.0, 1.0),
                          track: colors.onCanvas.withValues(alpha: 0.25),
                          color: colors.onCanvas,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerBar extends StatelessWidget {
  const _TrackerBar({
    required this.fill,
    required this.track,
    required this.color,
  });

  final double fill;
  final Color track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SetupTracker._barHeight,
      child: ClipRRect(
        borderRadius: Radii.fullAll,
        child: ColoredBox(
          color: track,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: fill,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: Radii.fullAll,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
