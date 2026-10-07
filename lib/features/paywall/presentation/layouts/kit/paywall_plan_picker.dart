import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How the plan picker is drawn. Both styles read the same state and draw
/// the same card.
enum PaywallPlanPickerStyle {
  /// One full-width card per plan, stacked. For a layout with the height.
  rows,

  /// The plans side by side, one card tall.
  segments,
}

/// The text scale the buy block stops growing at, so the button and the
/// plans stay on screen at any system text size.
const double paywallBuyMaxTextScale = 1.3;

/// The plans of the product on sale, as tappable cards.
///
/// It draws nothing where there is nothing to pick (`planCardCount`): the
/// button carries that price. While the store is being asked it holds the
/// same room with empty cards, so the layout above does not jump when they
/// arrive. The buy block draws this. A layout places one itself only when
/// it hides the block's own picker.
class PaywallPlanPicker extends StatelessWidget {
  const PaywallPlanPicker({
    this.style = PaywallPlanPickerStyle.segments,
    this.tone = PaywallTone.canvas,
    super.key,
  });

  final PaywallPlanPickerStyle style;

  /// What the cards sit on. An unpicked card has only a quiet fill, so
  /// its text takes this tone's colours.
  final PaywallTone tone;

  /// One card, at the default text size.
  static const double cardHeight = 52;
  static const double _gap = Spacing.s2;

  /// How far a badge stands above the top edge of its card. The picker
  /// keeps this much room above the cards when a card has a badge.
  static const double badgeRise = 10;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaywallBuyCubit>();
    final scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, paywallBuyMaxTextScale);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: paywallBuyMaxTextScale,
      child: BlocBuilder<PaywallBuyCubit, PaywallBuyState>(
        builder: (context, state) {
          final isLoading = state.status == PaywallBuyStatus.loading;
          final count = planCardCount(state);
          if (count == 0) return const SizedBox.shrink();

          Widget card(int i) {
            final option = isLoading ? null : state.options[i];
            final isOnly = count == 1;
            return _PlanCard(
              option: option,
              tone: tone,
              isWide: isOnly || style == PaywallPlanPickerStyle.rows,
              isChoice: option != null && !isOnly,
              // The only plan is the one that will be bought.
              isSelected:
                  option != null && (isOnly || option.id == state.selectedId),
              onTap: option == null || isOnly || state.isBusy
                  ? null
                  : () {
                      if (option.id == state.selectedId) return;
                      cubit.select(option.id);
                      getIt<PaywallCues>().pickPlan(yearly: option.isYearly);
                    },
            );
          }

          final height = cardHeight * scale;
          final top = EdgeInsets.only(
            top: planPickerKeepsBadgeRoom(state) ? badgeRise * scale : 0,
          );
          if (count == 1 || style == PaywallPlanPickerStyle.rows) {
            return Padding(
              padding: top,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    // A badge on a lower row stands in the gap above it.
                    if (i > 0)
                      SizedBox(
                        height: planCardBadge(state.options[i]) == null
                            ? _gap
                            : math.max(_gap, badgeRise * scale + 2),
                      ),
                    SizedBox(height: height, child: card(i)),
                  ],
                ],
              ),
            );
          }
          return Padding(
            padding: top,
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(child: card(i)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One plan, as a thing to pick: a mark that says whether it is picked,
/// then two lines. The name and the billed amount, which is the largest
/// thing on the card. Under them, smaller, the per month figure or when
/// the plan renews. Both stores ask for that order. A saving is a small
/// badge that stands half over the top edge.
///
/// The picked card is filled and stroked. Any other has a quiet fill and
/// no stroke, so the two never read as the same weight.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.option,
    required this.tone,
    required this.isWide,
    required this.isChoice,
    required this.isSelected,
    required this.onTap,
  });

  /// Null while the store is being asked: an empty card of the same size.
  final PaywallPlanOption? option;
  final PaywallTone tone;

  /// True for a card that has the full width to itself.
  final bool isWide;

  /// False for an empty card and for the only plan: nothing to pick.
  final bool isChoice;
  final bool isSelected;
  final VoidCallback? onTap;

  static const double _mark = 18;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = PaywallToneColors.of(context, tone);
    final option = this.option;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // The picked card is cream with ink on it. Any other is a tint of the
    // tone it sits on, with that tone's own text colours.
    final ink = isSelected ? colors.ink : toneColors.ink;
    final soft = isSelected ? colors.ink2 : toneColors.note;

    final title = AppTypography.small(
      ink,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.2);
    final price = AppTypography.title(
      ink,
      fontSize: 18,
    ).copyWith(fontWeight: FontWeight.w800, height: 1.1);
    final fine = AppTypography.small(soft, fontSize: 11).copyWith(height: 1.25);

    // The store's own strings and the plan words, as they come, each on
    // one line. Text that is too wide for its side is drawn smaller.
    Widget oneLine(String text, TextStyle style, Alignment alignment) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(text, style: style, maxLines: 1),
        );

    final Widget content;
    if (option == null) {
      content = const SizedBox.expand();
    } else {
      final second = planCardSecondLine(option);
      content = Row(
        children: [
          if (isChoice) ...[
            _PickMark(
              size: _mark,
              isSelected: isSelected,
              ink: ink,
              on: isSelected ? colors.cream : toneColors.background,
            ),
            const SizedBox(width: Spacing.s2),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The billed amount takes the width it needs, up to most
                // of the line, and keeps its size. The plan's name gives
                // way first.
                LayoutBuilder(
                  builder: (context, box) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: oneLine(
                          option.title,
                          title,
                          Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(width: Spacing.s2),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: box.maxWidth * 0.7,
                        ),
                        child: oneLine(
                          option.price,
                          price,
                          Alignment.centerRight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (second != null) ...[
                  const SizedBox(height: 2),
                  oneLine(second, fine, Alignment.centerLeft),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final badge = option == null ? null : planCardBadge(option);
    final card = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: context.motion(AppDurations.quick),
          padding: EdgeInsets.only(
            left: isWide ? 14 : Spacing.s3,
            right: isWide ? 14 : Spacing.s3,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.cream : _quietFill(colors, toneColors),
            borderRadius: Radii.mdAll,
            // The same width either way, so picking moves nothing.
            border: Border.all(
              color: isSelected ? colors.ink : colors.ink.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: content,
        ),
        if (badge != null)
          Positioned(
            top: -PaywallPlanPicker.badgeRise * scale,
            right: 12,
            child: _Badge(text: badge),
          ),
      ],
    );

    if (!isChoice) {
      return ExcludeSemantics(excluding: option == null, child: card);
    }
    // One node per plan, read as a choice among the others.
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: card,
      ),
    );
  }

  /// What a card that is not picked is filled with: cream thinned over the
  /// canvas, cream on a white sheet, where thinned it would not show, and
  /// a tint of the text colour on a dark or a coloured tone, where cream
  /// would not hold the tone's light text.
  Color _quietFill(AppColors colors, PaywallToneColors toneColors) =>
      switch (tone) {
        PaywallTone.canvas => colors.cream.withValues(alpha: 0.55),
        PaywallTone.surface => colors.cream,
        PaywallTone.panel ||
        PaywallTone.cobalt ||
        PaywallTone.crit => toneColors.ink.withValues(alpha: 0.1),
      };
}

/// The mark at the start of a plan card: a filled circle with a check on
/// the picked plan, an empty ring on any other.
class _PickMark extends StatelessWidget {
  const _PickMark({
    required this.size,
    required this.isSelected,
    required this.ink,
    required this.on,
  });

  final double size;
  final bool isSelected;
  final Color ink;

  /// The check's colour: what the card is filled with.
  final Color on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion(AppDurations.quick),
      curve: AppCurves.easeSpring,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? ink : ink.withValues(alpha: 0),
        border: Border.all(
          color: isSelected ? ink : ink.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected
          ? AppGlyph(
              GlyphType.check,
              size: size * 0.56,
              color: on,
              strokeWidth: 3.4,
            )
          : null,
    );
  }
}

/// The saving, as a small ink pill. It is ink and never cobalt, so the
/// button stays the one cobalt thing in the block.
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.ink, borderRadius: Radii.fullAll),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        child: Text(
          text,
          maxLines: 1,
          style: AppTypography.small(colors.surface, fontSize: 10).copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
