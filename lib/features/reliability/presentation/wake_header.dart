import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/wake_answer.dart';
import 'package:critalarm/features/reliability/presentation/readiness_view.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// The top of "Will it wake me?": a small label, the answer in one word, one
// mono line and the face. The face is the shipped one for each answer. The
// disc behind it (`WakeDisc`) breathes slowly, and is tinted red under No.

/// The word for [answer], as text.
String wakeAnswerWord(WakeAnswer answer) => switch (answer) {
  WakeAnswer.yes => LocaleKeys.wake_yes.tr(),
  WakeAnswer.maybe => LocaleKeys.wake_maybe.tr(),
  WakeAnswer.no => LocaleKeys.wake_no.tr(),
};

/// The face for [answer]: the one the existing headline wears.
FaceState wakeFaceFor(WakeAnswer answer) => reliabilityHeadlineView(
  switch (answer) {
    WakeAnswer.yes => ReliabilityHeadline.fine,
    WakeAnswer.maybe => ReliabilityHeadline.needsLook,
    WakeAnswer.no => ReliabilityHeadline.broken,
  },
).face;

/// The words of the line under the answer.
String wakeLineText(WakeLine line) => switch (line.kind) {
  WakeLineKind.testRang => LocaleKeys.wake_line_test_rang.tr(
    namedArgs: {'when': reliabilityAgo(line.since ?? Duration.zero)},
  ),
  WakeLineKind.noTestYet => LocaleKeys.wake_line_no_test.tr(),
  WakeLineKind.check => readinessCheckLine(line.checkId),
  WakeLineKind.several => LocaleKeys.wake_line_several.tr(
    namedArgs: {'count': '${line.count}'},
  ),
  WakeLineKind.couldNotRun =>
    LocaleKeys.home_card_foot_check_could_not_run.tr(),
};

/// The label, the answer, the line and the face.
///
/// Side by side the word and the line take the room left of the face. When
/// the word will not fit there (a narrow screen, large text) the face drops
/// under the line. `wakeAnswerSize` decides, so the two never meet.
class WakeHeader extends StatelessWidget {
  const WakeHeader({
    required this.answer,
    required this.line,
    required this.clock,
    required this.isStill,
    super.key,
  });

  final WakeAnswer answer;
  final String line;
  final ValueListenable<double> clock;
  final bool isStill;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final word = wakeAnswerWord(answer);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = wakeAnswerSize(
          answer,
          width,
          MediaQuery.textScalerOf(context).scale(1),
        );
        final face = _WakeFace(
          face: wakeFaceFor(answer),
          size: layout.faceSize,
        );

        final words = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.wake_label.tr().toUpperCase(),
              style: AppTypography.monoBold(
                colors.onCanvas,
                fontSize: 10.5,
              ).copyWith(letterSpacing: 10.5 * 0.1, height: 1.2),
            ),
            const SizedBox(height: 2),
            // The size is worked out above, so the word is held there and
            // does not grow a second time with the text size.
            Text(
              word,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.headline(
                colors.onCanvas,
                fontSize: layout.fontSize,
              ).copyWith(height: 1.05),
            ),
            const SizedBox(height: 6),
            Text(
              line,
              style: AppTypography.mono(
                colors.onCanvasMuted,
                fontSize: 12,
              ).copyWith(height: 1.4, letterSpacing: 0),
            ),
          ],
        );

        final Widget body = layout.isStacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words,
                  const SizedBox(height: Spacing.s3),
                  face,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: words),
                  const SizedBox(width: wakeFaceGap),
                  face,
                ],
              );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            wakeSideMargin,
            0,
            wakeSideMargin,
            0,
          ),
          child: Semantics(
            container: true,
            label: LocaleKeys.wake_answer_aria_label.tr(
              namedArgs: {'answer': word, 'line': line},
            ),
            excludeSemantics: true,
            child: body,
          ),
        );
      },
    );
  }
}

class _WakeFace extends StatelessWidget {
  const _WakeFace({required this.face, required this.size});

  final FaceState face;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // A face is yellow with an ink outline on every canvas.
    child: FaceWidget(
      state: face,
      size: size,
      overrideFillColor: AppColors.light.faceFill,
      overrideStrokeColor: AppColors.light.faceStroke,
      overrideInkColor: AppColors.light.faceInk,
    ),
  );
}

/// The disc behind the face: a soft wash that breathes, red under No. Put it
/// first in a `Stack` that holds the header, and past the right edge, so it
/// sits behind everything the stack holds.
class WakeDisc extends StatelessWidget {
  const WakeDisc({
    required this.answer,
    required this.clock,
    required this.isStill,
    super.key,
  });

  static const double size = 420;

  final WakeAnswer answer;
  final ValueListenable<double> clock;
  final bool isStill;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tint = answer == WakeAnswer.no
        ? colors.crit.withValues(alpha: 0.2)
        : colors.canvasAlt.withValues(alpha: 0.6);
    final disc = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
      child: const SizedBox.square(dimension: size),
    );
    if (isStill) return disc;
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      child: disc,
      builder: (context, t, child) =>
          Transform.scale(scale: wakeBreathAt(t), child: child),
    );
  }
}
