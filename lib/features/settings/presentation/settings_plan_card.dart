import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// How full the critical topic allowance is, from 0 to 1, or null where there
/// is no allowance to show: a plan with no limit, or no limit known yet.
double? planUsageFraction({required int used, required int? limit}) {
  if (limit == null || limit <= 0) return null;
  return (used / limit).clamp(0.0, 1.0);
}

/// The plan on Settings: its name, how much of it is used and one outline
/// pill. A cream card, drawn on the white sheet.
///
/// The card draws and reports taps. What the pill does belongs to the caller.
class SettingsPlanCard extends StatelessWidget {
  const SettingsPlanCard({
    required this.title,
    required this.usage,
    this.fraction,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  final String title;

  /// The line under the title.
  final String usage;

  /// Fills the bar under the usage line. Null draws no bar.
  final double? fraction;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fraction = this.fraction;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          usage,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 13.5,
            height: 1.3,
            color: colors.ink2,
          ),
        ),
        if (fraction != null) ...[
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: Radii.fullAll,
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.ink.withValues(alpha: 0.12),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: ColoredBox(color: colors.high),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final label = actionLabel;
    Widget pill({required bool isFullWidth}) => AppButton(
      label: label!,
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.sm,
      isFullWidth: isFullWidth,
      onPressed: onAction,
    );

    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: label == null
            ? words
            : LayoutBuilder(
                builder: (context, constraints) {
                  // The pill goes under the words when the card is narrow or
                  // the text is large, as the cream notice card does.
                  final isStacked =
                      scale > kChromeMaxTextScale || constraints.maxWidth < 300;
                  if (isStacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        words,
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
                    ],
                  );
                },
              ),
      ),
    );
  }
}
