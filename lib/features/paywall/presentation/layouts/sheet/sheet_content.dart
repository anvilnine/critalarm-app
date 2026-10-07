import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What the sheet says above the buy block: the handle, one headline, the
/// lead benefit as a card and the other benefits as a row of small tiles.
///
/// At the default text size the lead card takes whatever height is left,
/// so the sheet is full with one benefit and with seven. Past it the lead
/// keeps its short form and the whole part scrolls inside its own box.
class SheetContent extends StatelessWidget {
  const SheetContent({
    required this.headline,
    required this.lead,
    required this.others,
    required this.isCompact,
    required this.clock,
    super.key,
  });

  final String headline;
  final PaywallBenefit? lead;
  final List<PaywallBenefit> others;
  final bool isCompact;
  final ValueListenable<double> clock;

  /// Side inset, the same as the buy block's.
  static const double side = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isScaled = MediaQuery.textScalerOf(context).scale(100) > 101;
    final gap = isCompact ? 6.0 : Spacing.s3;
    final lead = this.lead;

    final column = Column(
      mainAxisSize: isScaled ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: isCompact ? 6 : 9),
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: clock,
            builder: (context, t, child) => Transform.scale(
              scaleX: SheetMotion.handle(t),
              child: child,
            ),
            child: Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: Radii.fullAll,
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : Spacing.s3),
        Padding(
          // The close cross has the top right corner.
          padding: const EdgeInsets.only(
            right: PaywallLayoutScope.closeCrossSize - Spacing.s2,
          ),
          child: Semantics(
            header: true,
            child: Text(
              headline,
              style: AppTypography.headline(
                colors.ink,
                fontSize: isCompact ? 22 : 27,
              ),
            ),
          ),
        ),
        if (lead != null) ...[
          SizedBox(height: gap),
          if (isScaled)
            _LeadCard(benefit: lead, isCompact: isCompact, height: null)
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _LeadCard(
                  benefit: lead,
                  isCompact: isCompact,
                  height: constraints.maxHeight,
                ),
              ),
            ),
        ] else if (!isScaled)
          const Spacer(),
        if (others.isNotEmpty) ...[
          SizedBox(height: gap),
          _Tiles(benefits: others, isCompact: isCompact),
        ],
        SizedBox(height: isCompact ? 6 : Spacing.s2),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: side),
      child: isScaled
          ? SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: column,
            )
          : column,
    );
  }
}

/// The benefit the sheet answers first, on a cream card.
///
/// With room, its preview is a stage across the card and the words sit
/// under it. Without, the preview is a square beside the words.
class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.benefit,
    required this.isCompact,
    required this.height,
  });

  /// From this height up the preview goes across the card.
  static const double _stageFrom = 136;

  final PaywallBenefit benefit;
  final bool isCompact;

  /// The height the card is given, or null to take what its words need.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final height = this.height;
    final isStage = height != null && height >= _stageFrom;

    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          benefit.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small(
            colors.ink,
            fontSize: 15,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
        ),
        Text(
          benefit.line,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small(
            colors.ink3,
            fontSize: 13,
          ).copyWith(height: 1.3),
        ),
      ],
    );

    final pad = isCompact && !isStage ? 6.0 : Spacing.s3;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: Spacing.s3, vertical: pad),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: isStage
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => PaywallPreview(
                      benefit.previewId,
                      size: constraints.biggest,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s2),
                words,
              ],
            )
          : Row(
              children: [
                PaywallPreview(
                  benefit.previewId,
                  size: Size.square(isCompact ? 40 : 52),
                ),
                const SizedBox(width: Spacing.s3),
                Expanded(child: words),
              ],
            ),
    );
  }
}

/// The other benefits: one small preview each, with its name under it.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.benefits, required this.isCompact});

  final List<PaywallBenefit> benefits;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final benefit in benefits)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  PaywallPreview(
                    benefit.previewId,
                    size: Size.square(isCompact ? 38 : 48),
                  ),
                  const SizedBox(height: Spacing.s1),
                  Text(
                    benefit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.small(
                      colors.ink3,
                      fontSize: 11,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
