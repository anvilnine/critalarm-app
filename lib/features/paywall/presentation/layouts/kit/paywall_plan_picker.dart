import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How the plan picker is drawn. Both styles read the same state.
enum PaywallPlanPickerStyle {
  /// One full-width row per plan, stacked.
  rows,

  /// The plans side by side. Shorter, for a layout that needs the height.
  segments,
}

/// The text scale the buy block stops growing at, so the button and the
/// plans stay on screen at any system text size.
const double paywallBuyMaxTextScale = 1.3;

/// The plans of the product on sale, as tappable cards.
///
/// With one option it is a single card with the store's title and price and
/// nothing to pick. While the store is being asked it holds the same room
/// with empty cards, so the layout above does not jump when they arrive.
/// The buy block draws this. A layout places one itself only when it hides
/// the block's own picker.
class PaywallPlanPicker extends StatelessWidget {
  const PaywallPlanPicker({
    this.style = PaywallPlanPickerStyle.rows,
    super.key,
  });

  final PaywallPlanPickerStyle style;

  static const double _rowHeight = 54;
  static const double _segmentHeight = 86;
  static const double _gap = 6;

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
          // The store has not answered: hold room for what it usually has.
          final count = isLoading
              ? (state.product == PaywallProduct.hosted ? 2 : 1)
              : state.options.length;
          if (count == 0) return const SizedBox.shrink();

          Widget card(int i) {
            final option = isLoading ? null : state.options[i];
            final isSingle = count == 1;
            return _PlanCard(
              option: option,
              isSingle: isSingle,
              isSelected: option != null && option.id == state.selectedId,
              isCompactCard:
                  !isSingle && style == PaywallPlanPickerStyle.segments,
              onTap: option == null || isSingle || state.isBusy
                  ? null
                  : () {
                      if (option.id == state.selectedId) return;
                      cubit.select(option.id);
                      getIt<PaywallCues>().pickPlan(yearly: option.isYearly);
                    },
            );
          }

          if (count == 1 || style == PaywallPlanPickerStyle.rows) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  SizedBox(height: _rowHeight * scale, child: card(i)),
                ],
              ],
            );
          }
          return SizedBox(
            height: _segmentHeight * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.s2),
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

/// One plan. The billed amount is the largest thing on it. The per month
/// figure and the saving are smaller and come after it, which is what both
/// stores ask for.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.option,
    required this.isSingle,
    required this.isSelected,
    required this.isCompactCard,
    required this.onTap,
  });

  /// Null while the store is being asked: an empty card of the same size.
  final PaywallPlanOption? option;
  final bool isSingle;
  final bool isSelected;

  /// True for a side by side card, which stacks its lines.
  final bool isCompactCard;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final option = this.option;
    final isLit = isSelected || isSingle;

    final title = AppTypography.small(
      colors.ink,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.2);
    final price = AppTypography.title(
      colors.ink,
    ).copyWith(fontWeight: FontWeight.w800, height: 1.1);
    final fine = AppTypography.small(
      colors.ink3,
      fontSize: 11.5,
    ).copyWith(height: 1.25);

    Widget oneLine(String text, TextStyle style, {Alignment? alignment}) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment ?? Alignment.centerLeft,
          // The store's own strings and the plan words, as they come.
          child: Text(text, style: style, maxLines: 1),
        );

    /// The per month figure, then the saving. Both follow the price.
    Widget? afterPrice(Alignment alignment) {
      final per = option?.perPeriodLine;
      final saving = option?.savingLabel;
      if (per == null && saving == null) return null;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (per != null) Text(per, style: fine, maxLines: 1),
            if (per != null && saving != null) const SizedBox(width: 6),
            if (saving != null) _SavingTag(label: saving),
          ],
        ),
      );
    }

    final Widget content;
    if (option == null) {
      content = const SizedBox.expand();
    } else if (isCompactCard) {
      final after = afterPrice(Alignment.centerLeft);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          oneLine(option.title, title),
          oneLine(option.price, price),
          if (option.renewalLine case final line?) oneLine(line, fine),
          ?after,
        ],
      );
    } else {
      final after = afterPrice(Alignment.centerRight);
      content = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                oneLine(option.title, title),
                if (option.renewalLine case final line?) oneLine(line, fine),
              ],
            ),
          ),
          const SizedBox(width: Spacing.s3),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                oneLine(option.price, price, alignment: Alignment.centerRight),
                ?after,
              ],
            ),
          ),
        ],
      );
    }

    final card = AnimatedContainer(
      duration: context.motion(AppDurations.quick),
      padding: EdgeInsets.symmetric(
        horizontal: isCompactCard ? Spacing.s3 : 14,
      ),
      decoration: BoxDecoration(
        color: isLit ? colors.surface : colors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colors.ink : colors.hairline,
          width: isSelected ? 2.5 : 1.5,
        ),
      ),
      child: content,
    );

    if (isSingle || option == null) {
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
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

class _SavingTag extends StatelessWidget {
  const _SavingTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.highlight,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.small(
          colors.onHighlight,
          fontSize: 10,
        ).copyWith(fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}
