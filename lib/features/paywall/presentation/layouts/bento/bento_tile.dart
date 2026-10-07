import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_tile_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:flutter/material.dart';

/// One benefit as a bento tile: its title, its line where there is room,
/// and its preview in the rest.
///
/// The lead tile is the ink panel with the preview in a cream window, so a
/// preview is always drawn on a light surface. Every other tile is a white
/// card.
class BentoTile extends StatelessWidget {
  const BentoTile({
    required this.benefit,
    required this.isLead,
    required this.isSolo,
    required this.isCompact,
    super.key,
  });

  final PaywallBenefit benefit;
  final bool isLead;

  /// True when this is the only tile, which then has the room of a poster.
  final bool isSolo;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(isCompact ? Radii.md : Radii.lg);
    final padding = isSolo
        ? const EdgeInsets.all(Spacing.s4)
        : EdgeInsets.symmetric(
            horizontal: isCompact ? Spacing.s2 + Spacing.xxs : Spacing.s3,
            vertical: isCompact ? Spacing.s2 : Spacing.s2 + Spacing.xxs,
          );

    final ink = isLead ? colors.onPanel : colors.ink;
    final muted = isLead ? colors.onPanelMuted : colors.ink3;
    final titleStyle = isLead
        ? AppTypography.title(ink, fontSize: isSolo ? 26 : 16)
        : AppTypography.small(
            ink,
            fontSize: 13,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.2);
    final lineStyle = AppTypography.small(
      muted,
      fontSize: isSolo ? 15 : (isLead ? 12 : 11),
    ).copyWith(height: 1.25);

    final title = benefit.title;
    final line = benefit.line;

    return Semantics(
      container: true,
      label: '$title. $line', // l10n-ok: joins two translated strings
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLead ? colors.panel : colors.surface,
            borderRadius: radius,
            boxShadow: AppShadows.shadowSm(isDark: isDark),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: padding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inner = constraints.biggest;
                  final scaler = MediaQuery.textScalerOf(context);
                  final direction = Directionality.of(context);
                  // Measured as `Text` draws it, inherited style included.
                  final inherited = DefaultTextStyle.of(context).style;
                  final lineSize = _measure(
                    line,
                    inherited.merge(lineStyle),
                    scaler,
                    direction,
                  ).size;

                  // A title that does not fit its lines steps down in size
                  // before it is cut short.
                  var fittedTitle = titleStyle;
                  late BentoTileText text;
                  for (final step in _titleSteps) {
                    fittedTitle = titleStyle.copyWith(
                      fontSize: titleStyle.fontSize! * step,
                      letterSpacing: (titleStyle.letterSpacing ?? 0) * step,
                    );
                    final drawn = inherited.merge(fittedTitle);
                    final titleSize = _measure(
                      title,
                      drawn,
                      scaler,
                      direction,
                    ).size;
                    text = bentoTileText(
                      inner: inner,
                      titleWidth: titleSize.width,
                      titleLineHeight: titleSize.height,
                      lineWidth: lineSize.width,
                      lineLineHeight: lineSize.height,
                      isLead: isLead,
                    );
                    final wrapped = _measure(
                      title,
                      drawn,
                      scaler,
                      direction,
                      maxLines: text.titleLines,
                      maxWidth: inner.width,
                    );
                    if (!wrapped.didExceedMaxLines) break;
                  }
                  // Stacked, the preview is under the words. On a tile too
                  // short for that it is beside the title.
                  final titleWidth = _measure(
                    title,
                    inherited.merge(fittedTitle),
                    scaler,
                    direction,
                  ).size.width;
                  final previewSize = text.previewBeside
                      ? Size(
                          inner.width - titleWidth - bentoBesideGap,
                          inner.height,
                        )
                      : Size(
                          inner.width,
                          inner.height - text.height - bentoTextGap,
                        );

                  final titleText = Text(
                    title,
                    maxLines: text.titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: fittedTitle,
                  );
                  final lineText = Text(
                    line,
                    maxLines: text.lineLines < 1 ? 1 : text.lineLines,
                    overflow: TextOverflow.ellipsis,
                    style: lineStyle,
                  );

                  return Stack(
                    children: [
                      PositionedDirectional(
                        top: text.previewBeside
                            ? (inner.height - text.height) / 2
                            : 0,
                        start: 0,
                        end: 0,
                        height: text.height.clamp(0.0, inner.height),
                        // The words were measured, so they fit. The box
                        // only keeps a rounding point from being an error.
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: AlignmentDirectional.topStart,
                            maxHeight: double.infinity,
                            child: switch (text.linePlace) {
                              BentoLinePlace.none => Align(
                                alignment: AlignmentDirectional.topStart,
                                child: titleText,
                              ),
                              BentoLinePlace.beside => Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(child: titleText),
                                  const SizedBox(width: bentoBesideGap),
                                  lineText,
                                ],
                              ),
                              BentoLinePlace.below => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleText,
                                  const SizedBox(height: bentoLineGap),
                                  lineText,
                                ],
                              ),
                            },
                          ),
                        ),
                      ),
                      if (previewSize.height >= bentoMinPreview / 2)
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          width: previewSize.width,
                          height: previewSize.height,
                          child: _PreviewWindow(
                            isLead: isLead,
                            child: PaywallPreview(
                              benefit.previewId,
                              size: previewSize,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The sizes a title tries, as shares of its own, largest first.
  static const List<double> _titleSteps = [1, 0.92, 0.85, 0.78];

  static ({Size size, bool didExceedMaxLines}) _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final result = (
      size: painter.size,
      didExceedMaxLines: painter.didExceedMaxLines,
    );
    painter.dispose();
    return result;
  }
}

/// What the preview is drawn on. On the ink lead tile it is a cream
/// window, so a preview drawn in ink still reads.
class _PreviewWindow extends StatelessWidget {
  const _PreviewWindow({required this.isLead, required this.child});

  final bool isLead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLead) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: ClipRRect(borderRadius: Radii.mdAll, child: child),
    );
  }
}
