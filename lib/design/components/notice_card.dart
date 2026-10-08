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

/// The surface of an [AppNoticeCard].
enum AppNoticeTone {
  /// Cream with no stroke, for a notice that asks for a look. It sits on the
  /// yellow canvas, which already sets it apart. This is not
  /// [AppHighlightTone.choice]: that tone is cream with the ink stroke, for a
  /// card on a white sheet.
  cream,

  /// The critical canvas with its stroke, for the one notice that means no
  /// alarm can arrive at all (no server).
  crit,
}

/// The card Home shows in its notice slot: a face, a title, up to two short
/// lines, one button, and a bare cross to put it away.
///
/// Every notice that is a card uses this one component, so a missed alarm, a
/// missed weekly check, a phone update and a missing server look the same and
/// differ only in their words and their face. Pass the face from
/// `face_meaning.dart`. The card owns the look: type sizes, the geometry and
/// the 44 point cross. A caller picks only the [tone].
///
/// [AppNoticeTone.cream] is the cream card with no stroke, the same surface
/// as Home's day-0 card, for a notice that asks for a look. Red belongs to a
/// ringing alarm, so [AppNoticeTone.crit] is for the one notice that means
/// no alarm can arrive at all (no server).
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
    this.tone = AppNoticeTone.cream,
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

  final AppNoticeTone tone;

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
    final isCream = tone == AppNoticeTone.cream;
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

/// The cream card in the inbox list: a title, a line of body, one outline
/// action pill and, when it can be put away, a bare cross.
///
/// Home uses it for "Back up your topics", the widgets card, the day-0 card,
/// "One topic so far" and the curl line of a topic that has had no message.
/// Cream on the yellow canvas has no stroke. Pass [isOnSheet] when it sits on
/// the white sheet, where cream alone does not separate and the ink stroke
/// draws it ([AppHighlightTone.choice]).
///
/// At large text, or in a narrow column, the pill drops under the words and
/// takes the full width, so neither is squeezed. The card draws and reports
/// taps; what the action and the cross do belong to the caller.
class AppCreamCard extends StatelessWidget {
  const AppCreamCard({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.body,
    this.isMonoTitle = false,
    this.isOnSheet = false,
    this.onClose,
    this.closeLabel,
    super.key,
  }) : assert(
         onClose == null || closeLabel != null,
         'A cross needs words for a screen reader.',
       );

  /// The first line, in bold.
  final String title;

  /// A supporting line under the title. Null leaves it out.
  final String? body;

  /// True sets the title in mono and on one line, for a command to copy.
  final bool isMonoTitle;

  /// The outline pill's label.
  final String actionLabel;

  final VoidCallback onAction;

  /// True draws the ink stroke, for a card on the white sheet.
  final bool isOnSheet;

  /// Puts the card away. Null draws no cross.
  final VoidCallback? onClose;

  /// What a screen reader says for the cross.
  final String? closeLabel;

  /// Below this width of card the pill goes under the words.
  static const double stackBelowWidth = 300;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;

    final titleStyle = isMonoTitle
        ? AppTypography.monoBold(colors.ink)
        : TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            height: 1.3,
            color: colors.ink,
          );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: isMonoTitle ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (body != null)
          Text(
            body!,
            style: AppTypography.small(colors.ink2, fontSize: 13.5),
          ),
      ],
    );

    Widget pill({required bool isFullWidth}) => AppButton(
      label: actionLabel,
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.sm,
      isFullWidth: isFullWidth,
      onPressed: onAction,
    );

    final cross = onClose == null
        ? null
        : AppDismissCross(
            onPressed: onClose!,
            label: closeLabel!,
            color: colors.ink,
          );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isStacked =
            scale > kChromeMaxTextScale ||
            constraints.maxWidth < stackBelowWidth;
        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: words),
                  ?cross,
                ],
              ),
              const SizedBox(height: Spacing.s3),
              pill(isFullWidth: true),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: words),
            const SizedBox(width: Spacing.s3),
            pill(isFullWidth: false),
            ?cross,
          ],
        );
      },
    );

    // The cross brings its own room at the right edge.
    final padding = EdgeInsets.fromLTRB(16, 12, onClose == null ? 16 : 4, 12);
    return isOnSheet
        ? AppHighlightCard(
            tone: AppHighlightTone.choice,
            padding: padding,
            child: content,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cream,
              borderRadius: Radii.lgAll,
            ),
            child: Padding(padding: padding, child: content),
          );
  }
}
