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

  /// What the cards sit on. An unpicked card has no fill, so its text
  /// takes this tone's colours.
  final PaywallTone tone;

  /// One card, at the default text size.
  static const double cardHeight = 52;
  static const double _gap = Spacing.s2;

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
          if (count == 1 || style == PaywallPlanPickerStyle.rows) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  SizedBox(height: height, child: card(i)),
                ],
              ],
            );
          }
          return SizedBox(
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
          );
        },
      ),
    );
  }
}

/// One plan, in two lines. The name and the billed amount, which is the
/// largest thing on the card. Under them, smaller, the per month figure
/// and the saving, or when the plan renews. Both stores ask for that order.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = PaywallToneColors.of(context, tone);
    final option = this.option;
    // The picked card is a surface. Any other is an outline on the tone.
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
    final strongFine = fine.copyWith(color: ink, fontWeight: FontWeight.w700);

    // The store's own strings and the plan words, as they come. Each side
    // may take what it needs and shrinks its text past the room it has.
    Widget oneLine(String text, TextStyle style, Alignment alignment) =>
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(text, style: style, maxLines: 1),
          ),
        );

    Widget twoSides(Widget? left, Widget? right) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ?left,
        if (left != null && right != null) const SizedBox(width: Spacing.s2),
        ?right,
      ],
    );

    final Widget content;
    if (option == null) {
      content = const SizedBox.expand();
    } else {
      final second = planCardSecondLine(option);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          twoSides(
            oneLine(option.title, title, Alignment.centerLeft),
            oneLine(option.price, price, Alignment.centerRight),
          ),
          if (second.left != null || second.right != null) ...[
            const SizedBox(height: 2),
            twoSides(
              second.left == null
                  ? null
                  : oneLine(second.left!, fine, Alignment.centerLeft),
              second.right == null
                  ? null
                  : oneLine(second.right!, strongFine, Alignment.centerRight),
            ),
          ],
        ],
      );
    }

    final card = AnimatedContainer(
      duration: context.motion(AppDurations.quick),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 14 : Spacing.s3),
      decoration: BoxDecoration(
        color: isSelected
            ? colors.surface
            : colors.surface.withValues(alpha: 0),
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: isSelected
              ? colors.ink
              : toneColors.ink.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1.5,
        ),
      ),
      child: content,
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
}
