import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/dismiss_cross.dart';
import 'package:critalarm/design/components/highlight_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The cream card in the inbox list: a title, a line of body, one outline
/// action pill and, when it can be put away, a bare cross.
///
/// Home uses it for the widgets card and the day-0 card.
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
