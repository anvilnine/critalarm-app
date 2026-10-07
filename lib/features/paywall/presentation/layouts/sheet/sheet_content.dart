import 'dart:math' as math;

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
/// is at least as tall as the room left over, and when the words need more
/// than the room the whole part scrolls inside its own box.
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

  /// Square edge of one small tile.
  double get _tile => isCompact ? 38 : 48;

  TextStyle _headlineStyle(AppColors colors) =>
      AppTypography.headline(colors.ink, fontSize: isCompact ? 22 : 27);

  /// The close cross has the top right corner, so the headline stops
  /// short of it.
  static const double _headlineInset =
      PaywallLayoutScope.closeCrossSize - Spacing.s2;

  @override
  Widget build(BuildContext context) {
    final isScaled = MediaQuery.textScalerOf(context).scale(100) > 101;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: side),
      child: isScaled
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: _column(
                  context,
                  leadRoom: _leadRoomWhenScaled(context, constraints),
                ),
              ),
            )
          : _column(context, leadRoom: null),
    );
  }

  /// The height left for the lead card at a large text size, worked out
  /// from the words around it. It only has to be close: the card grows
  /// past it when its own words need more.
  double _leadRoomWhenScaled(BuildContext context, BoxConstraints room) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: headline,
        style: _headlineStyle(context.appColors),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: math.max(0, room.maxWidth - _headlineInset));
    final headlineHeight = painter.height;
    painter.dispose();

    final tiles = others.isEmpty
        ? 0.0
        : _gap + _tile + Spacing.s1 + scaler.scale(_captionSize) * 1.2 * 2;
    final around = _aboveHandle + _handle + _underHandle + _gap + _bottom;
    return math.max(0, room.maxHeight - around - headlineHeight - tiles);
  }

  static const double _handle = 5;
  static const double _captionSize = 11;
  double get _aboveHandle => isCompact ? 6 : 9;
  double get _underHandle => isCompact ? 6 : Spacing.s3;
  double get _gap => isCompact ? 6 : Spacing.s3;
  double get _bottom => isCompact ? 6 : Spacing.s2;

  /// The parts, top to bottom. A null [leadRoom] is the default text size:
  /// the column fills its room and the lead takes what is left.
  Widget _column(BuildContext context, {required double? leadRoom}) {
    final colors = context.appColors;
    final lead = this.lead;
    final fills = leadRoom == null;

    return Column(
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _aboveHandle),
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: clock,
            builder: (context, t, child) => Transform.scale(
              scaleX: SheetMotion.handle(t),
              child: child,
            ),
            child: Container(
              width: 38,
              height: _handle,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: Radii.fullAll,
              ),
            ),
          ),
        ),
        SizedBox(height: _underHandle),
        Padding(
          padding: const EdgeInsets.only(right: _headlineInset),
          child: Semantics(
            header: true,
            child: Text(headline, style: _headlineStyle(colors)),
          ),
        ),
        if (lead != null) ...[
          SizedBox(height: _gap),
          if (leadRoom != null)
            _LeadCard(
              benefit: lead,
              isCompact: isCompact,
              // The stage needs an exact height. The words are larger
              // here, so it needs more of it.
              height: leadRoom >= _LeadCard.stageFromWhenScaled
                  ? leadRoom
                  : null,
              minHeight: leadRoom,
            )
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
        ] else if (fills)
          const Spacer(),
        if (others.isNotEmpty) ...[
          SizedBox(height: _gap),
          _Tiles(
            benefits: others,
            tile: _tile,
            captionSize: _captionSize,
          ),
        ],
        SizedBox(height: _bottom),
      ],
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
    this.minHeight = 0,
  });

  /// From this height up the preview goes across the card.
  static const double _stageFrom = 136;

  /// The same, at a large text size.
  static const double stageFromWhenScaled = 200;

  final PaywallBenefit benefit;
  final bool isCompact;

  /// The height the card is given, or null to take what its words need.
  final double? height;

  /// With no [height], the least the card is tall.
  final double minHeight;

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
          maxLines: height == null ? 4 : 2,
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
      constraints: BoxConstraints(minHeight: height ?? minHeight),
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
  const _Tiles({
    required this.benefits,
    required this.tile,
    required this.captionSize,
  });

  final List<PaywallBenefit> benefits;
  final double tile;
  final double captionSize;

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
                    size: Size.square(tile),
                  ),
                  const SizedBox(height: Spacing.s1),
                  Text(
                    benefit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.small(
                      colors.ink3,
                      fontSize: captionSize,
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
