import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/dismiss_cross.dart';
import 'package:critalarm/design/components/highlight_card.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The card Home shows in its notice slot: a face, a title, up to two short
/// lines, one button, and a bare cross to put it away.
///
/// Every notice that is a card uses this one component, so a missed alarm, a
/// missed weekly check, a phone update and a missing server look the same and
/// differ only in their words and their face. Pass the face from
/// `face_meaning.dart`. The card owns the look: type sizes, the geometry and
/// the 44 point cross. A caller picks only the [tone].
///
/// [AppHighlightTone.choice] is the cream card with no stroke, the same
/// surface as Home's day-0 card, for a notice that asks for a look. Red
/// belongs to a ringing alarm, so the crit tone is for the one notice that
/// means no alarm can arrive at all (no server).
///
/// The card draws and reports taps. Closing a notice and what the button does
/// belong to the caller. [onDismiss] null draws no cross, for a notice that
/// has to stay until its condition clears.
class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    required this.face,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.tone = AppHighlightTone.choice,
    this.lines = const [],
    this.onDismiss,
    this.dismissLabel,
    super.key,
  }) : assert(
         onDismiss == null || dismissLabel != null,
         'A cross needs words for a screen reader.',
       );

  final FaceState face;
  final String title;

  /// [AppHighlightTone.choice] (cream, no stroke) or
  /// [AppHighlightTone.crit].
  final AppHighlightTone tone;

  /// Short supporting lines under the title, one text style for all of them.
  final List<String> lines;

  final String actionLabel;
  final VoidCallback onAction;

  /// Puts the notice away. Null draws no cross.
  final VoidCallback? onDismiss;

  /// What a screen reader says for the cross.
  final String? dismissLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isCream = tone == AppHighlightTone.choice;
    // Text takes the card's own ink: the canvas text colour on the red card,
    // the plain ink pair on cream (as the day-0 card does).
    final titleColor = isCream ? colors.ink : colors.onCanvas;
    final lineColor = isCream ? colors.ink2 : colors.onCanvasMuted;
    const padding = EdgeInsets.fromLTRB(14, 2, 2, 14);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDismissCross.hitSize,
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: FaceWidget(state: face, size: 28)),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: titleColor,
                    ),
                  ),
                ),
              ),
              if (onDismiss != null)
                AppDismissCross(
                  onPressed: onDismiss!,
                  label: dismissLabel!,
                  color: titleColor,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in lines)
                Text(
                  line,
                  style: AppTypography.small(lineColor),
                ),
              const SizedBox(height: Spacing.s3),
              AppButton(
                label: actionLabel,
                size: AppButtonSize.sm,
                isFullWidth: true,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: isCream
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cream,
                borderRadius: Radii.lgAll,
              ),
              child: Padding(padding: padding, child: body),
            )
          : AppHighlightCard(padding: padding, child: body),
    );
  }
}
